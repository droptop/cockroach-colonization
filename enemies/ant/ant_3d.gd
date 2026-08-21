extends CharacterBody3D

## Small swarm enemy: fast, fragile, relentless. Patrols until it spots Harry,
## then scurries straight at him. One bite kills it.

enum State { PATROL, CHASE, DEAD }

@export var patrol_speed := 1.6
@export var patrol_distance := 2.5
## Below the player's 4.5, and meaningfully so. At 3.9 a Harry slowed by
## fullness (growth_run_penalty) could not outrun one, so an ant that noticed
## you stayed on you for the rest of the level.
@export var chase_speed := 2.9
## And it gives up sooner. Seven units meant breaking line of sight took most
## of a screen.
@export var lose_sight_distance := 5.0
@export var contact_damage := 1
@export var max_health := 1
@export var gravity := 26.0

var state := State.PATROL
## Frozen by the antennae pulse while this is above zero.
var _stagger_timer := 0.0
var health := 1

var _origin := Vector3.ZERO
var _patrol_dir := 1
var _target: Node3D

@onready var _visual: Node3D = $Visual
@onready var _hitbox: Area3D = $Hitbox


var _hp_bar: EnemyHealthBar


func _ready() -> void:
	health = max_health
	_origin = global_position
	_hp_bar = EnemyHealthBar.new()
	_hp_bar.position = Vector3(0, 0.85, 0)
	_hp_bar.scale = Vector3.ONE * 0.7
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
	match state:
		State.PATROL:
			velocity.x = _patrol_dir * patrol_speed
			var past := (_patrol_dir > 0 and global_position.x >= _origin.x + patrol_distance) \
				or (_patrol_dir < 0 and global_position.x <= _origin.x - patrol_distance)
			if past or is_on_wall() or not _floor_ahead(float(_patrol_dir)):
				_patrol_dir = -_patrol_dir
		State.CHASE:
			if not is_instance_valid(_target) \
				or global_position.distance_to(_target.global_position) > lose_sight_distance:
				_target = null
				state = State.PATROL
			else:
				var chase_dir := signf(_target.global_position.x - global_position.x)
				velocity.x = chase_dir * chase_speed if _floor_ahead(chase_dir) else 0.0
	move_and_slide()
	if absf(velocity.x) > 0.05:
		_visual.scale.x = signf(velocity.x)
	for body in _hitbox.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(contact_damage, global_position, "ant")


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
	velocity.x += signf(global_position.x - from_position.x) * 2.5
	velocity.y += 1.4 # a visible knock-up, so a hit never looks absorbed
	if health <= 0:
		_die()


func _die() -> void:
	state = State.DEAD
	set_physics_process(false)
	($CollisionShape3D as CollisionShape3D).set_deferred("disabled", true)
	_hitbox.set_deferred("monitoring", false)
	$DetectionArea.set_deferred("monitoring", false)
	Fx.ghost(get_parent(), global_position, 0.6, 6)
	Snd.sfx("splat", -6.0)
	FoodBurst.spawn(get_parent(), global_position, 2)
	# Flipped onto its back and skidding. An ant is light enough to be sent
	# flying, which is a different death from the spider's heavy drop — every
	# enemy used to flatten in place identically.
	var start_y := position.y
	var tween := create_tween()
	tween.tween_property(self, "position:y", start_y + 0.75, 0.16
		).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_visual, "rotation:z", PI, 0.32)
	tween.parallel().tween_property(self, "position:x",
		position.x + randf_range(-0.7, 0.7), 0.34)
	tween.tween_property(self, "position:y", start_y, 0.18).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector3(1.4, 0.1, 1.2), 0.16)
	tween.tween_callback(queue_free)


func _on_detection_area_body_entered(body: Node3D) -> void:
	if state != State.DEAD and body.is_in_group("player"):
		_target = body
		state = State.CHASE


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
