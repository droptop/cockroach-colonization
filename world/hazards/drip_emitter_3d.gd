class_name DripEmitter3D
extends Node3D

## Hazard: toxic goo drips from this point on a loose timer. Each drop hangs
## and swells for a beat (the dodge telegraph), falls, and splats on whatever
## it hits — hurting the player.

@export var interval := 2.4
@export var interval_jitter := 1.0
@export var hang_time := 0.55
@export var drop_color := Color(0.5, 0.95, 0.4)
@export var damage := 1
@export var gravity := 22.0
@export var kill_y := -8.0

var _timer := 0.0
var _drops: Array[Dictionary] = []


func _ready() -> void:
	_timer = randf() * interval


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = interval + randf_range(0.0, interval_jitter)
		_spawn_drop()
	for i in range(_drops.size() - 1, -1, -1):
		var drop: Dictionary = _drops[i]
		var area: Area3D = drop.area
		if not is_instance_valid(area):
			_drops.remove_at(i)
			continue
		if drop.hang > 0.0:
			drop.hang -= delta
			# Swell while hanging — the "get out of the way" cue.
			var t: float = 1.0 - drop.hang / hang_time
			area.scale = Vector3.ONE * (0.4 + 0.6 * t)
			continue
		drop.vy -= gravity * delta
		area.global_position.y += drop.vy * delta
		var hit := false
		for body in area.get_overlapping_bodies():
			if body.has_method("take_damage"):
				body.take_damage(damage, area.global_position)
			hit = true
		if hit or area.global_position.y < kill_y:
			_splat(area)
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
	var mesh_inst := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.46 # teardrop-ish stretch
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


func _splat(area: Area3D) -> void:
	var tween := area.create_tween()
	tween.tween_property(area, "scale", Vector3(1.6, 0.15, 1.6), 0.12)
	tween.parallel().tween_property(area, "position:y", area.position.y - 0.05, 0.12)
	tween.tween_callback(area.queue_free)
