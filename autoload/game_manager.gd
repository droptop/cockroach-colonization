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


func _physics_process(_delta: float) -> void:
	# Web-only heartbeat so automated tests can read engine state from JS.
	_physics_frames += 1
	if OS.has_feature("web") and _physics_frames % 20 == 0:
		var axis := Input.get_axis("move_left", "move_right")
		var px := -1.0
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			px = players[0].global_position.x # works for Node2D and Node3D
		JavaScriptBridge.eval(
			"window.__gd = {pf: %d, px: %.1f, axis: %.2f, jump: %s}" % [
				_physics_frames, px, axis,
				str(Input.is_action_pressed("jump")).to_lower()],
			true)


func complete_level() -> void:
	level_completed.emit()


## Persisted, so an achievement earned once stays earned across sessions.
func unlock_achievement(id: String, title: String) -> void:
	if _achievements_unlocked.has(id) or SaveGame.has_achievement(id):
		return
	_achievements_unlocked[id] = true
	SaveGame.mark_achievement(id)
	achievement_unlocked.emit(title)
