extends Node

## Global signal bus + session flags. Deliberately tiny in Phase 1 — systems talk
## to a player *instance*, not this singleton, so co-op stays possible later.

signal level_completed
signal achievement_unlocked(title: String)

var debug_enabled := false
var babies_banked := 0

var _physics_frames := 0
var _achievements_unlocked := {}


func _ready() -> void:
	babies_banked = SaveGame.babies_banked()
	print("GameManager ready. web feature: ", OS.has_feature("web"))
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__gd_ready = 1", true)


## Web test drive (?gdtest=1 only): the browser can steer the SHIPPED build.
## This exists because the Spider Queen's webs were reported uncuttable in the
## live build while every headless suite passed — and headless passing proves
## nothing about the web export (the audio bus hunt, all over again). With no
## way to DRIVE the wasm build, "works in tests" and "works where the player
## is" could never be compared. Off unless the URL asks for it.
var _test_mode := false
var _test_mode_checked := false
var _test_mash := false
var _mash_down := false


func _physics_process(_delta: float) -> void:
	# Web-only heartbeat so automated tests can read engine state from JS.
	_physics_frames += 1
	if OS.has_feature("web") and _physics_frames % 20 == 0:
		var axis := Input.get_axis("move_left", "move_right")
		var px := -1.0
		var py := -1.0
		var hp := -1.0
		var wings := -1.0
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			px = players[0].global_position.x # works for Node2D and Node3D
			py = players[0].global_position.y
			if "health" in players[0]:
				hp = float(players[0].health)
			if "wing_energy" in players[0]:
				wings = players[0].wing_energy
		var anchors := get_tree().get_nodes_in_group("web_anchors").size()
		var boss_hp := -1
		var boss_immune := false
		var boss_z := 0.0
		var bosses := get_tree().get_nodes_in_group("bosses")
		if bosses.size() > 0:
			boss_hp = bosses[0].health
			boss_immune = bosses[0].immune_to_damage
			if bosses[0] is Node3D:
				boss_z = (bosses[0] as Node3D).global_position.z
		JavaScriptBridge.eval(
			"window.__gd = {pf: %d, px: %.1f, py: %.1f, hp: %.1f, wings: %.0f, anchors: %d, boss_hp: %d, boss_immune: %s, boss_z: %.2f, axis: %.2f, jump: %s}" % [
				_physics_frames, px, py, hp, wings, anchors, boss_hp,
				str(boss_immune).to_lower(), boss_z, axis,
				str(Input.is_action_pressed("jump")).to_lower()],
			true)
		if _is_test_mode():
			_apply_test_cmd(players)


func _is_test_mode() -> bool:
	if not _test_mode_checked:
		_test_mode_checked = true
		var search := str(JavaScriptBridge.eval("window.location.search", true))
		_test_mode = "gdtest=1" in search
	return _test_mode


## Reads one command object from `window.__gd_cmd` and consumes it:
##   {tx, ty}                  teleport the player
##   {press: [...], release: [...]}   hold / release input actions
##   {mash: true|false}        toggle the attack button every heartbeat
func _apply_test_cmd(players: Array) -> void:
	if _test_mash:
		_mash_down = not _mash_down
		if _mash_down:
			Input.action_press("attack")
		else:
			Input.action_release("attack")
	var raw = JavaScriptBridge.eval("JSON.stringify(window.__gd_cmd || null)", true)
	if raw == null or str(raw) == "null":
		return
	JavaScriptBridge.eval("window.__gd_cmd = null", true)
	var cmd = JSON.parse_string(str(raw))
	if not (cmd is Dictionary):
		return
	if cmd.has("tx") and players.size() > 0 and players[0] is Node3D:
		var body := players[0] as Node3D
		body.global_position = Vector3(float(cmd.tx),
			float(cmd.get("ty", body.global_position.y)), 0.0)
		if "velocity" in body:
			body.velocity = Vector3.ZERO
	for action in cmd.get("press", []):
		Input.action_press(str(action))
	for action in cmd.get("release", []):
		Input.action_release(str(action))
	if cmd.has("mash"):
		_test_mash = bool(cmd.mash)
		if not _test_mash:
			Input.action_release("attack")
	# Jump straight to a level, so a browser test does not have to play three
	# levels to reach the fight it is checking. Levels only.
	if cmd.has("scene"):
		var path := str(cmd.scene)
		if path.begins_with("res://world/levels/") and ResourceLoader.exists(path):
			get_tree().change_scene_to_file(path)


func complete_level() -> void:
	level_completed.emit()


## Persisted, so an achievement earned once stays earned across sessions.
func unlock_achievement(id: String, title: String) -> void:
	if _achievements_unlocked.has(id) or SaveGame.has_achievement(id):
		return
	_achievements_unlocked[id] = true
	SaveGame.mark_achievement(id)
	achievement_unlocked.emit(title)
