extends CanvasLayer

## HUD: health pips, food count, centre messages, and the F3 debug overlay.
## Wired to a player *instance* via player_path (see rule 45 in GAME.md).

@export var player_path: NodePath

# Duck-typed so both the 2D Player and 3D Player3D work.
var _player: Node
var _message_tween: Tween

@onready var _hearts: Control = $Health
@onready var _food_label: Label = $Food
@onready var _message_label: Label = $Message
@onready var _debug_label: Label = $Debug


func _ready() -> void:
	_player = get_node_or_null(player_path)
	if _player:
		_player.health_changed.connect(_on_health_changed)
		_player.food_changed.connect(_on_food_changed)
		_player.died.connect(func() -> void: show_message("SQUISHED!", 1.2))
		_on_health_changed(_player.health, _player.max_health)
		_on_food_changed(_player.food)
		if _player.has_signal("fruit_changed"):
			_player.fruit_changed.connect(_on_fruit_changed)
			_player.babies_changed.connect(_on_babies_changed)
			_player.growth_stage_changed.connect(_on_growth_stage_changed)
			_on_fruit_changed(_player.fruit_count)
			_on_babies_changed(_player.carried_babies.size())
		if _player.has_signal("wing_energy_changed"):
			_player.wing_energy_changed.connect(_on_wing_energy_changed)
			_on_wing_energy_changed(_player.wing_energy, _player.max_wing_energy)
		else:
			$WingDial.visible = false
			$WingLabel.visible = false


func _process(_delta: float) -> void:
	if _debug_label.visible and _player:
		var vel: Vector2 = Vector2(_player.velocity.x, _player.velocity.y)
		_debug_label.text = "FPS %d\nvel (%.1f, %.1f)\nfloor %s  wall %s\nhealth %d  food %d\ndash ready %s" % [
			Engine.get_frames_per_second(),
			vel.x, vel.y,
			_player.is_on_floor(), _player.is_on_wall(),
			_player.health, _player.food,
			_player.dash_ready,
		]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		_debug_label.visible = not _debug_label.visible
		GameManager.debug_enabled = _debug_label.visible
	elif event.is_action_pressed("pause"):
		var tree := get_tree()
		tree.paused = not tree.paused
		if tree.paused:
			show_message("PAUSED", 0.0)
		else:
			_message_label.visible = false


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


func _on_health_changed(current: int, max_value: int) -> void:
	_hearts.set_health(current, max_value)


func _on_food_changed(count: int) -> void:
	_food_label.text = "CRUMBS  %d" % count


func _on_fruit_changed(count: int) -> void:
	$Fruit.text = "FRUIT  %d" % count


func _on_babies_changed(carried: int) -> void:
	$Babies.text = "BABIES  riding %d / safe %d" % [carried, GameManager.babies_banked]


const GROWTH_LINES := ["", "Getting rounder...", "Quite plump!", "Seriously chunky!", "ABSOLUTE UNIT"]

func _on_growth_stage_changed(stage: int) -> void:
	if stage >= 1 and stage < GROWTH_LINES.size():
		show_message(GROWTH_LINES[stage], 1.6)


func _on_wing_energy_changed(current: float, max_value: float) -> void:
	$WingDial.set_energy(current, max_value)
