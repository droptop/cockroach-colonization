extends BaseEnemy

## Phase 1 spider: PATROL -> CHASE -> ATTACK (telegraphed lunge) -> back, DEAD.
## Detection is an Area2D radius; sight is lost past lose_sight_distance.

enum State { PATROL, CHASE, ATTACK, DEAD }

@export_group("Patrol")
@export var patrol_speed := 60.0
@export var patrol_distance := 130.0
@export var patrol_pause := 0.8

@export_group("Chase")
@export var chase_speed := 150.0
@export var lose_sight_distance := 340.0

@export_group("Attack")
@export var attack_range := 46.0
## Telegraph delay before the lunge so the player can react.
@export var attack_windup := 0.25
@export var lunge_speed := 300.0
@export var lunge_duration := 0.3
@export var attack_cooldown := 1.0

@export_group("Physics")
@export var gravity := 1500.0

var state := State.PATROL

var _origin := Vector2.ZERO
var _patrol_dir := 1
var _pause_timer := 0.0
var _windup_timer := 0.0
var _lunge_timer := 0.0
var _cooldown_timer := 0.0
var _lunge_dir := 1.0
var _target: Node2D

@onready var _visual: Node2D = $Visual
@onready var _hitbox: Area2D = $Hitbox


func _ready() -> void:
	super()
	_origin = global_position


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 900.0)
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)

	match state:
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_chase()
		State.ATTACK:
			_attack(delta)

	move_and_slide()
	_damage_overlapping_player()
	if absf(velocity.x) > 1.0:
		_visual.scale.x = signf(velocity.x)


func _patrol(delta: float) -> void:
	if _pause_timer > 0.0:
		_pause_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		if _pause_timer <= 0.0:
			_patrol_dir = -_patrol_dir
		return
	velocity.x = _patrol_dir * patrol_speed
	var past_bound := (_patrol_dir > 0 and global_position.x >= _origin.x + patrol_distance) \
		or (_patrol_dir < 0 and global_position.x <= _origin.x - patrol_distance)
	if past_bound or is_on_wall():
		_pause_timer = patrol_pause


func _chase() -> void:
	if not is_instance_valid(_target):
		_return_to_patrol()
		return
	var to_target := _target.global_position - global_position
	if to_target.length() > lose_sight_distance:
		_target = null
		_return_to_patrol()
		return
	if absf(to_target.x) <= attack_range and _cooldown_timer <= 0.0:
		state = State.ATTACK
		_windup_timer = attack_windup
		_lunge_timer = 0.0
		_lunge_dir = signf(to_target.x) if to_target.x != 0.0 else 1.0
		_visual.scale.x = _lunge_dir
		return
	velocity.x = signf(to_target.x) * chase_speed


func _attack(delta: float) -> void:
	if _windup_timer > 0.0:
		# Telegraph: freeze and crouch slightly before lunging.
		_windup_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
		_visual.scale.y = 0.8
		if _windup_timer <= 0.0:
			velocity = Vector2(_lunge_dir * lunge_speed, -120.0)
			_lunge_timer = lunge_duration
			_visual.scale.y = 1.0
		return
	_lunge_timer -= delta
	if _lunge_timer <= 0.0:
		_cooldown_timer = attack_cooldown
		state = State.CHASE if is_instance_valid(_target) else State.PATROL


func _return_to_patrol() -> void:
	state = State.PATROL
	_pause_timer = 0.0


func _damage_overlapping_player() -> void:
	for body in _hitbox.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(contact_damage, global_position)


func die() -> void:
	state = State.DEAD
	_hitbox.set_deferred("monitoring", false)
	$DetectionArea.set_deferred("monitoring", false)
	super()


func _on_detection_area_body_entered(body: Node2D) -> void:
	if state == State.DEAD or not body.is_in_group("player"):
		return
	_target = body
	if state == State.PATROL:
		state = State.CHASE


func _on_detection_area_body_exited(_body: Node2D) -> void:
	# Sight loss is distance-based in _chase(); nothing to do here yet.
	pass
