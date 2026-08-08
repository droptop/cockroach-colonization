class_name DripEmitter3D
extends Node3D

## Hazard: toxic goo drips from a leaky pipe. Each drop hangs and swells (the
## dodge telegraph), falls, and splats. Where it lands it leaves a BURNING
## puddle that smokes and hurts anything standing in it.

@export var interval := 2.4
@export var interval_jitter := 1.0
@export var hang_time := 0.55
@export var drop_color := Color(0.5, 0.95, 0.4)
@export var damage := 1
@export var gravity := 22.0
@export var kill_y := -8.0
@export var puddle_lifetime := 5.0
@export var show_pipe := true

var _timer := 0.0
var _drops: Array[Dictionary] = []
var _puddles: Array[Dictionary] = []


func _ready() -> void:
	_timer = randf() * interval
	if show_pipe:
		_build_pipe()


func _build_pipe() -> void:
	var pipe := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.3
	mesh.bottom_radius = 0.34
	mesh.height = 0.7
	mesh.radial_segments = 10
	mesh.material = Block3D.textured_material(Color(0.3, 0.34, 0.32), "speckle", 1.2)
	pipe.mesh = mesh
	pipe.position = Vector3(0, 0.45, 0)
	add_child(pipe)
	var hole := MeshInstance3D.new()
	var hole_mesh := CylinderMesh.new()
	hole_mesh.top_radius = 0.24
	hole_mesh.bottom_radius = 0.24
	hole_mesh.height = 0.06
	hole_mesh.material = Block3D.flat_material(Color(0.03, 0.05, 0.04))
	hole.mesh = hole_mesh
	hole.position = Vector3(0, 0.12, 0)
	add_child(hole)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = interval + randf_range(0.0, interval_jitter)
		_spawn_drop()
	_update_drops(delta)
	_update_puddles(delta)


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
				body.take_damage(damage, area.global_position)
				done = true
			else:
				hit_world = true
		if hit_world:
			_spawn_puddle(area.global_position)
			done = true
		if done or area.global_position.y < kill_y:
			area.queue_free()
			_drops.remove_at(i)


func _update_puddles(delta: float) -> void:
	for i in range(_puddles.size() - 1, -1, -1):
		var puddle: Dictionary = _puddles[i]
		var area: Area3D = puddle.area
		if not is_instance_valid(area):
			_puddles.remove_at(i)
			continue
		puddle.life -= delta
		puddle.tick -= delta
		if puddle.tick <= 0.0:
			puddle.tick = 0.35
			for body in area.get_overlapping_bodies():
				if body.has_method("take_damage"):
					body.take_damage(damage, area.global_position)
		if puddle.life <= 0.0:
			var smoke: CPUParticles3D = puddle.smoke
			if is_instance_valid(smoke):
				smoke.emitting = false
			var tween := area.create_tween()
			tween.tween_property(area, "scale", Vector3(0.05, 0.02, 0.05), 0.4)
			tween.tween_callback(area.queue_free)
			_puddles.remove_at(i)


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
	var mesh_inst := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.46
	var mat := Block3D.flat_material(drop_color)
	mat.emission_enabled = true
	mat.emission = drop_color
	mat.emission_energy_multiplier = 1.3
	mesh.material = mat
	mesh_inst.mesh = mesh
	area.add_child(mesh_inst)
	add_child(area)
	area.global_position = global_position
	area.scale = Vector3.ONE * 0.4
	_drops.append({"area": area, "vy": 0.0, "hang": hang_time})


func _spawn_puddle(pos: Vector3) -> void:
	Snd.sfx("sizzle", -6.0)
	var area := Area3D.new()
	area.collision_layer = 8
	area.collision_mask = 2
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 0.5, 1.0)
	shape.shape = box
	shape.position = Vector3(0, 0.2, 0)
	area.add_child(shape)
	# Glowing molten disc.
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 0.55
	disc_mesh.bottom_radius = 0.62
	disc_mesh.height = 0.09
	disc_mesh.radial_segments = 12
	var mat := Block3D.flat_material(drop_color)
	mat.emission_enabled = true
	mat.emission = drop_color
	mat.emission_energy_multiplier = 1.8
	disc_mesh.material = mat
	disc.mesh = disc_mesh
	area.add_child(disc)
	# Rising acrid smoke.
	var smoke := CPUParticles3D.new()
	smoke.amount = 10
	smoke.lifetime = 1.3
	smoke.mesh = _smoke_mesh()
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.1
	smoke.gravity = Vector3(0, 0.4, 0)
	smoke.scale_amount_min = 0.5
	smoke.scale_amount_max = 1.2
	smoke.position = Vector3(0, 0.15, 0)
	area.add_child(smoke)
	add_child(area)
	area.global_position = pos + Vector3(0, 0.05, 0)
	area.scale = Vector3(0.3, 1, 0.3)
	var tween := area.create_tween()
	tween.tween_property(area, "scale", Vector3.ONE, 0.2)
	_puddles.append({"area": area, "smoke": smoke, "life": puddle_lifetime, "tick": 0.0})


func _smoke_mesh() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.09
	mesh.height = 0.18
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := Block3D.flat_material(Color(drop_color.r * 0.5 + 0.25, drop_color.g * 0.5 + 0.25, drop_color.b * 0.5 + 0.25, 0.4))
	mesh.material = mat
	return mesh
