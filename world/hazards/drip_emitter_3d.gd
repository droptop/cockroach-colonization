class_name DripEmitter3D
extends Node3D

## Hazard: toxic goo drips from a leaky pipe. Each drop hangs and swells (the
## dodge telegraph), falls, and splats. Where it lands it leaves a BURNING
## puddle that smokes and hurts anything standing in it.

@export var interval := 2.4
@export var interval_jitter := 1.0
## How long a drop swells at the pipe mouth before it lets go. This IS the
## warning: it was half a second, which is not enough to read and move.
@export var hang_time := 1.15
@export var drop_color := Color(0.5, 0.95, 0.4)
@export var damage := 1
@export var gravity := 22.0
@export var kill_y := -8.0
@export var puddle_lifetime := 5.0
@export var show_pipe := true

var _timer := 0.0
var _drops: Array[Dictionary] = []
var _pools: Array[HazardPool3D] = []


func _ready() -> void:
	_timer = randf() * interval
	if show_pipe:
		_build_pipe()


func _build_pipe() -> void:
	# Turned to face the camera so you see the BORE as an O, with the drop
	# swelling in the mouth of it. End-on it was just a grey stub.
	var body := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.34
	mesh.bottom_radius = 0.34
	mesh.height = 0.8
	mesh.radial_segments = 12
	mesh.material = Block3D.textured_material(Color(0.3, 0.34, 0.32), "speckle", 1.2)
	body.mesh = mesh
	body.rotation.x = PI / 2.0
	body.position = Vector3(0, 0.18, -0.3)
	add_child(body)

	# Rim around the opening.
	var rim := MeshInstance3D.new()
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.3
	rim_mesh.outer_radius = 0.4
	rim_mesh.rings = 14
	rim_mesh.ring_segments = 6
	rim_mesh.material = Block3D.flat_material(Color(0.36, 0.4, 0.38))
	rim.mesh = rim_mesh
	rim.position = Vector3(0, 0.18, 0.12)
	add_child(rim)

	# The dark bore you can see into.
	var bore := MeshInstance3D.new()
	var bore_mesh := CylinderMesh.new()
	bore_mesh.top_radius = 0.3
	bore_mesh.bottom_radius = 0.3
	bore_mesh.height = 0.05
	bore_mesh.radial_segments = 12
	bore_mesh.material = Block3D.flat_material(Color(0.03, 0.05, 0.04))
	bore.mesh = bore_mesh
	bore.rotation.x = PI / 2.0
	bore.position = Vector3(0, 0.18, 0.09)
	add_child(bore)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = interval + randf_range(0.0, interval_jitter)
		_spawn_drop()
	_update_drops(delta)


func _update_drops(delta: float) -> void:
	for i in range(_drops.size() - 1, -1, -1):
		var drop: Dictionary = _drops[i]
		var area: Area3D = drop.area
		if not is_instance_valid(area):
			_drops.remove_at(i)
			continue
		if drop.hang > 0.0:
			drop.hang -= delta
			var t: float = 1.0 - drop.hang / hang_time
			area.scale = Vector3.ONE * (0.4 + 0.6 * t)
			continue
		drop.vy -= gravity * delta
		area.global_position.y += drop.vy * delta
		var hit_world := false
		var done := false
		for body in area.get_overlapping_bodies():
			if body.has_method("take_damage"):
				body.take_damage(damage, area.global_position, "acid")
				done = true
			else:
				hit_world = true
		if hit_world:
			_spawn_puddle(area.global_position)
			done = true
		if done or area.global_position.y < kill_y:
			area.queue_free()
			_drops.remove_at(i)


func _spawn_drop() -> void:
	var area := Area3D.new()
	area.collision_layer = 8
	area.collision_mask = 1 | 2
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.2
	shape.shape = sphere
	area.add_child(shape)
	var mat := Block3D.flat_material(drop_color)
	mat.emission_enabled = true
	mat.emission = drop_color
	mat.emission_energy_multiplier = 1.3
	# A teardrop: round belly, drawn to a point on top, which is the shape a
	# hanging drop actually makes. A plain sphere read as a pea.
	var belly := MeshInstance3D.new()
	var belly_mesh := SphereMesh.new()
	belly_mesh.radius = 0.18
	belly_mesh.height = 0.32
	belly_mesh.radial_segments = 10
	belly_mesh.rings = 6
	belly_mesh.material = mat
	belly.mesh = belly_mesh
	belly.position = Vector3(0, -0.06, 0)
	area.add_child(belly)
	var tip := MeshInstance3D.new()
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.0
	tip_mesh.bottom_radius = 0.16
	tip_mesh.height = 0.26
	tip_mesh.radial_segments = 10
	tip_mesh.material = mat
	tip.mesh = tip_mesh
	tip.position = Vector3(0, 0.14, 0)
	area.add_child(tip)
	add_child(area)
	area.global_position = global_position
	area.scale = Vector3.ONE * 0.4
	_drops.append({"area": area, "vy": 0.0, "hang": hang_time})


## Acid landing. If it lands in a pool that is already there, that pool spreads
## instead of a second one stacking on top — which is what makes a slow leak
## build a wide puddle over time rather than a pile of identical discs.
func _spawn_puddle(pos: Vector3) -> void:
	Snd.sfx("sizzle", -6.0)
	for i in range(_pools.size() - 1, -1, -1):
		if not is_instance_valid(_pools[i]):
			_pools.remove_at(i)
			continue
		var existing := _pools[i]
		if absf(existing.global_position.x - pos.x) < existing.radius + 0.25:
			existing.feed()
			return
	var pool := HazardPool3D.new()
	pool.damage = damage
	pool.color = drop_color
	pool.lifetime = puddle_lifetime
	add_child(pool)
	pool.global_position = pos + Vector3(0, 0.02, 0)
	_pools.append(pool)
