extends SceneTree

## Music and SFX toggles: independent, immediate, and persistent.
##
## Writes to a scratch settings file — a test that mutes a real player's game
## to prove muting works is not worth the proof.
##
## Run with:
##   godot --headless --path . --script tests/audio_settings_test.gd

const TEST_PATH := "user://test_settings.cfg"

var _phase := 0
var _frames := 0
var _hud: Node
var _level: Node
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _muted(bus_name: String) -> bool:
	var idx := AudioServer.get_bus_index(bus_name)
	return idx != -1 and AudioServer.is_bus_mute(idx)


func _initialize() -> void:
	Settings.settings_path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Settings.invalidate()

	print("-- defaults")
	_check(Settings.music_enabled(), "music defaults ON")
	_check(Settings.sfx_enabled(), "sfx defaults ON")

	print("-- independence")
	Snd.set_music_enabled(false)
	_check(not Snd.music_enabled(), "music can be turned off")
	_check(Snd.sfx_enabled(), "muting music leaves sound effects alone")
	Snd.set_music_enabled(true)
	Snd.set_sfx_enabled(false)
	_check(not Snd.sfx_enabled(), "sound effects can be turned off")
	_check(Snd.music_enabled(), "muting sound effects leaves music alone")

	print("-- persistence")
	Snd.set_music_enabled(false)
	Snd.set_sfx_enabled(false)
	Settings.invalidate() # forget everything, as a restart would
	_check(not Settings.music_enabled(), "music mute survives a restart")
	_check(not Settings.sfx_enabled(), "sfx mute survives a restart")
	Snd.set_music_enabled(true)
	Settings.invalidate()
	_check(Settings.music_enabled(), "and un-muting persists too")

	_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_hud = _level.get_node("HUD")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 100000:
		print("AUDIO SETTINGS TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 12:
				return false
			print("-- buses exist and follow the setting")
			_check(AudioServer.get_bus_index("Music") != -1, "a Music bus exists")
			_check(AudioServer.get_bus_index("SFX") != -1, "an SFX bus exists")
			# Establish a known state: the persistence checks above deliberately
			# left sound effects off.
			Snd.set_music_enabled(true)
			Snd.set_sfx_enabled(true)
			_check(not _muted("Music") and not _muted("SFX"), "both buses start unmuted")
			Snd.set_music_enabled(false)
			_check(_muted("Music"), "turning music off mutes the Music bus")
			_check(not _muted("SFX"), "and leaves the SFX bus alone")
			Snd.set_sfx_enabled(false)
			Snd.set_music_enabled(true)
			_check(not _muted("Music"), "turning music back on unmutes it")
			_check(_muted("SFX"), "while sound effects stay off")

			print("-- pause menu")
			_hud.set_paused(true)
			var menu: Control = _hud.get_node_or_null("PauseMenu")
			_check(menu != null, "pausing builds the menu")
			_check(menu != null and menu.visible, "and shows it")
			_check(paused, "and pauses the tree")
			_check(_hud.can_process(), "the HUD still runs while paused, so it can unpause")
			if menu:
				_check(menu.process_mode == Node.PROCESS_MODE_ALWAYS,
					"the menu itself runs while paused")
			_check(_hud._music_button.text.ends_with("ON"),
				"the music button shows its state (%s)" % _hud._music_button.text)
			_check(_hud._sfx_button.text.ends_with("OFF"),
				"the sfx button shows its state (%s)" % _hud._sfx_button.text)

			# Press it the way a player would, rather than calling the setter.
			_hud._music_button.pressed.emit()
			_check(not Snd.music_enabled(), "pressing the music button turns music off")
			_check(_hud._music_button.text.ends_with("OFF"),
				"and the label updates immediately")
			_check(_muted("Music"), "and the bus follows on the same frame")

			_hud.set_paused(false)
			_check(not paused, "unpausing resumes the tree")
			_check(not menu.visible, "and hides the menu")
			_phase = 1
		1:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
			if _failures.is_empty():
				print("AUDIO SETTINGS TEST PASS")
			else:
				print("AUDIO SETTINGS TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
	return false
