extends SceneTree

## The controls have to be reachable in a BROWSER, which is where this game
## actually ships.
##
## This exists because Escape was the only key bound to `pause`, and browsers
## swallow Escape — so in the web build the pause menu could not be opened at
## all, and the MUSIC and SOUND FX toggles live inside it. Anyone who turned
## audio off had no way to turn it back on, and the setting persists in
## user:// (IndexedDB on web), so it survived every redeploy.
##
## Run with:
##   godot --headless --path . --script tests/input_map_test.gd

## Keys a browser is liable to intercept before the canvas sees them.
const BROWSER_EATEN := ["Escape", "Tab", "F1", "F5", "F11", "Backspace"]

var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _keys(action: String) -> Array[String]:
	var out: Array[String] = []
	if not InputMap.has_action(action):
		return out
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var code: int = ev.keycode if ev.keycode != 0 else ev.physical_keycode
			out.append(OS.get_keycode_string(code))
	return out


func _initialize() -> void:
	print("-- everything the player needs is bound")
	for action in ["move_left", "move_right", "jump", "attack", "pause",
			"interact", "move_up", "move_down"]:
		_check(not _keys(action).is_empty(),
			"%s has a key (%s)" % [action, ", ".join(_keys(action))])

	print("-- and reachable in a browser, not just on desktop")
	for action in ["pause", "attack", "jump", "move_left", "move_right"]:
		var usable: Array[String] = []
		for key in _keys(action):
			if not BROWSER_EATEN.has(key):
				usable.append(key)
		_check(not usable.is_empty(),
			"%s works in a browser (%s)" % [action, ", ".join(usable)
				if not usable.is_empty() else "ONLY " + ", ".join(_keys(action))])

	# The specific regression: the audio toggles live behind the pause menu, so
	# an unreachable pause menu means unrecoverable silence.
	_check(_keys("pause").size() >= 2,
		"pause has a spare binding, since it is the only way to the audio toggles")

	if _failures.is_empty():
		print("INPUT MAP TEST PASS")
	else:
		print("INPUT MAP TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
	quit(0 if _failures.is_empty() else 1)
