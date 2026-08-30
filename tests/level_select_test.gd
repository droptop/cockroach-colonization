extends SceneTree

## The LEVEL SELECT menu, which broke the moment the game outgrew it: at 14
## levels the one-per-row column ran ~400 px off the bottom of the screen,
## three levels showed, and GO was unreachable (live report, 2026-08-30).
##
## The claims: every level in the chain gets a button, every button sits
## fully ON the screen (GO included), and pick + GO actually starts a level.
##
## Run with:
##   godot --headless --path . --script tests/level_select_test.gd

var _phase := 0
var _t := 0.0
var _step := 0.0
var _title: Control
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = "user://test_level_select.cfg"
	SaveGame.clear()
	Settings.settings_path = "user://test_level_select_settings.cfg"
	_title = (load("res://ui/title/title_screen.tscn") as PackedScene).instantiate()
	root.add_child(_title)
	print("-- the testing menu fits the screen it is on")


func _buttons(node: Node, out: Array[Button]) -> void:
	if node is Button:
		out.append(node)
	for child in node.get_children():
		_buttons(child, out)


func _process(delta: float) -> bool:
	_t += delta
	_step += delta
	if _t > 30.0:
		print("LEVEL SELECT TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _step < 0.5:
				return false
			var all: Array[Button] = []
			_buttons(_title, all)
			for button in all:
				if button.text.begins_with("LEVEL SELECT"):
					button.pressed.emit()
					_step = 0.0
					_phase = 1
					return false
			_check(false, "the title offers LEVEL SELECT")
			_phase = 3
		1:
			if _step < 0.4:
				return false
			var all: Array[Button] = []
			_buttons(_title, all)
			var levels := 0
			var go: Button = null
			var off_screen: Array[String] = []
			var vp := _title.get_viewport_rect().size
			for button in all:
				if button.text.begins_with("GO"):
					go = button
				else:
					levels += 1
				var rect := button.get_global_rect()
				if rect.position.y < -0.5 or rect.end.y > vp.y + 0.5 \
						or rect.position.x < -0.5 or rect.end.x > vp.x + 0.5:
					off_screen.append("%s at y %.0f..%.0f (screen %.0f)"
						% [button.text, rect.position.y, rect.end.y, vp.y])
			var expected := ShopScreen.LEVEL_ROWS.size() - 1 # minus "unknown"
			_check(levels == expected,
				"every level has a button (%d of %d)" % [levels, expected])
			_check(go != null, "and GO is there")
			_check(off_screen.is_empty(),
				"and every button is ON the screen%s" % ("" if off_screen.is_empty()
					else " - OFF: " + ", ".join(off_screen)))
			# Pick the last level (worst-placed button) and GO.
			for button in all:
				if button.text == "MARS":
					button.pressed.emit()
			if go:
				go.pressed.emit()
			_step = 0.0
			_phase = 2
		2:
			if _step < 0.2:
				return false
			_check(_title._starting, "pick + GO starts the run")
			_phase = 3
		3:
			if _failures.is_empty():
				print("LEVEL SELECT TEST PASS")
			else:
				print("LEVEL SELECT TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
			return true
	return false
