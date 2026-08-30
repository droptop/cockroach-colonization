extends Control

## Intro screen: COCKROACH COLONISATION — A COLECLAN GAME.
##
## Offers CONTINUE only when there is actually something to continue, so a first
## run is still a single button. Progress has been recorded since the save layer
## landed; until now nothing read it back, and a player who got to the tabletop
## and closed the tab started again at the drain.

const FIRST_LEVEL := "res://world/levels/drain_level.tscn"

var _starting := false

@onready var _prompt: Label = $Prompt

var _menu: VBoxContainer


func _ready() -> void:
	Snd.music("res://audio/music/lanterns_in_the_drain.mp3")
	_build_menu()
	_show_high_score()
	var tween := create_tween().set_loops()
	tween.tween_property(_prompt, "modulate:a", 0.25, 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_prompt, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)


## Plain Buttons, like the pause menu: Godot's own focus navigation then covers
## keyboard and controller, and touch gets tapping, with nothing bespoke to keep
## in sync between them.
func _build_menu() -> void:
	var resume_at := SaveGame.furthest_level()
	var has_save := resume_at != "" and ResourceLoader.exists(resume_at)

	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu.position.y -= 150
	_menu.custom_minimum_size = Vector2(320, 0)
	_menu.add_theme_constant_override("separation", 10)
	add_child(_menu)

	var font := _prompt.get_theme_font("font")
	if has_save:
		_prompt.visible = false
		var carry_on := _button(font, "CONTINUE")
		carry_on.pressed.connect(_start.bind(resume_at))
		var fresh := _button(font, "NEW GAME")
		fresh.pressed.connect(func() -> void:
			# Explicit: starting over has to actually start over, or a "new"
			# game inherits beaten bosses and open gates from the old one.
			SaveGame.clear()
			_start(FIRST_LEVEL))
		carry_on.grab_focus()
	else:
		var begin := _button(font, "START")
		begin.pressed.connect(_start.bind(FIRST_LEVEL))
		begin.grab_focus()
	# TESTING: jump straight to any level (user's call). Ships in the build -
	# this is a prototype and the tester is the audience.
	var select := _button(font, "LEVEL SELECT (TESTING)")
	select.pressed.connect(_open_level_select)


## The attract-mode line: the board's best run, under the menu, the way a
## cabinet flaunts its champion between games.
func _show_high_score() -> void:
	var best := Leaderboard.best()
	if best.is_empty():
		return
	var line := Label.new()
	line.text = "HI-SCORE   %s   %d" % [best.name, best.score]
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	line.grow_horizontal = Control.GROW_DIRECTION_BOTH
	line.position.y -= 56
	var font := _prompt.get_theme_font("font")
	if font:
		line.add_theme_font_override("font", font)
	line.add_theme_font_size_override("font_size", 18)
	line.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	add_child(line)


func _button(font: Font, label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(320, 46)
	button.focus_mode = Control.FOCUS_ALL
	if font:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 22)
	_menu.add_child(button)
	return button


## Any key still starts a fresh run when there is no save, so the old
## press-anything behaviour survives for a first-time player.
func _unhandled_input(event: InputEvent) -> void:
	if _starting or SaveGame.furthest_level() != "":
		return
	var pressed: bool = (event is InputEventKey and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if pressed:
		_start(FIRST_LEVEL)


func _start(scene: String) -> void:
	if _starting:
		return
	_starting = true
	Snd.sfx("level_up", 2.0, 0.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(scene))


## The testing jump menu: pick a level (it arms on the GO button), then GO.
## Rows come from the shop's own chain map, so this list can never drift
## from the real level roster without the matrix drifting too.
var _armed_level := ""


func _open_level_select() -> void:
	for child in _menu.get_children():
		child.queue_free()
	var font := _prompt.get_theme_font("font")
	# A GRID, not a column: at 14 levels a 46 px-per-row list ran 400 px off
	# the bottom of the screen - three levels showed and GO was unreachable
	# (live report). Three columns keep every level AND the GO on screen,
	# and the whole block climbs so it fits above the bottom edge.
	_menu.position.y -= 170
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	_menu.add_child(grid)
	var go: Button = null
	var first: Button = null
	for row in ShopScreen.LEVEL_ROWS:
		if row[0] == "unknown":
			continue
		var pick := Button.new()
		pick.text = row[1]
		pick.custom_minimum_size = Vector2(132, 38)
		pick.focus_mode = Control.FOCUS_ALL
		if font:
			pick.add_theme_font_override("font", font)
		pick.add_theme_font_size_override("font_size", 15)
		grid.add_child(pick)
		if first == null:
			first = pick
		pick.pressed.connect(func() -> void:
			_armed_level = row[0]
			if go:
				go.text = "GO: %s" % row[1])
	go = _button(font, "GO: pick a level first")
	go.pressed.connect(func() -> void:
		if _armed_level != "":
			_start("res://world/levels/%s.tscn" % _armed_level))
	if first:
		first.grab_focus()
