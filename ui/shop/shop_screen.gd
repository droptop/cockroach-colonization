class_name ShopScreen
extends Control

## The stash, between levels: spend the run's coins, admire the run's babies,
## carry on. A separate SCREEN rather than a shopfront inside a level
## (BACKLOG item 25) so no level needs a safe room built into it.
##
## Everything money-shaped lives in SaveGame (coins, upgrade levels), so this
## screen owns no state a scene change could lose. Purchases last the RUN:
## NEW GAME wipes the save and the upgrades with it, dying does not.
##
## Plain Buttons throughout, like the pause menu: Godot's focus navigation
## gives keyboard and controller movement for free, and touch gets tapping.

## Where CONTINUE goes. Set by the level that hands over to this screen;
## statics survive the scene change that frees that level.
static var next_scene_path := ""
## How many babies were banked at the exit just walked through, so the matrix
## can light the new ones.
static var banked_delta := 0

## The catalogue. Price climbs by `step` per level owned, so a second heart
## costs real saving; a 0-step item is a flat price.
const UPGRADES: Array[Dictionary] = [
	{"id": "heart", "label": "EXTRA HEART", "blurb": "One more heart, forever this run",
		"price": 12, "step": 8, "max": 3},
	{"id": "wing_tank", "label": "BIGGER WING TANK", "blurb": "Fly 20 percent longer",
		"price": 10, "step": 8, "max": 3},
	{"id": "thick_shell", "label": "THICK SHELL", "blurb": "Hits drain less wing power",
		"price": 15, "step": 0, "max": 1},
	{"id": "power_hits", "label": "POWER HITS", "blurb": "Every attack hits +1 harder",
		"price": 20, "step": 15, "max": 2},
	{"id": "funny_sounds", "label": "FUNNY SOUNDS", "blurb": "Everything squeaks. Or booms",
		"price": 8, "step": 0, "max": 1},
	{"id": "hat", "label": "RIDICULOUS HAT", "blurb": "A tiny top hat. It does nothing",
		"price": 6, "step": 0, "max": 1},
]

var _coins_label: Label
var _buttons := {}
var _continue_button: Button


func _ready() -> void:
	var black: Font = load("res://ui/fonts/IronDiceGrit-Black.ttf")
	var bold: Font = load("res://ui/fonts/IronDiceGrit-Bold.ttf")

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.05, 0.045, 0.07)
	add_child(backdrop)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.custom_minimum_size = Vector2(440, 0)
	column.add_theme_constant_override("separation", 8)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)

	var title := Label.new()
	title.text = "THE STASH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", black)
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)

	_coins_label = Label.new()
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coins_label.add_theme_font_override("font", bold)
	_coins_label.add_theme_font_size_override("font_size", 22)
	_coins_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	column.add_child(_coins_label)

	_build_baby_matrix(column, bold)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	column.add_child(spacer)

	for upgrade in UPGRADES:
		var button := Button.new()
		button.custom_minimum_size = Vector2(440, 40)
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_override("font", bold)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_buy.bind(upgrade))
		column.add_child(button)
		_buttons[upgrade.id] = button

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	column.add_child(spacer2)

	_continue_button = Button.new()
	_continue_button.custom_minimum_size = Vector2(440, 44)
	_continue_button.focus_mode = Control.FOCUS_ALL
	_continue_button.add_theme_font_override("font", black)
	_continue_button.add_theme_font_size_override("font_size", 20)
	_continue_button.text = "CONTINUE  -->"
	_continue_button.pressed.connect(continue_to_next)
	column.add_child(_continue_button)

	_refresh()
	_continue_button.grab_focus()


## Every banked baby, one square each — the run's whole family on one screen.
## The ones banked at the door just walked through glow; the veterans sit dim.
## This is the seed of the level-end matrix (BACKLOG item 23).
func _build_baby_matrix(column: VBoxContainer, bold: Font) -> void:
	var banked := SaveGame.babies_banked()
	var caption := Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font", bold)
	caption.add_theme_font_size_override("font_size", 16)
	if banked <= 0:
		caption.text = "NO BABIES BANKED YET - CARRY THEM TO THE DOOR"
		caption.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		column.add_child(caption)
		return
	var fresh := clampi(banked_delta, 0, banked)
	caption.text = "BABIES BANKED  %d%s" % [banked,
		"  (+%d!)" % fresh if fresh > 0 else ""]
	caption.add_theme_color_override("font_color", Color(0.65, 0.95, 0.7))
	column.add_child(caption)

	var grid := GridContainer.new()
	grid.columns = 12
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(grid)
	for i in banked:
		var square := ColorRect.new()
		square.custom_minimum_size = Vector2(22, 22)
		# New this level: lit. Banked earlier: dim, but present — the point of
		# the grid is that nothing you saved ever stops being shown.
		square.color = Color(0.55, 0.95, 0.6) if i >= banked - fresh \
			else Color(0.24, 0.4, 0.28)
		grid.add_child(square)


func _price(upgrade: Dictionary) -> int:
	return upgrade.price + upgrade.step * SaveGame.upgrade_level(upgrade.id)


func _buy(upgrade: Dictionary) -> void:
	var owned := SaveGame.upgrade_level(upgrade.id)
	if owned >= int(upgrade["max"]):
		return
	if not SaveGame.spend_coins(_price(upgrade)):
		Snd.sfx("locked", -6.0)
		return
	SaveGame.set_upgrade_level(upgrade.id, owned + 1)
	Snd.sfx("level_up", 0.0, 0.05)
	_refresh()


func _refresh() -> void:
	_coins_label.text = "COINS  %d" % SaveGame.coins()
	for upgrade in UPGRADES:
		var button: Button = _buttons[upgrade.id]
		var owned := SaveGame.upgrade_level(upgrade.id)
		if owned >= int(upgrade["max"]):
			button.text = "%s - OWNED%s" % [upgrade.label,
				" x%d" % owned if int(upgrade["max"]) > 1 else ""]
			button.disabled = true
			continue
		button.text = "%s  %dc - %s%s" % [upgrade.label, _price(upgrade),
			upgrade.blurb, "  (own %d)" % owned if owned > 0 else ""]
		# Never disabled for being unaffordable: pressing it and hearing the
		# locked clunk teaches the price; a greyed row teaches nothing.


## On to the next level. Public and argument-free so the completability
## harness can walk through the shop the way a player does.
func continue_to_next() -> void:
	var target := next_scene_path
	next_scene_path = ""
	banked_delta = 0
	if target != "" and ResourceLoader.exists(target):
		get_tree().change_scene_to_file(target)
	else:
		# Nothing to go to: the only honest fallback is the title.
		get_tree().change_scene_to_file("res://ui/title/title_screen.tscn")
