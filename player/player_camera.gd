extends Camera2D

## Follows via built-in position smoothing; adds horizontal look-ahead in the
## direction Harry faces, scaled by how fast he is actually moving.

@export var look_ahead := 56.0
@export var look_ahead_smoothing := 4.0
@export var shake_decay := 8.0

var _shake_strength := 0.0
var _player: Player


func _ready() -> void:
	_player = get_parent() as Player


func _process(delta: float) -> void:
	if _player == null:
		return
	var speed_factor := clampf(absf(_player.velocity.x) / maxf(_player.run_speed, 1.0), 0.2, 1.0)
	var target_x := _player.facing * look_ahead * speed_factor
	var t := minf(look_ahead_smoothing * delta, 1.0)
	offset.x = lerpf(offset.x, target_x, t)
	if _shake_strength > 0.01:
		_shake_strength = lerpf(_shake_strength, 0.0, minf(shake_decay * delta, 1.0))
		offset.y = randf_range(-_shake_strength, _shake_strength)
	else:
		offset.y = 0.0


func shake(strength: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
