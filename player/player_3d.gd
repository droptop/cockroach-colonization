class_name Player3D
extends CharacterBody3D

## Harry in 3D: same movement feel as the 2D controller, ported to metres and
## +Y-up. Motion is locked to the X/Y plane (axis_lock_linear_z) so gameplay
## stays a side-scrolling platformer inside a 3D world.

signal health_changed(current: int, max_value: int)
signal food_changed(count: int)
signal died
signal respawned

@export_group("Run")
@export var run_speed := 4.5
@export var ground_acceleration := 45.0
@export var ground_deceleration := 55.0
@export var air_acceleration := 30.0
@export var air_deceleration := 18.0

@export_group("Jump")
@export var gravity := 26.0
@export var max_fall_speed := 18.0
@export var jump_velocity := 8.8
## Upward velocity is multiplied by this when jump is released early (variable height).
@export_range(0.0, 1.0) var jump_cut_multiplier := 0.45
@export var coyote_time := 0.10
@export var jump_buffer_time := 0.12

@export_group("Wall")
@export var wall_slide_speed := 2.2
## x = push away from wall, y = upward kick.
@export var wall_jump_velocity := Vector2(4.8, 7.6)
@export var wall_jump_lockout := 0.12

@export_group("Dash")
@export var dash_speed := 9.0
@export var dash_duration := 0.16
@export var dash_cooldown := 0.35

@export_group("Combat")
@export var max_health := 5
@export var bite_damage := 1
@export var bite_cooldown := 0.3
@export var invincibility_time := 0.8
@export var hurt_knockback := Vector2(3.6, 4.6)
@export var respawn_delay := 2.2

var health := 5
var food := 0
var facing := 1
var spawn_position := Vector3.ZERO
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

@onready var _visual: Node3D = $Visual
@onready var _bite_area: Area3D = $Visual/BiteArea
@onready var _collision: CollisionShape3D = $CollisionShape3D


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
	velocity.y = maxf(velocity.y - gravity * delta, -max_fall_speed)
	# Wall slide only while actively pushing into the wall, so letting go drops cleanly.
	if is_on_wall_only() and direction != 0.0 and velocity.y < 0.0:
		velocity.y = maxf(velocity.y, -wall_slide_speed)


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
			velocity.x = wall_jump_velocity.x * away
			velocity.y = wall_jump_velocity.y
			_wall_jump_lockout_timer = wall_jump_lockout
			_jump_buffer_timer = 0.0
			_squash = Vector2(0.75, 1.25)
	if Input.is_action_just_released("jump") and velocity.y > 0.0:
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
	velocity = Vector3(dash_dir * dash_speed, 0.0, 0.0)
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


func take_damage(amount: int, from_position: Vector3) -> void:
	if is_dead or _invincibility_timer > 0.0:
		return
	health = clampi(health - amount, 0, max_health)
	health_changed.emit(health, max_health)
	_invincibility_timer = invincibility_time
	var away := signf(global_position.x - from_position.x)
	if away == 0.0:
		away = -float(facing)
	velocity = Vector3(hurt_knockback.x * away, hurt_knockback.y, 0.0)
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
		velocity = Vector3.ZERO
		_invincibility_timer = invincibility_time


func collect_food(value: int) -> void:
	food += value
	food_changed.emit(food)


func _die() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	_collision.set_deferred("disabled", true)
	died.emit()
	_spawn_death_cry()
	# "AAHH!" — little hop, keel over flat on his back, legs in the air.
	var tween := create_tween()
	tween.tween_property(_visual, "position:y", 0.5, 0.16).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_visual, "rotation:z", PI, 0.32)
	tween.tween_property(_visual, "position:y", 0.3, 0.14).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.25)
	tween.tween_callback(_spawn_ghost)
	await get_tree().create_timer(respawn_delay).timeout
	_respawn()


## Floating "AAHH!" text at the moment of death.
func _spawn_death_cry() -> void:
	var cry := Label3D.new()
	cry.text = "AAHH!"
	cry.font_size = 56
	cry.pixel_size = 0.008
	cry.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cry.modulate = Color(1, 1, 1, 0.95)
	cry.outline_size = 14
	get_parent().add_child(cry)
	cry.global_position = global_position + Vector3(0, 0.9, 0.4)
	var tween := cry.create_tween()
	tween.tween_property(cry, "position:y", cry.position.y + 0.9, 0.8).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(cry, "modulate:a", 0.0, 0.9)
	tween.tween_callback(cry.queue_free)


## White translucent ghost-Harry twirls up into the air.
func _spawn_ghost() -> void:
	var ghost := Node3D.new()
	ghost.set_script(load("res://player/roach_visual_3d.gd"))
	ghost.shell_color = Color(1, 1, 1, 0.45)
	ghost.body_color = Color(0.95, 0.98, 1, 0.45)
	ghost.blush_color = Color(1, 1, 1, 0.3)
	get_parent().add_child(ghost)
	ghost.global_position = global_position + Vector3(0, 0.25, 0)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "position:y", ghost.position.y + 3.0, 1.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ghost, "rotation:y", TAU * 2.5, 1.5)
	tween.parallel().tween_property(ghost, "scale", Vector3.ONE * 0.05, 1.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(ghost.queue_free)


func _respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	health = max_health
	food = 0
	is_dead = false
	_collision.set_deferred("disabled", false)
	_invincibility_timer = invincibility_time
	_visual.scale = Vector3.ONE
	_visual.rotation = Vector3.ZERO
	_visual.position = Vector3.ZERO
	_squash = Vector2.ONE
	health_changed.emit(health, max_health)
	food_changed.emit(food)
	respawned.emit()


func _update_visual(direction: float, delta: float) -> void:
	if direction != 0.0:
		facing = int(signf(direction))
	# Smoothly turn the roach around instead of snapping.
	var target_yaw := 0.0 if facing > 0 else PI
	_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, minf(14.0 * delta, 1.0))
	_squash = _squash.lerp(Vector2.ONE, minf(12.0 * delta, 1.0))
	if _dash_timer > 0.0:
		_visual.scale = Vector3(1.35, 0.65, 1.0)
	else:
		_visual.scale = Vector3(_squash.x, _squash.y, 1.0)
	# Blink while invincible after a hit.
	if _invincibility_timer > 0.0:
		_visual.visible = fmod(_invincibility_timer, 0.15) >= 0.075
	else:
		_visual.visible = true
