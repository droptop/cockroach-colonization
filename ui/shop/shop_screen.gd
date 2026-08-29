class_name ShopScreen
extends Control

## The stash, between levels: spend the run's coins, admire the run's babies,
## carry on. A separate SCREEN rather than a shopfront inside a level
## (BACKLOG item 25) so no level needs a safe room built into it.
##
## Laid out as a STORE, per the user's call: a card per item with a drawn
## icon and the price in coins underneath, not a column of text buttons.
## Icons are procedural `_draw` graphics like everything else in the project —
## no textures to import, and they match the in-game objects they buy.
##
## Everything money-shaped lives in SaveGame (coins, upgrade levels), so this
## screen owns no state a scene change could lose. Purchases last the RUN:
## NEW GAME wipes the save and the upgrades with it, dying does not.
##
## Cards are plain Buttons underneath, like the pause menu: Godot's focus
## navigation gives keyboard and controller movement for free, touch gets
## tapping, and the focus ring doubles as the selection highlight.

## Where CONTINUE goes. Set by the level that hands over to this screen;
## statics survive the scene change that frees that level.
static var next_scene_path := ""
## How many babies were banked at the exit just walked through, so the matrix
## can light the new ones — and which level's row they light.
static var banked_delta := 0
static var banked_level := ""

## Matrix row names, keyed by level id, in chain order.
const LEVEL_ROWS := [
	["drain_level", "DRAIN"], ["street_level", "STREET"],
	["kitchen_level", "KITCHEN"], ["counter_level", "COUNTER"],
	["granny_kitchen_level", "FLOOR"], ["tabletop_level", "TABLE"],
	["pantry_level", "PANTRY"], ["roof_level", "ROOF"], ["roof_garden_level", "GARDEN"], ["tree_level", "TREE"], ["abduction_level", "FIELD"], ["moon_level", "MOON"], ["unknown", "???"],
]

## The catalogue. Price climbs by `step` per level owned, so a second heart
## costs real saving; a 0-step item is a flat price.
const UPGRADES: Array[Dictionary] = [
	{"id": "heart", "label": "EXTRA HEART", "blurb": "One more heart, forever this run",
		"price": 12, "step": 8, "max": 3},
	{"id": "wing_tank", "label": "BIGGER WINGS", "blurb": "Fly 20 percent longer",
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

const GOLD := Color(1.0, 0.85, 0.35)

var _coins_label: Label
## id -> {button, price, owned}
var _cards := {}
var _blurb_label: Label
var _continue_button: Button
## Two presses to buy: the first ARMS the card ("BUY FOR 12?"), the second
## spends. A single-click purchase meant tapping around the shop to look at
## things silently drained the balance — which reads as coins disappearing,
## because that is what it is.
var _armed_id := ""


## The item pictures: little flat-colour drawings of the thing you get, in the
## palette the game already taught (heart red, wing-shard blue, coin gold).
class UpgradeIcon:
	extends Control
	var id := ""

	func _init(for_id: String) -> void:
		id = for_id
		custom_minimum_size = Vector2(120, 64)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(size.x / 2.0, size.y / 2.0)
		match id:
			"heart":
				var red := Color(0.95, 0.25, 0.35)
				draw_circle(c + Vector2(-11, -8), 13, red)
				draw_circle(c + Vector2(11, -8), 13, red)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(-23, -3), c + Vector2(23, -3), c + Vector2(0, 28)]), red)
			"wing_tank":
				var blue := Color(0.55, 0.85, 1.0)
				for side in [-1.0, 1.0]:
					var points := PackedVector2Array()
					for i in 13:
						var a: float = PI * i / 12.0
						points.append(c + Vector2(side * (6.0 + 22.0 * sin(a * 0.5)),
							-20.0 + 40.0 * (a / PI)))
					points.append(c + Vector2(side * 4.0, 20.0))
					draw_colored_polygon(points, blue)
				draw_line(c + Vector2(0, -22), c + Vector2(0, 22), Color(0.35, 0.6, 0.8), 3.0)
			"thick_shell":
				var brown := Color(0.72, 0.3, 0.2)
				var dome := PackedVector2Array()
				for i in 17:
					var a: float = PI * i / 16.0
					dome.append(c + Vector2(-cos(a) * 26.0, 14.0 - sin(a) * 26.0))
				draw_colored_polygon(dome, brown)
				draw_rect(Rect2(c + Vector2(-26, 14), Vector2(52, 6)), Color(0.5, 0.2, 0.14))
				for x in [-12.0, 2.0, 16.0]:
					draw_line(c + Vector2(x, -8), c + Vector2(x - 4, 12),
						Color(0.5, 0.2, 0.14), 2.0)
			"power_hits":
				var yellow := Color(1.0, 0.85, 0.2)
				var star := PackedVector2Array()
				for i in 16:
					var a: float = TAU * i / 16.0
					var r: float = 26.0 if i % 2 == 0 else 11.0
					star.append(c + Vector2(cos(a) * r, sin(a) * r))
				draw_colored_polygon(star, yellow)
				draw_circle(c, 6.0, Color(1.0, 0.96, 0.75))
			"funny_sounds":
				var purple := Color(0.85, 0.6, 0.95)
				draw_circle(c + Vector2(-14, 14), 8, purple)
				draw_rect(Rect2(c + Vector2(-8, -18), Vector2(4, 32)), purple)
				draw_rect(Rect2(c + Vector2(-8, -18), Vector2(16, 5)), purple)
				for r in [12.0, 19.0, 26.0]:
					draw_arc(c + Vector2(12, 0), r, -0.9, 0.9, 10,
						Color(0.85, 0.6, 0.95, 1.0 - r * 0.02), 2.5)
			"hat":
				var felt := Color(0.16, 0.14, 0.2)
				draw_rect(Rect2(c + Vector2(-26, 14), Vector2(52, 7)), felt)
				draw_rect(Rect2(c + Vector2(-14, -22), Vector2(28, 36)), felt)
				draw_rect(Rect2(c + Vector2(-14, 4), Vector2(28, 8)), Color(0.85, 0.25, 0.2))


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
	column.add_theme_constant_override("separation", 8)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)

	var title := Label.new()
	title.text = "THE STASH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", black)
	title.add_theme_font_size_override("font_size", 38)
	column.add_child(title)

	_coins_label = Label.new()
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coins_label.add_theme_font_override("font", bold)
	_coins_label.add_theme_font_size_override("font_size", 22)
	_coins_label.add_theme_color_override("font_color", GOLD)
	column.add_child(_coins_label)

	_build_baby_matrix(column, bold)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(grid)
	for upgrade in UPGRADES:
		_build_card(grid, upgrade, bold)

	# One line under the shelves that describes whatever is focused, so the
	# cards themselves stay pictures and prices.
	_blurb_label = Label.new()
	_blurb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blurb_label.add_theme_font_override("font", bold)
	_blurb_label.add_theme_font_size_override("font_size", 15)
	_blurb_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	_blurb_label.custom_minimum_size = Vector2(0, 22)
	column.add_child(_blurb_label)

	_continue_button = Button.new()
	_continue_button.custom_minimum_size = Vector2(460, 44)
	_continue_button.focus_mode = Control.FOCUS_ALL
	_continue_button.add_theme_font_override("font", black)
	_continue_button.add_theme_font_size_override("font_size", 20)
	_continue_button.text = "CONTINUE  -->"
	_continue_button.pressed.connect(continue_to_next)
	_continue_button.focus_entered.connect(func() -> void:
		_blurb_label.text = "On to the next level!")
	column.add_child(_continue_button)

	_refresh()
	_continue_button.grab_focus()


## One shelf item: the picture, the name, and the price in coins under it.
## The card IS a button, so it focuses, clicks and taps; its children only
## decorate and must never eat the input.
func _build_card(grid: GridContainer, upgrade: Dictionary, bold: Font) -> void:
	var card := Button.new()
	card.name = upgrade.id
	card.custom_minimum_size = Vector2(150, 138)
	card.focus_mode = Control.FOCUS_ALL
	card.pressed.connect(_buy.bind(upgrade))
	card.focus_entered.connect(func() -> void:
		_blurb_label.text = upgrade.blurb
		# Moving to another card stands down an armed purchase.
		if _armed_id != "" and _armed_id != upgrade.id:
			_armed_id = ""
			_refresh())
	card.mouse_entered.connect(func() -> void:
		_blurb_label.text = upgrade.blurb)
	grid.add_child(card)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(box)

	box.add_child(UpgradeIcon.new(upgrade.id))

	var name_label := Label.new()
	name_label.text = upgrade.label
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_override("font", bold)
	name_label.add_theme_font_size_override("font_size", 13)
	box.add_child(name_label)

	var price := Label.new()
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.add_theme_font_override("font", bold)
	price.add_theme_font_size_override("font_size", 16)
	price.add_theme_color_override("font_color", GOLD)
	box.add_child(price)

	var owned := Label.new()
	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owned.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owned.add_theme_font_override("font", bold)
	owned.add_theme_font_size_override("font_size", 12)
	owned.add_theme_color_override("font_color", Color(0.65, 0.95, 0.7))
	box.add_child(owned)

	_cards[upgrade.id] = {"button": card, "price": price, "owned": owned}


## THE MATRIX (BACKLOG item 23): one row per level, one square per baby that
## level's door banked, this level's fresh rescues lit. Filling every row is
## the long game; nothing you saved ever stops being shown.
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
	caption.text = "THE COLONY MATRIX  %d%s" % [banked,
		"  (+%d!)" % fresh if fresh > 0 else ""]
	caption.add_theme_color_override("font_color", Color(0.65, 0.95, 0.7))
	column.add_child(caption)

	var matrix := VBoxContainer.new()
	matrix.name = "BabyMatrix"
	matrix.add_theme_constant_override("separation", 3)
	matrix.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(matrix)
	var ledger := SaveGame.babies_by_level()
	for row in LEVEL_ROWS:
		var count := int(ledger.get(row[0], 0))
		if count <= 0:
			continue
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 5)
		matrix.add_child(line)
		var name_label := Label.new()
		name_label.text = "%-7s" % row[1]
		name_label.custom_minimum_size = Vector2(92, 0)
		name_label.add_theme_font_override("font", bold)
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78))
		line.add_child(name_label)
		var lit := fresh if row[0] == banked_level else 0
		for i in count:
			var square := ColorRect.new()
			square.custom_minimum_size = Vector2(16, 16)
			# This door's rescues glow; every earlier row keeps its dim green.
			square.color = Color(0.55, 0.95, 0.6) if i >= count - lit \
				else Color(0.24, 0.4, 0.28)
			line.add_child(square)


func _price(upgrade: Dictionary) -> int:
	return upgrade.price + upgrade.step * SaveGame.upgrade_level(upgrade.id)


func _buy(upgrade: Dictionary) -> void:
	var owned := SaveGame.upgrade_level(upgrade.id)
	if owned >= int(upgrade["max"]):
		return
	if _armed_id != upgrade.id:
		_armed_id = upgrade.id
		Snd.sfx("crumb", -4.0)
		_refresh()
		return
	_armed_id = ""
	if not SaveGame.spend_coins(_price(upgrade)):
		Snd.sfx("locked", -6.0)
		_refresh()
		return
	SaveGame.set_upgrade_level(upgrade.id, owned + 1)
	Snd.sfx("level_up", 0.0, 0.05)
	_refresh()


func _refresh() -> void:
	_coins_label.text = "COINS  %d" % SaveGame.coins()
	for upgrade in UPGRADES:
		var card: Dictionary = _cards[upgrade.id]
		var owned := SaveGame.upgrade_level(upgrade.id)
		var maxed := owned >= int(upgrade["max"])
		(card.button as Button).disabled = maxed
		if maxed:
			(card.price as Label).text = "SOLD OUT"
		elif _armed_id == upgrade.id:
			(card.price as Label).text = "BUY FOR %d?" % _price(upgrade)
		else:
			(card.price as Label).text = "%d COINS" % _price(upgrade)
		var pips := ""
		for i in owned:
			pips += "*"
		(card.owned as Label).text = ("OWNED " + pips) if owned > 0 else ""
		# Never disabled for being unaffordable: pressing it and hearing the
		# locked clunk teaches the price; a greyed card teaches nothing.


## On to the next level. Public and argument-free so the completability
## harness can walk through the shop the way a player does.
func continue_to_next() -> void:
	var target := next_scene_path
	next_scene_path = ""
	banked_delta = 0
	banked_level = ""
	if target != "" and ResourceLoader.exists(target):
		get_tree().change_scene_to_file(target)
	else:
		# Nothing to go to: the only honest fallback is the title.
		get_tree().change_scene_to_file("res://ui/title/title_screen.tscn")
