class_name EndingScreen
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
const TOTAL_BOSSES := 10

## Hearts he walked out of the last door with, in half-heart units. Set by
## Level3D at the final exit — statics survive the scene change, same trick
## as ShopScreen's handoff.
static var run_hearts := 0.0

## The initials wheel. Space last, so a two-letter name is reachable.
const INITIALS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ "

var _leaving := false
var _score := 0
var _initials := [0, 0, 0]
var _initial_labels: Array[Label] = []
var _entry_box: VBoxContainer
var _board_box: VBoxContainer

@onready var _stats: Label = $Stats

var _menu: VBoxContainer


func _ready() -> void:
	Snd.music("res://audio/music/lanterns_in_the_drain.mp3")
	_score = Leaderboard.score_for(
		SaveGame.babies_banked(), SaveGame.coins_earned(), run_hearts)
	_stats.text = _summary()
	_build_menu()
	# THE ARCADE MOMENT (BACKLOG item 24): a good enough run earns three
	# initials on the board, exactly like the machines this game grew up on.
	if Leaderboard.qualifies(_score):
		_build_initials_entry()
	else:
		_build_board(-1)
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
		"%d coins earned" % SaveGame.coins_earned(),
		"%.1f hearts to spare" % (run_hearts / 2.0),
		"",
		"SCORE  %d" % _score,
	]
	return "\n".join(lines)


## Three big letters, an up and a down arrow each, and OK. Plain Buttons like
## every menu here: keyboard and controller get focus navigation for free,
## touch gets tapping, nothing bespoke.
func _build_initials_entry() -> void:
	var font := _stats.get_theme_font("font")
	_entry_box = VBoxContainer.new()
	_entry_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_entry_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_entry_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_entry_box.position.y += 10
	_entry_box.add_theme_constant_override("separation", 6)
	_entry_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_entry_box)

	var caption := Label.new()
	caption.text = "A PLACE ON THE BOARD! YOUR MARK:"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font:
		caption.add_theme_font_override("font", font)
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_entry_box.add_child(caption)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_entry_box.add_child(row)
	var first_up: Button = null
	for slot in 3:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		row.add_child(column)
		var up := _wheel_button(font, "^", column)
		up.pressed.connect(_turn_initial.bind(slot, 1))
		if first_up == null:
			first_up = up
		var letter := Label.new()
		letter.text = INITIALS[0]
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if font:
			letter.add_theme_font_override("font", font)
		letter.add_theme_font_size_override("font_size", 44)
		column.add_child(letter)
		_initial_labels.append(letter)
		var down := _wheel_button(font, "v", column)
		down.pressed.connect(_turn_initial.bind(slot, -1))

	var confirm := Button.new()
	confirm.name = "ConfirmInitials"
	confirm.text = "CARVE IT IN"
	confirm.custom_minimum_size = Vector2(220, 40)
	confirm.focus_mode = Control.FOCUS_ALL
	if font:
		confirm.add_theme_font_override("font", font)
	confirm.add_theme_font_size_override("font_size", 18)
	confirm.pressed.connect(_submit_initials)
	_entry_box.add_child(confirm)
	if first_up:
		first_up.grab_focus()


func _wheel_button(font: Font, label: String, parent: Node) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(56, 32)
	button.focus_mode = Control.FOCUS_ALL
	if font:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 16)
	parent.add_child(button)
	return button


func _turn_initial(slot: int, step: int) -> void:
	_initials[slot] = wrapi(_initials[slot] + step, 0, INITIALS.length())
	_initial_labels[slot].text = INITIALS[_initials[slot]]
	Snd.sfx("crumb", -6.0)


func _submit_initials() -> void:
	var carved := "%s%s%s" % [INITIALS[_initials[0]], INITIALS[_initials[1]],
		INITIALS[_initials[2]]]
	var rank := Leaderboard.submit(carved, _score, SaveGame.babies_banked(),
		SaveGame.coins_earned(), run_hearts)
	Snd.sfx("level_up", 0.0, 0.05)
	_entry_box.queue_free()
	_entry_box = null
	_build_board(rank)


## The table itself, best first, this run's row lit.
func _build_board(highlight_rank: int) -> void:
	var font := _stats.get_theme_font("font")
	_board_box = VBoxContainer.new()
	_board_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_board_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_board_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_board_box.position.y += 10
	_board_box.add_theme_constant_override("separation", 1)
	_board_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_board_box)

	var heading := Label.new()
	heading.text = "BEST COLONIES"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font:
		heading.add_theme_font_override("font", font)
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_board_box.add_child(heading)

	var board := Leaderboard.entries()
	if board.is_empty():
		var empty := Label.new()
		empty.text = "NOBODY YET - THIS BOARD IS YOURS TO OPEN"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if font:
			empty.add_theme_font_override("font", font)
		empty.add_theme_font_size_override("font_size", 15)
		_board_box.add_child(empty)
		return
	for i in board.size():
		var entry: Dictionary = board[i]
		var line := Label.new()
		line.text = "%2d   %-3s   %6d   %d babies" % [
			i + 1, entry.name, entry.score, entry.babies]
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if font:
			line.add_theme_font_override("font", font)
		line.add_theme_font_size_override("font_size", 15)
		if i == highlight_rank:
			line.add_theme_color_override("font_color", Color(0.55, 0.95, 0.6))
			line.text = "> " + line.text.strip_edges() + " <"
		_board_box.add_child(line)


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
