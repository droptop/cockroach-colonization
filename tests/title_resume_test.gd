extends SceneTree

## Resuming. Progress has been recorded since the save layer landed, but nothing
## read it back — a player who reached the tabletop and closed the tab started
## again at the drain.
##
## Run with:
##   godot --headless --path . --script tests/title_resume_test.gd

const TEST_SAVE := "user://test_title.cfg"

var _phase := 0
var _frames := 0
var _title: Control
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _buttons() -> Array[Button]:
	var found: Array[Button] = []
	var menu := _title.get_node_or_null("Menu")
	if menu:
		for child in menu.get_children():
			if child is Button:
				found.append(child)
	return found


func _labels() -> Array[String]:
	var out: Array[String] = []
	for button in _buttons():
		out.append(button.text)
	return out


func _open_title() -> void:
	if _title:
		_title.free()
	_title = (load("res://ui/title/title_screen.tscn") as PackedScene).instantiate()
	root.add_child(_title)


func _initialize() -> void:
	SaveGame.save_path = TEST_SAVE
	SaveGame.clear()
	_open_title()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 20000:
		print("TITLE TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 10:
				return false
			print("-- a first run is one button")
			_check(_labels() == ["START"], "no save, so just START (%s)" % str(_labels()))
			_check(_buttons()[0].focus_mode == Control.FOCUS_ALL,
				"and it is focusable, so a controller can reach it")

			print("-- once there is progress, it offers to resume")
			SaveGame.set_furthest_level("res://world/levels/tabletop_level.tscn")
			_open_title()
			_frames = 0
			_phase = 1
		1:
			if _frames < 10:
				return false
			var labels := _labels()
			_check(labels.size() == 2, "two options now (%s)" % str(labels))
			_check(labels.has("CONTINUE"), "CONTINUE is offered")
			_check(labels.has("NEW GAME"), "and so is starting over")
			_check(labels[0] == "CONTINUE", "with continuing first, since it is the likely one")

			print("-- NEW GAME really starts over")
			SaveGame.mark_boss_defeated("rat")
			SaveGame.set_babies_banked(4)
			for button in _buttons():
				if button.text == "NEW GAME":
					button.pressed.emit()
			_check(SaveGame.furthest_level() == "",
				"progress is wiped, or a 'new' game inherits the old one's open gates")
			_check(not SaveGame.is_boss_defeated("rat"), "and beaten bosses come back")
			_check(SaveGame.babies_banked() == 0, "and the babies are gone")
			_phase = 2
		2:
			print("-- a stale save does not strand him")
			SaveGame.clear()
			SaveGame.set_furthest_level("res://world/levels/deleted_level.tscn")
			_open_title()
			_frames = 0
			_phase = 3
		3:
			if _frames < 10:
				return false
			_check(_labels() == ["START"],
				"a level that no longer exists falls back to START (%s)" % str(_labels()))
			_phase = 4
		4:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
			if _failures.is_empty():
				print("TITLE RESUME TEST PASS")
			else:
				print("TITLE RESUME TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
	return false
