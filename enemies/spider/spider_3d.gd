class_name Spider3D
extends CharacterBody3D

## 3D port of the spider: PATROL -> CHASE -> ATTACK (telegraphed lunge) -> DEAD.
## Kept self-contained rather than sharing the 2D BaseEnemy — the two worlds
## will diverge and a forced common base would fight both.

signal enemy_died

enum State { PATROL, CHASE, ATTACK, DEAD }

@export_group("Stats")
@export var max_health := 3
@export var contact_damage := 1

@export_group("Patrol")
@export var patrol_speed := 1.2
@export var patrol_distance := 2.6
@export var patrol_pause := 0.8

@export_group("Chase")
@export var chase_speed := 2.5
@export var lose_sight_distance := 5.0

@export_group("Attack")
@export var attack_range := 0.95
@export var attack_windup := 0.25
@export var lunge_speed := 6.0
@export var lunge_duration := 0.3
@export var attack_cooldown := 1.0

@export_group("Physics")
@export var gravity := 26.0

var state := State.PATROL
## Frozen by the antennae pulse while this is above zero.
var _stagger_timer := 0.0
var health := 3

var _origin := Vector3.ZERO
var _patrol_dir := 1
var _pause_timer := 0.0
var _windup_timer := 0.0
var _lunge_timer := 0.0
var _cooldown_timer := 0.0
var _lunge_dir := 1.0
var _target: Node3D

@onready var _visual: Node3D = $Visual
@onready var _hitbox: Area3D = $Hitbox


var _hp_bar: EnemyHealthBar


func _ready() -> void:
	health = max_health
	_origin = global_position
	_hp_bar = EnemyHealthBar.new()
	_hp_bar.position = Vector3(0, 1.1, 0)
	add_child(_hp_bar)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _stagger_timer > 0.0:
		_stagger_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		if not is_on_floor():
			velocity.y = maxf(velocity.y - gravity * delta, -18.0)
		move_and_slide()
		return
	if not is_on_floor():
		velocity.y = maxf(velocity.y - gravity * delta, -18.0)
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
	if absf(velocity.x) > 0.05:
		var target_yaw := 0.0 if velocity.x > 0.0 else PI
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, 0.3)


func _patrol(delta: float) -> void:
	if _pause_timer > 0.0:
		_pause_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		if _pause_timer <= 0.0:
			_patrol_dir = -_patrol_dir
		return
	velocity.x = _patrol_dir * patrol_speed
	var past_bound := (_patrol_dir > 0 and global_position.x >= _origin.x + patrol_distance) \
		or (_patrol_dir < 0 and global_position.x <= _origin.x - patrol_distance)
	if past_bound or is_on_wall() or not _floor_ahead(float(_patrol_dir)):
		_pause_timer = patrol_pause


func _chase() -> void:
	if not is_instance_valid(_target):
		state = State.PATROL
		return
	var to_target := _target.global_position - global_position
	if to_target.length() > lose_sight_distance:
		_target = null
		state = State.PATROL
		return
	if absf(to_target.x) <= attack_range and _cooldown_timer <= 0.0 \
			and Encounter.may_commit(self, _target):
		# Keeps chasing if the gate says no, so a spider waiting its turn still
		# closes and postures rather than standing there looking switched off.
		Encounter.commit(self)
		state = State.ATTACK
		_windup_timer = attack_windup
		_lunge_timer = 0.0
		_lunge_dir = signf(to_target.x) if to_target.x != 0.0 else 1.0
		_visual.rotation.y = 0.0 if _lunge_dir > 0 else PI
		return
	var chase_dir := signf(to_target.x)
	if _floor_ahead(chase_dir):
		velocity.x = chase_dir * chase_speed
	else:
		velocity.x = 0.0 # don't chase off a ledge


func _attack(delta: float) -> void:
	if _windup_timer > 0.0:
		# Telegraph: freeze and crouch slightly before lunging.
		_windup_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
		_visual.scale.y = 0.8
		if _windup_timer <= 0.0:
			velocity.x = _lunge_dir * lunge_speed
			velocity.y = 2.4
			_lunge_timer = lunge_duration
			_visual.scale.y = 1.0
		return
	_lunge_timer -= delta
	if _lunge_timer <= 0.0:
		Encounter.release(self)
		_cooldown_timer = attack_cooldown
		state = State.CHASE if is_instance_valid(_target) else State.PATROL


func _damage_overlapping_player() -> void:
	for body in _hitbox.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(contact_damage, global_position, "spider")
			# And bounce off him rather than standing inside him.
			Encounter.bump(self, body.global_position,
				body.fullness if "fullness" in body else 0.0)


## `cause` is accepted and ignored here — it only decides the PLAYER's
## death message. Taking it keeps one duck-typed signature across
## everything that can be hurt, so a caller never has to ask what it is
## hitting before it hits it.
func take_damage(amount: int, from_position: Vector3, _cause := "") -> void:
	if health <= 0:
		return
	health -= amount
	_flash()
	_hp_bar.set_ratio(float(health) / max_health)
	Fx.spark_burst(get_parent(), global_position + Vector3(0, 0.5, 0))
	var away := signf(global_position.x - from_position.x)
	velocity.x += away * 3.2
	velocity.y += 1.6
	if health <= 0:
		Encounter.release(self)
		die()


func die() -> void:
	state = State.DEAD
	enemy_died.emit()
	set_physics_process(false)
	$CollisionShape3D.set_deferred("disabled", true)
	_hitbox.set_deferred("monitoring", false)
	$DetectionArea.set_deferred("monitoring", false)
	Snd.sfx("enemy_die", -3.0)
	FoodBurst.spawn(get_parent(), global_position, 2)
	# Knocked up, legs curling, then dropped — a body with weight, rather than
	# something that flattens where it stood.
	var start_y := position.y
	var tween := create_tween()
	tween.tween_property(self, "position:y", start_y + 1.1, 0.22
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(_visual, "rotation:z", PI * 0.85, 0.34)
	tween.parallel().tween_property(_visual, "scale", Vector3(0.85, 1.15, 0.85), 0.2)
	tween.tween_property(self, "position:y", start_y, 0.26
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", Vector3(1.4, 0.35, 1.4), 0.12)
	# Only once it has landed does the spirit leave it.
	tween.tween_callback(func() -> void:
		Fx.ghost(get_parent(), global_position, 1.0, 6))
	tween.tween_interval(0.45)
	tween.tween_property(self, "scale", Vector3(1.4, 0.02, 1.4), 0.2)
	tween.tween_callback(queue_free)


func _flash() -> void:
	# Squash plus the shared white overlay — the squash alone read as a wobble
	# rather than as damage.
	_visual.scale = Vector3(1.15, 0.8, 1.15)
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3.ONE, 0.18)
	Fx.hit_flash(_visual)


func _on_detection_area_body_entered(body: Node3D) -> void:
	if state == State.DEAD or not body.is_in_group("player"):
		return
	_target = body
	if state == State.PATROL:
		state = State.CHASE


func _on_detection_area_body_exited(_body: Node3D) -> void:
	# Sight loss is distance-based in _chase(); nothing to do here yet.
	pass


func _floor_ahead(dir: float) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(dir * 0.6, 0.4, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -1.6, 0), 1)
	return not space.intersect_ray(query).is_empty()


## Interrupted by Harry's antennae pulse. NO damage on purpose: the pulse has a
## 9 unit radius and no aiming, so anything that hurt would out-range all nine
## weapons and become the only attack worth pressing. What it buys is a moment,
## which is what makes it worth having when something is already on top of you.
func stagger(duration: float) -> void:
	if state == State.DEAD:
		return
	_stagger_timer = maxf(_stagger_timer, duration)
	Fx.hit_flash(_visual, Color(0.75, 1.0, 0.9), 0.18)
