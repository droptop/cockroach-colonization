extends SceneTree

## Does the title screen fit on the title screen?
##
## This exists because it did not, in the first thing anyone sees. The menu was
## hung 150 px above the bottom edge and grew DOWNWARD, sized for one button.
## With START plus LEVEL SELECT the second button sat squarely on top of the
## "press SPACE / tap to start" prompt; with CONTINUE, NEW GAME and LEVEL
## SELECT the third ran off the bottom of the screen, through the HI-SCORE line
## on the way. `level_select_test` only measured the grid AFTER the button was
## pressed, so the screen you press it on was never checked.
##
## The claim, for a first run, a returning player and the level grid alike:
## every button and every line of text is fully on screen, and no two overlap.
##
## Run with:
##   godot --headless --path . --script tests/title_layout_test.gd

const DRAIN := "res://world/levels/drain_level.tscn"

var _phase := 0
var _settle := 0
var _title: Control
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = "user://test_title_layout.cfg"
	SaveGame.clear()
	Settings.settings_path = "user://test_title_layout_settings.cfg"
	Leaderboard.board_path = "user://test_title_layout_board.cfg"
	Leaderboard.clear()
	print("-- nothing on the title screen overlaps or leaves the screen")
	_open()


func _open() -> void:
	if _title:
		_title.free()
	_title = (load("res://ui/title/title_screen.tscn") as PackedScene).instantiate()
	root.add_child(_title)
	_settle = 6 # containers sort on the frame after their children arrive


func _widgets(node: Node, out: Array[Control]) -> void:
	if node is Control and not (node as Control).is_visible_in_tree():
		return
	if node is Button or node is Label:
		out.append(node)
		return
	for child in node.get_children():
		_widgets(child, out)


func _text(widget: Control) -> String:
	return str(widget.get("text")).left(24)


func _measure(scenario: String, expect_buttons: int) -> void:
	var widgets: Array[Control] = []
	_widgets(_title, widgets)
	var buttons := 0
	for widget in widgets:
		if widget is Button:
			buttons += 1
	_check(buttons == expect_buttons, "%s: shows %d buttons (expected %d)" % [
		scenario, buttons, expect_buttons])
	var screen := Rect2(Vector2.ZERO, _title.get_viewport_rect().size).grow(0.5)
	var problems: Array[String] = []
	for widget in widgets:
		var rect := widget.get_global_rect()
		if not screen.encloses(rect):
			problems.append("\"%s\" leaves the screen (y %.0f..%.0f of %.0f)" % [
				_text(widget), rect.position.y, rect.end.y, screen.size.y])
	for i in widgets.size():
		for j in range(i + 1, widgets.size()):
			# Shrunk a hair: neighbours in a container share an edge exactly.
			if widgets[i].get_global_rect().grow(-1.0).intersects(widgets[j].get_global_rect().grow(-1.0)):
				problems.append("\"%s\" overlaps \"%s\"" % [_text(widgets[i]), _text(widgets[j])])
	_check(problems.is_empty(), "%s: %d widgets on screen and clear of each other%s" % [
		scenario, widgets.size(),
		"" if problems.is_empty() else "\n         " + "\n         ".join(problems)])


func _press(prefix: String) -> void:
	var widgets: Array[Control] = []
	_widgets(_title, widgets)
	for widget in widgets:
		if widget is Button and (widget as Button).text.begins_with(prefix):
			(widget as Button).pressed.emit()
			return
	_check(false, "there is a %s button to press" % prefix)


func _process(_delta: float) -> bool:
	_settle -= 1
	if _settle > 0:
		return false
	match _phase:
		0:
			_measure("first run", 2)
			Leaderboard.submit("ROA", 12345, 3, 40, 6.0)
			_open()
		1:
			_measure("first run, with a hi-score on the board", 2)
			_press("LEVEL SELECT")
			_settle = 6
		2:
			_measure("level select", ShopScreen.LEVEL_ROWS.size())
			SaveGame.set_furthest_level(DRAIN)
			_open()
		3:
			_measure("returning player, with a hi-score", 3)
			_press("LEVEL SELECT")
			_settle = 6
		4:
			_measure("returning player's level select", ShopScreen.LEVEL_ROWS.size())
			if _failures.is_empty():
				print("TITLE LAYOUT TEST PASS")
			else:
				print("TITLE LAYOUT TEST FAIL (%d)" % _failures.size())
			quit(0 if _failures.is_empty() else 1)
			return true
	_phase += 1
	return false
