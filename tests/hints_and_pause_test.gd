extends SceneTree

## The in-world hints, and the menu that controls them.
##
## From playtesting: the hints "in the wall". They were bare Label3D nodes with
## no backing and no wrapping, so a 61-character line ran the width of the level
## and sat directly on the masonry. They now get a bubble and wrap, and can be
## switched off — along with the audio — from a pause menu that a browser can
## actually open.
##
## Run with:
##   godot --headless --path . --script tests/hints_and_pause_test.gd

const TEST_SETTINGS := "user://test_hints.cfg"

var _phase := 0
var _t := 0.0
var _level: Node
var _hud: Node
var _player: Node3D
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _hint_labels() -> Array[Label3D]:
	var out: Array[Label3D] = []
	var hints := _level.get_node_or_null("Hints")
	if hints:
		for child in hints.get_children():
			if child is Label3D:
				out.append(child)
	return out


func _initialize() -> void:
	Settings.settings_path = TEST_SETTINGS
	Settings.invalidate()
	_check(Settings.hints_enabled(), "hints are ON by default, so a first player is told what to do")
	_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_hud = _level.get_node_or_null("HUD")
	_player = _level.get_node("Player")


func _process(delta: float) -> bool:
	_t += delta
	if _t > 40.0:
		print("HINTS TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _t < 1.0:
				return false
			# The hints used to be bubbles standing in the level. Wrapping and a
			# panel fixed them being unreadable, but not the real complaint:
			# the advice was physically in front of the thing it was advising
			# about, so the drain read as cluttered. They are now a HUD line
			# under FLYING POWER, driven by proximity, and the Label3D nodes
			# survive only as the text and the place it applies to.
			print("-- hints are out of the world and on the HUD")
			var labels := _hint_labels()
			_check(labels.size() >= 5, "the drain has hints (%d)" % labels.size())
			var showing: Array[String] = []
			for label in labels:
				if label.is_visible_in_tree():
					showing.append(label.name)
			_check(showing.is_empty(), "none of them stands in the level%s"
				% ("" if showing.is_empty() else " — IN WORLD: " + ", ".join(showing)))
			_check(_hud != null and _hud.has_method("show_hint"),
				"the HUD takes hint text")

			# Standing next to one must actually put its words on screen.
			var nearest: Label3D = labels[0]
			_player.global_position = nearest.global_position
			_level._process(0.016)
			var line: Label = _hud.get_node_or_null("Hint")
			_check(line != null, "the HUD has a hint line")
			if line:
				_check(line.visible and line.text == nearest.text,
					"standing at %s shows its text (%s)"
						% [nearest.name, line.text.substr(0, 24)])
				# And walking away clears it, rather than leaving stale advice.
				_player.global_position = nearest.global_position + Vector3(60, 0, 0)
				_level._process(0.016)
				_check(not line.visible, "and walking away clears it")
			_phase = 1
		1:
			print("-- and they can be switched off")
			var hints := _level.get_node_or_null("Hints")
			_check(hints != null and hints.is_in_group("hints"),
				"the group exists, so the HUD can reach them without knowing the level")
			var line2: Label = _hud.get_node_or_null("Hint")
			Settings.set_hints_enabled(false)
			_player.global_position = _hint_labels()[0].global_position
			_level._process(0.016)
			_check(line2 == null or not line2.visible,
				"MESSAGES off keeps the hint line down even stood right at one")
			_check(not Settings.hints_enabled(), "the choice is written down")
			Settings.invalidate()
			_check(not Settings.hints_enabled(), "and survives a reload, like the audio ones")
			Settings.set_hints_enabled(true)
			_phase = 2
		2:
			print("-- pause toggles both ways, and not only on Escape")
			var keys: Array[String] = []
			for ev in InputMap.action_get_events("pause"):
				if ev is InputEventKey:
					var code: int = ev.keycode if ev.keycode != 0 else ev.physical_keycode
					keys.append(OS.get_keycode_string(code))
			_check(keys.has("P"), "P pauses (%s)" % ", ".join(keys))
			if _hud and _hud.has_method("set_paused"):
				_hud.set_paused(true)
				_check(root.get_tree().paused, "the game actually stops")
				_hud.set_paused(false)
				_check(not root.get_tree().paused, "and starts again — pause is a toggle, not a trap")
			else:
				_check(false, "the HUD exposes set_paused")
			_phase = 3
		3:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
			if _failures.is_empty():
				print("HINTS AND PAUSE TEST PASS")
			else:
				print("HINTS AND PAUSE TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
	return false
