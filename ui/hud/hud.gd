extends CanvasLayer

## HUD: health pips, food count, centre messages, and the F3 debug overlay.
## Wired to a player *instance* via player_path (see rule 45 in GAME.md).

@export var player_path: NodePath

# Duck-typed so both the 2D Player and 3D Player3D work.
var _player: Node
var _message_tween: Tween
var _weapon_id := "bite"
var _weapon_ready := false

@onready var _hearts: Control = $Health
@onready var _food_label: Label = $Food
@onready var _message_label: Label = $Message
@onready var _debug_label: Label = $Debug
@onready var _weapon_label: Label = $Weapon
@onready var _shield_label: Label = $Shield


func _ready() -> void:
	# get_node_or_null, not the bare GameManager global: the headless
	# `--script` test harness doesn't register autoloads (see Snd's docstring).
	var game_manager := get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.achievement_unlocked.connect(_on_achievement_unlocked)
	_player = get_node_or_null(player_path)
	if _player:
		_player.health_changed.connect(_on_health_changed)
		_player.food_changed.connect(_on_food_changed)
		_player.died.connect(_on_player_died)
		_on_health_changed(_player.health, _player.max_health)
		_on_food_changed(_player.food)
		if _player.has_signal("fruit_changed"):
			_player.fruit_changed.connect(_on_fruit_changed)
			_player.babies_changed.connect(_on_babies_changed)
			_player.growth_stage_changed.connect(_on_growth_stage_changed)
			_on_fruit_changed(_player.fruit_count)
			_on_babies_changed(_player.baby_count())
		if _player.has_signal("wing_energy_changed"):
			_player.wing_energy_changed.connect(_on_wing_energy_changed)
			_on_wing_energy_changed(_player.wing_energy, _player.max_wing_energy)
		else:
			$WingDial.visible = false
			$WingLabel.visible = false
		if _player.has_signal("damaged"):
			_player.damaged.connect(_on_player_damaged)
		if _player.has_signal("weapon_changed"):
			_player.weapon_changed.connect(_on_weapon_changed)
			_player.shield_changed.connect(_on_shield_changed)
			if _player.has_signal("weapon_ready_changed"):
				_player.weapon_ready_changed.connect(_on_weapon_ready_changed)
			if _player.has_signal("shield_blocked"):
				_player.shield_blocked.connect(_on_shield_blocked)
			_on_weapon_changed(_player.active_weapon)
			_on_shield_changed(_player.has_shield)
		else:
			_weapon_label.visible = false
			_shield_label.visible = false


func _process(_delta: float) -> void:
	if _debug_label.visible and _player:
		var vel: Vector2 = Vector2(_player.velocity.x, _player.velocity.y)
		_debug_label.text = "FPS %d\nvel (%.1f, %.1f)\nfloor %s  wall %s\nhealth %.1f  food %d\ndash ready %s" % [
			Engine.get_frames_per_second(),
			vel.x, vel.y,
			_player.is_on_floor(), _player.is_on_wall(),
			_player.health, _player.food,
			_player.dash_ready,
		]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		_debug_label.visible = not _debug_label.visible
		var gm := get_node_or_null("/root/GameManager")
		if gm:
			gm.debug_enabled = _debug_label.visible
	elif event.is_action_pressed("pause"):
		set_paused(not get_tree().paused)


# --- pause menu ---------------------------------------------------------------
# Built in code on first use, like the boss bar. Plain Buttons, so Godot's own
# focus navigation gives keyboard and controller movement for free, and touch
# gets tapping for free as well — no bespoke input handling to keep in sync.

var _pause_menu: Control
var _music_button: Button
var _sfx_button: Button


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	if _pause_menu == null:
		_build_pause_menu()
	_pause_menu.visible = paused
	if paused:
		_refresh_audio_buttons()
		_music_button.grab_focus()
	else:
		_message_label.visible = false


func _build_pause_menu() -> void:
	_pause_menu = Control.new()
	_pause_menu.name = "PauseMenu"
	_pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The HUD is PROCESS_MODE_ALWAYS, but be explicit: a pause menu that pauses
	# with the tree is a menu you cannot use.
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_menu.visible = false
	add_child(_pause_menu)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.03, 0.05, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_menu.add_child(dim)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.custom_minimum_size = Vector2(300, 0)
	column.add_theme_constant_override("separation", 10)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_menu.add_child(column)

	var display_font := _message_label.get_theme_font("font")

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if display_font:
		title.add_theme_font_override("font", display_font)
	title.add_theme_font_size_override("font_size", 34)
	column.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	column.add_child(spacer)

	_music_button = _menu_button(column, display_font, _on_music_pressed)
	_sfx_button = _menu_button(column, display_font, _on_sfx_pressed)
	var resume := _menu_button(column, display_font, func() -> void: set_paused(false))
	resume.text = "RESUME"


func _menu_button(parent: Node, font: Font, pressed: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(300, 42)
	button.focus_mode = Control.FOCUS_ALL
	if font:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(pressed)
	parent.add_child(button)
	return button


func _on_music_pressed() -> void:
	Snd.set_music_enabled(not Snd.music_enabled())
	_refresh_audio_buttons()


func _on_sfx_pressed() -> void:
	Snd.set_sfx_enabled(not Snd.sfx_enabled())
	_refresh_audio_buttons()
	if Snd.sfx_enabled():
		Snd.sfx("crumb") # so turning it back on proves itself


## State has to be obvious at a glance, not inferred from silence.
func _refresh_audio_buttons() -> void:
	if _music_button == null:
		return
	_music_button.text = "MUSIC        %s" % ("ON" if Snd.music_enabled() else "OFF")
	_sfx_button.text = "SOUND FX     %s" % ("ON" if Snd.sfx_enabled() else "OFF")


# --- player damage ------------------------------------------------------------

var _damage_flash: ColorRect
var _damage_tween: Tween


func _on_player_damaged(_amount: int, blocked: bool) -> void:
	# Blue for a block, red for a hit that got through: the tint is the fastest
	# way to read what just happened without looking at the hearts.
	_pulse_damage(Color(0.5, 0.75, 1.0) if blocked else Color(0.85, 0.1, 0.12))


## Brief, shallow, never strobing — feedback has to be obvious without becoming
## excessive flashing.
func _pulse_damage(color: Color) -> void:
	if _damage_flash == null:
		_damage_flash = ColorRect.new()
		_damage_flash.name = "DamageFlash"
		_damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_damage_flash)
		move_child(_damage_flash, 1) # over the vignette, under the readouts
	_damage_flash.color = Color(color.r, color.g, color.b, 0.0)
	if _damage_tween:
		_damage_tween.kill()
	_damage_tween = create_tween()
	_damage_tween.tween_property(_damage_flash, "color:a", 0.22, 0.05)
	_damage_tween.tween_property(_damage_flash, "color:a", 0.0, 0.28)


# --- boss health -------------------------------------------------------------
# Built in code on first use so hud.tscn stays the hand-edited layout it is.
# Only BOSSES get this bar; normal enemies keep their little world-space one
# (enemies/enemy_health_bar.gd), which is what makes a boss read as a boss.

var _boss_bar: Control
var _boss_fill: ColorRect
var _boss_name: Label


func show_boss_bar(title: String) -> void:
	if _boss_bar == null:
		_build_boss_bar()
	_boss_name.text = title
	_boss_bar.visible = true


func hide_boss_bar() -> void:
	if _boss_bar:
		_boss_bar.visible = false


func set_boss_health(current: int, max_value: int) -> void:
	if _boss_bar == null or max_value <= 0:
		return
	var ratio := clampf(float(current) / float(max_value), 0.0, 1.0)
	_boss_fill.anchor_right = ratio
	# Same green -> orange -> red read as the world-space enemy bars, so the
	# two never disagree about what "nearly dead" looks like.
	if ratio > 0.55:
		_boss_fill.color = Color(0.3, 0.85, 0.35)
	elif ratio > 0.28:
		_boss_fill.color = Color(0.95, 0.6, 0.2)
	else:
		_boss_fill.color = Color(0.9, 0.2, 0.2)


func _build_boss_bar() -> void:
	_boss_bar = Control.new()
	_boss_bar.name = "BossBar"
	_boss_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_bar.offset_top = 52.0
	_boss_bar.offset_bottom = 108.0
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.visible = false
	add_child(_boss_bar)

	_boss_name = Label.new()
	_boss_name.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_name.offset_bottom = 26.0
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Borrow the Message label's face rather than hardcoding a path: a boss name
	# is a display moment, same tier as the popup (see CLAUDE.md font rule).
	var display_font := _message_label.get_theme_font("font")
	if display_font:
		_boss_name.add_theme_font_override("font", display_font)
	_boss_name.add_theme_font_size_override("font_size", 20)
	_boss_name.add_theme_color_override("font_color", Color(1, 0.6, 0.55))
	_boss_bar.add_child(_boss_name)

	var track := ColorRect.new()
	track.anchor_left = 0.22
	track.anchor_right = 0.78
	track.anchor_top = 0.58
	track.anchor_bottom = 1.0
	track.offset_left = 0.0
	track.offset_right = 0.0
	track.color = Color(0.07, 0.07, 0.1, 0.85)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.add_child(track)

	_boss_fill = ColorRect.new()
	_boss_fill.anchor_left = 0.0
	_boss_fill.anchor_right = 1.0
	_boss_fill.anchor_top = 0.0
	_boss_fill.anchor_bottom = 1.0
	_boss_fill.offset_left = 3.0
	_boss_fill.offset_top = 3.0
	_boss_fill.offset_right = -3.0
	_boss_fill.offset_bottom = -3.0
	_boss_fill.color = Color(0.3, 0.85, 0.35)
	_boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_boss_fill)


## duration 0 keeps the message on screen.
func show_message(text: String, duration := 2.0) -> void:
	if _message_tween:
		_message_tween.kill()
	_message_label.text = text
	_message_label.visible = true
	_message_label.modulate.a = 1.0
	if duration > 0.0:
		_message_tween = create_tween()
		_message_tween.tween_interval(duration)
		_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.4)
		_message_tween.tween_callback(func() -> void: _message_label.visible = false)


func _on_health_changed(current: float, max_value: int) -> void:
	_hearts.set_health(current, max_value)


func _on_food_changed(count: int) -> void:
	_food_label.text = "CRUMBS  %d" % count


func _on_fruit_changed(count: int) -> void:
	$Fruit.text = "FRUIT  %d" % count


func _on_babies_changed(following: int) -> void:
	$Babies.text = "BABIES  %d" % following


## SQUISHED is reserved for being crushed — a swatter, a foot, a paw. Using it
## for everything told the player nothing about what had just killed them, and
## made the one genuinely crushing death land like any other.
const DEATH_MESSAGES := {
	"swat": "SQUISHED!",
	"stomp": "SQUISHED!",
	"paw": "SQUISHED!",
	"pounce": "SQUISHED!",
	"shake": "SHAKEN OFF!",
	"spray": "SPRAYED!",
	"poison": "POISONED!",
	"acid": "DISSOLVED!",
	"water": "WASHED AWAY!",
	"fall": "SPLAT!",
	"spider": "THE SPIDER GOT HIM!",
	"ant": "THE ANTS GOT HIM!",
	"fly": "THE FLY GOT HIM!",
	"rat": "THE RAT GOT HIM!",
}
const DEATH_DEFAULT := "HARRY'S HAD IT!"


func _on_player_died() -> void:
	var cause := ""
	if _player and "death_cause" in _player:
		cause = _player.death_cause
	show_message(DEATH_MESSAGES.get(cause, DEATH_DEFAULT), 1.4)


## Each stage names the trade, not just the waistline. Eating used to read as
## pure punishment; it is a build choice, and the message is where the player
## finds that out.
const GROWTH_LINES := [
	"",
	"Rounder - and steadier on your feet",
	"Plump! Harder to shove, slower to run",
	"Chunky! Hits harder, flies worse",
	"ABSOLUTE UNIT - a wrecking ball that cannot fly",
]

func _on_growth_stage_changed(stage: int) -> void:
	if stage >= 1 and stage < GROWTH_LINES.size():
		show_message(GROWTH_LINES[stage], 1.6)


func _on_wing_energy_changed(current: float, max_value: float) -> void:
	$WingDial.set_energy(current, max_value)


func _on_weapon_changed(id: String) -> void:
	_weapon_id = id
	_refresh_weapon_label()


func _on_weapon_ready_changed(ready: bool) -> void:
	_weapon_ready = ready
	_refresh_weapon_label()


## The prompt names the action, not just the item: X - BITE bare-mouthed,
## X - HIT with something in hand. ASCII only — the display font has no dashes
## beyond the plain hyphen (see CLAUDE.md).
func _refresh_weapon_label() -> void:
	if _weapon_id == "bite":
		_weapon_label.text = "X - BITE"
		return
	var stats: Dictionary = Player3D.WEAPON_STATS.get(_weapon_id, {})
	var label: String = stats.get("label", _weapon_id.to_upper())
	_weapon_label.text = "X - HIT   %s%s   (N/M)" % [
		label, "  *READY*" if _weapon_ready else ""]


func _on_shield_changed(equipped: bool) -> void:
	_shield_label.visible = equipped
	if equipped and _player:
		_on_shield_blocked(_player.shield_hits)


## Condition, not just presence: "SHIELD" told the player nothing about how
## close it was to giving out.
func _on_shield_blocked(remaining: int) -> void:
	_shield_label.text = "SHIELD  %s" % "#".repeat(maxi(remaining, 0))


func _on_achievement_unlocked(title: String) -> void:
	Snd.sfx("complete")
	show_message("ACHIEVEMENT UNLOCKED\n%s" % title, 3.5)
