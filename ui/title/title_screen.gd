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
	Snd.sfx("complete")
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(scene))
