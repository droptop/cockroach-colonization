extends CharacterBody3D

## MARS FAUNA: the dust hopper. Nothing from the house made it out here
## (user's call: no recycled enemies on Mars) - this is a spindly two-legged
## thing with one glowing eye that crosses the basin in huge slow arcs,
## because in a third of a gravity, why would anything walk?
##
## Same duck-typed contract as every enemy: take_damage, stagger, contact
## damage through a Hitbox area, one bite kills it.

enum State { IDLE, CHASE, DEAD }

@export var hop_speed_x := 3.2
@export var hop_speed_y := 6.5
## The wind-up crouch between hops; its whole rhythm, and the punish window.
@export var hop_pause := 0.9
@export var lose_sight_distance := 9.0
@export var contact_damage := 1
@export var max_health := 1
## Mars pull, matching the level's player gravity.
@export var gravity := 12.0

var state := State.IDLE
var _stagger_timer := 0.0
var health := 1
var _pause_left := 0.4
var _target: Node3D

@onready var _visual: Node3D = $Visual
@onready var _hitbox: Area3D = $Hitbox

var _hp_bar: EnemyHealthBar


func _ready() -> void:
	health = max_health
	_hp_bar = EnemyHealthBar.new()
	_hp_bar.position = Vector3(0, 1.3, 0)
	_hp_bar.scale = Vector3.ONE * 0.7
	add_child(_hp_bar)
	_build_visual()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _stagger_timer > 0.0:
		_stagger_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		if not is_on_floor():
			velocity.y = maxf(velocity.y - gravity * delta, -12.0)
		move_and_slide()
		return
	if not is_on_floor():
		velocity.y = maxf(velocity.y - gravity * delta, -12.0)
		# Mid-arc: legs trail, nothing to decide.
		_visual.rotation.z = clampf(-velocity.y * 0.03 * signf(velocity.x), -0.3, 0.3)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 26.0 * delta)
		_visual.rotation.z = 0.0
		_pause_left -= delta
		# The crouch reads as the tell.
		_visual.scale.y = 1.0 - clampf((hop_pause - _pause_left) / hop_pause, 0.0, 1.0) * 0.25
		if _pause_left <= 0.0:
			_hop()
	move_and_slide()
	if absf(velocity.x) > 0.05:
		_visual.scale.x = signf(velocity.x)
	for body in _hitbox.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(contact_damage, global_position, "a dust hopper")
			Encounter.bump(self, body.global_position,
				body.fullness if "fullness" in body else 0.0)


func _hop() -> void:
	_pause_left = hop_pause
	_visual.scale.y = 1.0
	var dir := [-1.0, 1.0][randi() % 2] * 0.5 # idle: small aimless bounds
	if state == State.CHASE:
		if not is_instance_valid(_target) \
				or global_position.distance_to(_target.global_position) > lose_sight_distance:
			_target = null
			state = State.IDLE
		else:
			dir = signf(_target.global_position.x - global_position.x)
	velocity = Vector3(dir * hop_speed_x, hop_speed_y, 0.0)
	Snd.sfx("whoosh", -14.0, 0.3)


func take_damage(amount: int, from_position: Vector3, _cause := "") -> void:
	if state == State.DEAD:
		return
	health -= amount
	_hp_bar.set_ratio(float(health) / max_health)
	Fx.hit_flash(_visual)
	velocity.x += signf(global_position.x - from_position.x) * 2.5
	velocity.y += 1.6
	if health <= 0:
		_die()


func _die() -> void:
	state = State.DEAD
	set_physics_process(false)
	($CollisionShape3D as CollisionShape3D).set_deferred("disabled", true)
	_hitbox.set_deferred("monitoring", false)
	$DetectionArea.set_deferred("monitoring", false)
	Fx.ghost(get_parent(), global_position, 0.6, 6)
	Fx.shatter(get_parent(), _visual, 5.0)
	Snd.sfx("enemy_die", -6.0)
	FoodBurst.spawn(get_parent(), global_position, 2, 0, 1)
	# It folds up: legs first, like a deck chair.
	var tween := create_tween()
	tween.tween_property(_visual, "rotation:z", PI * 0.6, 0.3)
	tween.tween_property(self, "scale", Vector3(1.3, 0.12, 1.2), 0.18)
	tween.tween_callback(queue_free)


func _on_detection_area_body_entered(body: Node3D) -> void:
	if state != State.DEAD and body.is_in_group("player"):
		_target = body
		state = State.CHASE


func stagger(duration: float) -> void:
	if state == State.DEAD:
		return
	_stagger_timer = maxf(_stagger_timer, duration)
	Fx.hit_flash(_visual, Color(0.75, 1.0, 0.9), 0.18)


## Rust teardrop on two stilts, one eye on a stalk. Unmistakably not an ant.
func _build_visual() -> void:
	var hide := Block3D.flat_material(Color(0.72, 0.4, 0.25))
	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.3
	body_mesh.height = 0.75
	body_mesh.radial_segments = 8
	body_mesh.rings = 5
	body_mesh.material = hide
	body.mesh = body_mesh
	body.position.y = 0.75
	_visual.add_child(body)
	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var leg_mesh := CylinderMesh.new()
		leg_mesh.top_radius = 0.045
		leg_mesh.bottom_radius = 0.03
		leg_mesh.height = 0.62
		leg_mesh.radial_segments = 5
		leg_mesh.material = Block3D.flat_material(Color(0.5, 0.28, 0.18))
		leg.mesh = leg_mesh
		leg.position = Vector3(side * 0.09, 0.3, side * 0.1)
		leg.rotation.z = side * 0.16
		_visual.add_child(leg)
	var stalk := MeshInstance3D.new()
	var stalk_mesh := CylinderMesh.new()
	stalk_mesh.top_radius = 0.03
	stalk_mesh.bottom_radius = 0.045
	stalk_mesh.height = 0.34
	stalk_mesh.radial_segments = 5
	stalk_mesh.material = hide
	stalk.mesh = stalk_mesh
	stalk.position = Vector3(0.08, 1.25, 0)
	_visual.add_child(stalk)
	var eye := MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.11
	eye_mesh.height = 0.22
	eye_mesh.radial_segments = 6
	eye_mesh.rings = 4
	var eye_mat := Block3D.flat_material(Color(0.5, 1.0, 0.8))
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.4, 1.0, 0.7)
	eye_mat.emission_energy_multiplier = 1.5
	eye_mesh.material = eye_mat
	eye.mesh = eye_mesh
	eye.position = Vector3(0.1, 1.46, 0)
	_visual.add_child(eye)
