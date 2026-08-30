extends CharacterBody3D

## MARS FAUNA: the gasbag. A translucent dome that floats on nothing at all,
## tentacles trailing, drifting patiently toward anything warm. It cannot be
## outrun so much as out-thought: it is slow, it pops to one bite, and its
## only weapon is being where you wanted to stand.
##
## Airborne like the fly but nothing like it to look at or fight: no dives,
## no spit - a drifting mine with feelings.

enum State { DRIFT, SEEK, DEAD }

@export var drift_speed := 0.7
@export var seek_speed := 1.6
@export var bob_height := 0.5
@export var lose_sight_distance := 8.0
@export var contact_damage := 1
@export var max_health := 1

var state := State.DRIFT
var _stagger_timer := 0.0
var health := 1
var _time := 0.0
var _home := Vector3.ZERO
var _target: Node3D

@onready var _visual: Node3D = $Visual
@onready var _hitbox: Area3D = $Hitbox

var _hp_bar: EnemyHealthBar


func _ready() -> void:
	health = max_health
	_home = global_position
	_time = randf() * TAU
	_hp_bar = EnemyHealthBar.new()
	_hp_bar.position = Vector3(0, 1.0, 0)
	_hp_bar.scale = Vector3.ONE * 0.7
	add_child(_hp_bar)
	_build_visual()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_time += delta
	if _stagger_timer > 0.0:
		_stagger_timer -= delta
		velocity = velocity.move_toward(Vector3.ZERO, 8.0 * delta)
		move_and_slide()
		return
	var bob := sin(_time * 1.7) * bob_height
	match state:
		State.DRIFT:
			var toward := _home + Vector3(sin(_time * 0.5) * 1.8, bob, 0.0)
			velocity = (toward - global_position) * drift_speed
		State.SEEK:
			if not is_instance_valid(_target) \
					or global_position.distance_to(_target.global_position) > lose_sight_distance:
				_target = null
				state = State.DRIFT
			else:
				var at := _target.global_position + Vector3(0, 0.6 + bob, 0)
				velocity = (at - global_position).normalized() * seek_speed
	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0
	# The tentacles sway against the motion.
	_visual.rotation.z = clampf(-velocity.x * 0.12, -0.25, 0.25)
	for body in _hitbox.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(contact_damage, global_position, "a gasbag's sting")
			Encounter.bump(self, body.global_position,
				body.fullness if "fullness" in body else 0.0)


func take_damage(amount: int, from_position: Vector3, _cause := "") -> void:
	if state == State.DEAD:
		return
	health -= amount
	_hp_bar.set_ratio(float(health) / max_health)
	Fx.hit_flash(_visual)
	velocity += Vector3(signf(global_position.x - from_position.x) * 2.0, 1.0, 0.0)
	if health <= 0:
		_die()


func _die() -> void:
	state = State.DEAD
	set_physics_process(false)
	($CollisionShape3D as CollisionShape3D).set_deferred("disabled", true)
	_hitbox.set_deferred("monitoring", false)
	$DetectionArea.set_deferred("monitoring", false)
	# A POP, not a fall: it was mostly nothing to begin with.
	Fx.spark_burst(get_parent(), global_position, Color(0.6, 0.95, 0.8))
	Fx.ghost(get_parent(), global_position, 0.7, 6)
	Snd.sfx("splat", -4.0, 0.2)
	FoodBurst.spawn(get_parent(), global_position, 2, 0, 1)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.5, 0.1)
	tween.tween_property(self, "scale", Vector3.ONE * 0.02, 0.12)
	tween.tween_callback(queue_free)


func _on_detection_area_body_entered(body: Node3D) -> void:
	if state != State.DEAD and body.is_in_group("player"):
		_target = body
		state = State.SEEK


func stagger(duration: float) -> void:
	if state == State.DEAD:
		return
	_stagger_timer = maxf(_stagger_timer, duration)
	Fx.hit_flash(_visual, Color(0.75, 1.0, 0.9), 0.18)


## A see-through dome with a glowing core and three trailing tentacles.
func _build_visual() -> void:
	var dome := MeshInstance3D.new()
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 0.42
	dome_mesh.height = 0.7
	dome_mesh.radial_segments = 10
	dome_mesh.rings = 5
	var skin := Block3D.flat_material(Color(0.55, 0.9, 0.75, 0.4))
	skin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	skin.emission_enabled = true
	skin.emission = Color(0.4, 0.85, 0.65)
	skin.emission_energy_multiplier = 0.5
	dome_mesh.material = skin
	dome.mesh = dome_mesh
	dome.position.y = 0.4
	_visual.add_child(dome)
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.15
	core_mesh.height = 0.3
	core_mesh.radial_segments = 6
	core_mesh.rings = 4
	var glow := Block3D.flat_material(Color(0.95, 0.6, 0.85))
	glow.emission_enabled = true
	glow.emission = Color(0.9, 0.5, 0.8)
	glow.emission_energy_multiplier = 1.6
	core_mesh.material = glow
	core.mesh = core_mesh
	core.position.y = 0.38
	_visual.add_child(core)
	for i in 3:
		var tentacle := MeshInstance3D.new()
		var t_mesh := CylinderMesh.new()
		t_mesh.top_radius = 0.035
		t_mesh.bottom_radius = 0.015
		t_mesh.height = 0.55
		t_mesh.radial_segments = 5
		t_mesh.material = Block3D.flat_material(Color(0.45, 0.75, 0.6))
		tentacle.mesh = t_mesh
		tentacle.position = Vector3(
			cos(TAU * i / 3.0) * 0.2, -0.12, sin(TAU * i / 3.0) * 0.14)
		tentacle.rotation.z = cos(TAU * i / 3.0) * 0.2
		_visual.add_child(tentacle)
