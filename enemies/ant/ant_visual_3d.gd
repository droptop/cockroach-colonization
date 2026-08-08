@tool
extends Node3D

## Little red ant, matching the designer's red-enemy reference art:
## round head with dark eyes, two body segments, six scurrying legs,
## angry little antennae. Built facing +X.

@export var body_color := Color(0.78, 0.3, 0.26)
@export var eye_color := Color(0.08, 0.05, 0.06)

var _built := false
var _body_ref: CharacterBody3D
var _leg_pivots: Array[Node3D] = []
var _time := 0.0


func _ready() -> void:
	_body_ref = get_parent() as CharacterBody3D
	if _built:
		return
	_built = true
	var body_mat := Block3D.flat_material(body_color)
	var dark_mat := Block3D.flat_material(body_color.darkened(0.25))
	var eye_mat := Block3D.flat_material(eye_color)

	var head := _sphere(self, Vector3(0.16, 0.24, 0), 0.15, body_mat)
	head.scale = Vector3(1.0, 1.05, 0.95)
	_sphere(self, Vector3(-0.14, 0.22, 0), 0.13, dark_mat)
	for side in [-1.0, 1.0]:
		_sphere(self, Vector3(0.26, 0.28, side * 0.07), 0.045, eye_mat)
		var antenna := _cylinder(self, Vector3(0.22, 0.42, side * 0.05), 0.008, 0.012, 0.22, dark_mat)
		antenna.rotation.z = -0.9
		antenna.rotation.x = side * 0.4
	for i in 3:
		for side in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(-0.14 + i * 0.13, 0.1, side * 0.09)
			pivot.rotation.x = side * 0.45
			add_child(pivot)
			_cylinder(pivot, Vector3(0, -0.07, 0), 0.015, 0.02, 0.14, dark_mat)
			_leg_pivots.append(pivot)


func _process(delta: float) -> void:
	var speed := 0.0
	if _body_ref:
		speed = clampf(absf(_body_ref.velocity.x) / 3.9, 0.0, 1.2)
	_time += delta * lerpf(4.0, 22.0, minf(speed, 1.0))
	var amplitude := lerpf(0.08, 0.6, minf(speed, 1.0))
	for i in _leg_pivots.size():
		_leg_pivots[i].rotation.z = sin(_time + PI * (i % 2) + i * 0.3) * amplitude


func _sphere(parent: Node3D, pos: Vector3, radius: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.material = mat
	inst.mesh = mesh
	inst.position = pos
	parent.add_child(inst)
	return inst


func _cylinder(parent: Node3D, pos: Vector3, top_r: float, bottom_r: float, height: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = height
	mesh.radial_segments = 6
	mesh.material = mat
	inst.mesh = mesh
	inst.position = pos
	parent.add_child(inst)
	return inst
