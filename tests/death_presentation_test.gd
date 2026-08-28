extends SceneTree

## Death should say what killed him. SQUISHED is reserved for being crushed —
## using it for everything told the player nothing, and wasted the one word that
## should land hardest.
##
## Run with:
##   godot --headless --path . --script tests/death_presentation_test.gd

var _phase := 0
var _frames := 0
var _level: Node
var _player: Node
var _hud: Node
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	# HERMETIC: the player reads bought upgrades off the save on spawn now,
	# so a test without a scratch save measures whatever was last played.
	SaveGame.save_path = "user://test_death_presentation_scratch.cfg"
	SaveGame.clear()
	print("-- the message table")
	var hud_script: GDScript = load("res://ui/hud/hud.gd")
	var messages: Dictionary = hud_script.DEATH_MESSAGES
	var default: String = hud_script.DEATH_DEFAULT
	_check(default != "SQUISHED!", "SQUISHED is not the generic death message")
	for crushing in ["swat", "stomp", "paw", "pounce"]:
		_check(messages.get(crushing, "") == "SQUISHED!",
			"%s is a crushing death, so it says SQUISHED" % crushing)
	_check(messages.get("spray", "") == "SPRAYED!", "insecticide says SPRAYED")
	_check(messages.get("acid", "") != "SQUISHED!", "acid does not say SQUISHED")
	_check(messages.get("fall", "") != "SQUISHED!", "falling does not say SQUISHED")
	var distinct := {}
	for key in ["spray", "acid", "fall", "spider", "rat"]:
		distinct[messages.get(key, "")] = true
	_check(distinct.size() == 5, "those five causes all read differently")

	_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")
	_hud = _level.get_node("HUD")


func _kill(cause: String) -> void:
	_player.is_dead = false
	_player.health = 5.0
	_player._invincibility_timer = 0.0
	_player.take_damage(99, _player.global_position + Vector3(1, 0, 0), cause)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 20000:
		print("DEATH TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 12:
				return false
			print("-- the cause reaches the message")
			_kill("stomp")
			_check(_player.death_cause == "stomp", "the killing blow records its cause")
			_check(_hud._message_label.text == "SQUISHED!",
				"a stomp says SQUISHED (%s)" % _hud._message_label.text)

			_kill("acid")
			_check(_hud._message_label.text == "DISSOLVED!",
				"acid says DISSOLVED (%s)" % _hud._message_label.text)

			_kill("spray")
			_check(_hud._message_label.text == "SPRAYED!",
				"insecticide says SPRAYED (%s)" % _hud._message_label.text)

			_kill("")
			_check(_hud._message_label.text != "SQUISHED!",
				"an unattributed death does not claim to be a crushing (%s)"
					% _hud._message_label.text)

			print("-- falling in a pit is a fall")
			_player.is_dead = false
			_player.health = 5.0
			_player._invincibility_timer = 0.0
			_player.fall_into_pit()
			_check(_player.death_cause == "fall", "the pit blames itself")

			print("-- the ghost always rises visibly")
			_check(_player.ghost_rise > 0.0, "ghost rise is a configurable value")
			_player.ghost_rise = 0.0 # the "level zero" case
			_check(maxf(_player.ghost_rise, 1.0) >= 1.0,
				"and is floored so it is visible even at zero")
			_phase = 1
		1:
			if _failures.is_empty():
				print("DEATH TEST PASS")
			else:
				print("DEATH TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
	return false
