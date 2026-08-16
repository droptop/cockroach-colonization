extends CharacterBody3D

## Aerial enemy: hovers around its anchor point bobbing lazily, then dive-bombs
## Harry when he wanders underneath. Returns to its perch after each swoop.

enum State { HOVER, DIVE, RETURN, DEAD }

@export var detect_range := 4.5
@export var dive_speed := 6.5
@export var return_speed := 3.0
@export var dive_cooldown := 2.2
@export var contact_damage := 1
@export var max_health := 2
## What it leaves behind. Flies are the reliable health drop in a game where
## nothing else heals you mid-level.
@export_enum("heart", "energy", "none") var drop_kind := "heart"
@export var drop_amount := 1.0

var state := State.HOVER
var health := 2

var _anchor := Vector3.ZERO
var _time := 0.0
var _cooldown := 0.0
var _dive_target := Vector3.ZERO
var _target: Node3D

@onready var _visual: Node3D = $Visual
@onready var _hitbox: Area3D = $Hitbox


var _hp_bar: EnemyHealthBar


func _ready() -> void:
	health = max_health
	_anchor = global_position
	_hp_bar = EnemyHealthBar.new()
	_hp_bar.position = Vector3(0, 0.7, 0)
	_hp_bar.scale = Vector3.ONE * 0.7
	add_child(_hp_bar)
	_time = randf() * TAU


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	match state:
		State.HOVER:
			var bob := _anchor + Vector3(sin(_time * 1.3) * 0.5, sin(_time * 2.1) * 0.3, 0)
			velocity = (bob - global_position) * 4.0
			velocity.z = 0.0
			if _cooldown <= 0.0 and _acquire_target():
				_dive_target = _target.global_position + Vector3(0, 0.2, 0)
				state = State.DIVE
		State.DIVE:
			var to_target := _dive_target - global_position
			to_target.z = 0.0
			if to_target.length() < 0.3:
				state = State.RETURN
				_cooldown = dive_cooldown
			else:
				velocity = to_target.normalized() * dive_speed
		State.RETURN:
			var back := _anchor - global_position
			back.z = 0.0
			if back.length() < 0.3:
				state = State.HOVER
			else:
				velocity = back.normalized() * return_speed
	move_and_slide()
	if state == State.DIVE and is_on_floor():
		# Smacked the ground — head home.
		state = State.RETURN
		_cooldown = dive_cooldown
	if absf(velocity.x) > 0.1:
		_visual.scale.x = signf(velocity.x)
	for body in _hitbox.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(contact_damage, global_position, "fly")


func _acquire_target() -> bool:
	if not is_instance_valid(_target):
		_target = null
		for node in get_tree().get_nodes_in_group("player"):
			_target = node
			break
	return _target != null \
		and global_position.distance_to(_target.global_position) <= detect_range


## `cause` is accepted and ignored here — it only decides the PLAYER's
## death message. Taking it keeps one duck-typed signature across
## everything that can be hurt, so a caller never has to ask what it is
## hitting before it hits it.
func take_damage(amount: int, from_position: Vector3, _cause := "") -> void:
	if state == State.DEAD:
		return
	health -= amount
	_hp_bar.set_ratio(float(health) / max_health)
	Fx.hit_flash(_visual)
	velocity += Vector3(signf(global_position.x - from_position.x) * 2.0, 1.5, 0)
	if health <= 0:
		_die()


func _die() -> void:
	state = State.DEAD
	set_physics_process(false)
	($CollisionShape3D as CollisionShape3D).set_deferred("disabled", true)
	_hitbox.set_deferred("monitoring", false)
	Fx.ghost(get_parent(), global_position, 0.7, 6)
	Snd.sfx("splat", -6.0)
	_drop_reward()
	# Wings cut out: it stalls, tips over and drops. A flier's death should be
	# the fall itself, not a shrink-and-fade.
	var tween := create_tween()
	tween.tween_property(_visual, "rotation:z", 2.4, 0.5)
	tween.parallel().tween_property(self, "position:y", position.y - 2.6, 0.5
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(self, "position:x",
		position.x + randf_range(-0.7, 0.7), 0.5)
	tween.tween_property(self, "scale", Vector3(1.3, 0.25, 1.3), 0.12)
	tween.tween_callback(queue_free)


func _drop_reward() -> void:
	if drop_kind == "none":
		return
	var reward := RewardPickup3D.new()
	reward.kind = drop_kind
	reward.amount = drop_amount
	get_parent().add_child(reward)
	reward.global_position = global_position
