class_name Player
extends CharacterBody2D

## Harry Cockroach — Phase 1 movement + combat controller.
## Every feel-critical number is exported so it can be tuned live in the Inspector.

signal health_changed(current: int, max_value: int)
signal food_changed(count: int)
signal died
signal respawned

@export_group("Run")
@export var run_speed := 220.0
@export var ground_acceleration := 2200.0
@export var ground_deceleration := 2800.0
@export var air_acceleration := 1500.0
@export var air_deceleration := 900.0

@export_group("Jump")
@export var gravity := 1500.0
@export var max_fall_speed := 900.0
@export var jump_velocity := -390.0
## Upward velocity is multiplied by this when jump is released early (variable height).
@export_range(0.0, 1.0) var jump_cut_multiplier := 0.45
@export var coyote_time := 0.10
@export var jump_buffer_time := 0.12

@export_group("Wall")
@export var wall_slide_speed := 110.0
## x = push away from wall, y = upward kick.
@export var wall_jump_velocity := Vector2(250.0, -350.0)
## Steering is ignored briefly after a wall jump so the player can't instantly re-stick.
@export var wall_jump_lockout := 0.12

@export_group("Dash")
@export var dash_speed := 430.0
@export var dash_duration := 0.16
@export var dash_cooldown := 0.35

@export_group("Combat")
@export var max_health := 5
@export var bite_damage := 1
@export var bite_cooldown := 0.3
@export var invincibility_time := 0.8
@export var hurt_knockback := Vector2(180.0, -220.0)
@export var respawn_delay := 1.2

var health := 5
var food := 0
var facing := 1
var spawn_position := Vector2.ZERO
var is_dead := false
var dash_ready: bool:
	get: return _dash_available and _dash_cooldown_timer <= 0.0

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _wall_jump_lockout_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _dash_available := true
var _bite_cooldown_timer := 0.0
var _invincibility_timer := 0.0
var _was_on_floor := false
var _squash := Vector2.ONE

@onready var _visual: Node2D = $Visual
@onready var _bite_area: Area2D = $Visual/BiteArea
@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	health = max_health
	spawn_position = global_position
	health_changed.emit(health, max_health)
	food_changed.emit(food)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_tick_timers(delta)
	var direction := Input.get_axis("move_left", "move_right")

	if _dash_timer > 0.0:
		velocity.y = 0.0 # dash ignores gravity for its whole duration
	else:
		_apply_gravity(direction, delta)
		_handle_jump()
		_apply_run(direction, delta)
		_handle_dash_input(direction)
	_handle_bite()

	move_and_slide()

	if is_on_floor() and not _was_on_floor:
		_squash = Vector2(1.3, 0.7) # landing squash
	_was_on_floor = is_on_floor()

	_update_visual(direction, delta)


func _tick_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
		_dash_available = true
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_wall_jump_lockout_timer = maxf(_wall_jump_lockout_timer - delta, 0.0)
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_bite_cooldown_timer = maxf(_bite_cooldown_timer - delta, 0.0)
	_invincibility_timer = maxf(_invincibility_timer - delta, 0.0)


func _apply_gravity(direction: float, delta: float) -> void:
	if is_on_floor():
		return
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	# Wall slide only while actively pushing into the wall, so letting go drops cleanly.
	if is_on_wall_only() and direction != 0.0 and velocity.y > 0.0:
		velocity.y = minf(velocity.y, wall_slide_speed)


func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	if _jump_buffer_timer > 0.0:
		if is_on_floor() or _coyote_timer > 0.0:
			velocity.y = jump_velocity
			_jump_buffer_timer = 0.0
			_coyote_timer = 0.0
			_squash = Vector2(0.75, 1.25)
		elif is_on_wall_only():
			var away := get_wall_normal().x
			velocity = Vector2(wall_jump_velocity.x * away, wall_jump_velocity.y)
			_wall_jump_lockout_timer = wall_jump_lockout
			_jump_buffer_timer = 0.0
			_squash = Vector2(0.75, 1.25)
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


func _apply_run(direction: float, delta: float) -> void:
	if _wall_jump_lockout_timer > 0.0:
		return # keep wall-jump momentum
	var target := direction * run_speed
	var accel: float
	if is_on_floor():
		accel = ground_acceleration if direction != 0.0 else ground_deceleration
	else:
		accel = air_acceleration if direction != 0.0 else air_deceleration
	velocity.x = move_toward(velocity.x, target, accel * delta)


func _handle_dash_input(direction: float) -> void:
	if not Input.is_action_just_pressed("dash"):
		return
	if not _dash_available or _dash_cooldown_timer > 0.0:
		return
	var dash_dir := signf(direction) if direction != 0.0 else float(facing)
	velocity = Vector2(dash_dir * dash_speed, 0.0)
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	_dash_available = is_on_floor() # one air dash until grounded again
	_squash = Vector2(1.35, 0.65)


func _handle_bite() -> void:
	if not Input.is_action_just_pressed("attack") or _bite_cooldown_timer > 0.0:
		return
	_bite_cooldown_timer = bite_cooldown
	_squash = Vector2(1.2, 0.9)
	for body in _bite_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(bite_damage, global_position)


func take_damage(amount: int, from_position: Vector2) -> void:
	if is_dead or _invincibility_timer > 0.0:
		return
	health = clampi(health - amount, 0, max_health)
	health_changed.emit(health, max_health)
	_invincibility_timer = invincibility_time
	var away := signf(global_position.x - from_position.x)
	if away == 0.0:
		away = -float(facing)
	velocity = Vector2(hurt_knockback.x * away, hurt_knockback.y)
	_dash_timer = 0.0
	if health <= 0:
		_die()


## Pits knock off one health and reset to the spawn point instead of instant death.
func fall_into_pit() -> void:
	if is_dead:
		return
	_invincibility_timer = 0.0
	take_damage(1, global_position)
	if not is_dead:
		global_position = spawn_position
		velocity = Vector2.ZERO
		_invincibility_timer = invincibility_time


func collect_food(value: int) -> void:
	food += value
	food_changed.emit(food)


func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	_collision.set_deferred("disabled", true)
	died.emit()
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector2(1.6, 0.15), 0.3)
	await get_tree().create_timer(respawn_delay).timeout
	_respawn()


func _respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	health = max_health
	food = 0
	is_dead = false
	_collision.set_deferred("disabled", false)
	_invincibility_timer = invincibility_time
	_visual.scale = Vector2.ONE
	_squash = Vector2.ONE
	health_changed.emit(health, max_health)
	food_changed.emit(food)
	respawned.emit()


func _update_visual(direction: float, delta: float) -> void:
	if direction != 0.0:
		facing = int(signf(direction))
	_squash = _squash.lerp(Vector2.ONE, minf(12.0 * delta, 1.0))
	if _dash_timer > 0.0:
		_visual.scale = Vector2(facing * 1.35, 0.65)
	else:
		_visual.scale = Vector2(facing * _squash.x, _squash.y)
	# Blink while invincible after a hit.
	if _invincibility_timer > 0.0:
		_visual.modulate.a = 0.35 if fmod(_invincibility_timer, 0.15) < 0.075 else 1.0
	else:
		_visual.modulate.a = 1.0
