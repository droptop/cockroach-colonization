extends Control

## THE END OF THE GAME, which until now did not exist.
##
## Beating the cat on the tabletop unlocked the exit, and walking into it called
## `GameManager.complete_level()` and showed the level's complete message with a
## duration of 0.0, i.e. forever. `complete_level()` emits `level_completed` and
## NOTHING in the codebase was connected to that signal. So the last level had
## no next scene and nowhere to go: you finished the game, the message stuck on
## screen, and it read as an exit that would not let you through. The player
## reported it as exactly that, twice.
##
## So this is the somewhere to go. It is deliberately small: bosses beaten,
## babies banked, and a way back. The real payoff is meant to be the baby matrix
## (BACKLOG item 16), which replaces the middle of this screen when it lands.

const FIRST_LEVEL := "res://world/levels/drain_level.tscn"
const TITLE := "res://ui/title/title_screen.tscn"
## Every level ends in a boss, so this is also the number of levels.
const TOTAL_BOSSES := 6

var _leaving := false

@onready var _stats: Label = $Stats

var _menu: VBoxContainer


func _ready() -> void:
	Snd.music("res://audio/music/lanterns_in_the_drain.mp3")
	_stats.text = _summary()
	_build_menu()
	# The colony is established: worth recording, and it gives the title screen
	# something to know about a player who has actually finished.
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("unlock_achievement"):
		gm.unlock_achievement("finished_game", "COLONY ESTABLISHED")
	var tween := create_tween()
	modulate = Color(1, 1, 1, 0)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.8)


func _summary() -> String:
	var bosses: int = SaveGame.defeated_boss_count()
	var babies: int = SaveGame.babies_banked()
	var lines := [
		"%d of %d bosses beaten" % [bosses, TOTAL_BOSSES],
		"%d %s carried home" % [babies, "baby" if babies == 1 else "babies"],
	]
	return "\n".join(lines)


## Plain Buttons, like the title and the pause menu: Godot's own focus
## navigation then covers keyboard and controller, and touch gets tapping.
func _build_menu() -> void:
	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# Sat under the stats rather than down on the floor of the screen: the gap
	# between them is where the baby matrix goes (BACKLOG item 16), and until it
	# does an empty half-screen reads as something failing to load.
	_menu.position.y -= 230
	_menu.custom_minimum_size = Vector2(320, 0)
	_menu.add_theme_constant_override("separation", 10)
	add_child(_menu)

	var font := _stats.get_theme_font("font")
	var again := _button(font, "RUN IT AGAIN")
	# Starting over has to actually start over, or a fresh run inherits beaten
	# bosses and open gates. Same rule as NEW GAME on the title.
	again.pressed.connect(func() -> void:
		SaveGame.clear()
		_leave(FIRST_LEVEL))
	var home := _button(font, "TITLE SCREEN")
	home.pressed.connect(_leave.bind(TITLE))
	again.grab_focus()


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


func _leave(scene: String) -> void:
	if _leaving:
		return
	_leaving = true
	Snd.sfx("level_up", 2.0, 0.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(scene))
