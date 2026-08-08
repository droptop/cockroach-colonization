extends CanvasLayer

## HUD: health pips, food count, centre messages, and the F3 debug overlay.
## Wired to a player *instance* via player_path (see rule 45 in GAME.md).

@export var player_path: NodePath

var _player: Player
var _message_tween: Tween

@onready var _health_label: Label = $Health
@onready var _food_label: Label = $Food
@onready var _message_label: Label = $Message
@onready var _debug_label: Label = $Debug


func _ready() -> void:
	_player = get_node_or_null(player_path) as Player
	if _player:
		_player.health_changed.connect(_on_health_changed)
		_player.food_changed.connect(_on_food_changed)
		_player.died.connect(func() -> void: show_message("SQUISHED!", 1.2))
		_on_health_changed(_player.health, _player.max_health)
		_on_food_changed(_player.food)


func _process(_delta: float) -> void:
	if _debug_label.visible and _player:
		_debug_label.text = "FPS %d\nvel (%.0f, %.0f)\nfloor %s  wall %s\nhealth %d  food %d\ndash ready %s" % [
			Engine.get_frames_per_second(),
			_player.velocity.x, _player.velocity.y,
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
	# ASCII only — the default font in web exports lacks ●/○ glyphs.
	_health_label.text = "HP  " + "#".repeat(current) + "-".repeat(max_value - current)


func _on_food_changed(count: int) -> void:
	_food_label.text = "CRUMBS  %d" % count
