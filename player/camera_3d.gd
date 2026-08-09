extends Camera3D

## Detached follow camera: smooth position tracking, horizontal look-ahead,
## slight downward pitch for the diorama feel. Lives as a child of Player3D
## but goes top-level so the player's transform doesn't drag it around.

@export var follow_offset := Vector3(0.0, 1.8, 8.5)
@export var look_ahead := 1.4
@export var smoothing := 5.0
@export var pitch_degrees := -6.0
@export var shake_decay := 7.0

var _player: Player3D
var _shake_strength := 0.0


func _ready() -> void:
	_player = get_parent() as Player3D
	top_level = true
	rotation_degrees = Vector3(pitch_degrees, 0, 0)
	# Deferred: the player's global transform isn't valid yet during _ready.
	_snap_to_player.call_deferred()


func _snap_to_player() -> void:
	if _player and _player.is_inside_tree():
		global_position = _player.global_position + follow_offset


func _process(delta: float) -> void:
	if _player == null:
		return
	var speed_factor := clampf(absf(_player.velocity.x) / maxf(_player.run_speed, 0.1), 0.2, 1.0)
	var target := _player.global_position + follow_offset
	target.x += _player.facing * look_ahead * speed_factor
	var t := minf(smoothing * delta, 1.0)
	global_position = global_position.lerp(target, t)
	if _shake_strength > 0.005:
		_shake_strength = lerpf(_shake_strength, 0.0, minf(shake_decay * delta, 1.0))
		global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake_strength


func shake(strength: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
