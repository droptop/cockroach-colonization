@tool
extends Node3D

## Chubby red fly per the designer's reference: round red body, big dark eye
## patches, constantly buzzing translucent wings, dangly little legs.

@export var body_color := Color(0.8, 0.28, 0.24)
@export var eye_color := Color(0.1, 0.06, 0.07)

var _built := false
var _wing_pivots: Array[Node3D] = []


func _ready() -> void:
	if _built:
		return
	_built = true
	var body_mat := Block3D.flat_material(body_color)
	var eye_mat := Block3D.flat_material(eye_color)
	var wing_mat := Block3D.flat_material(Color(0.9, 0.92, 0.98, 0.4))

	var body := _sphere(self, Vector3(0, 0, 0), 0.3, body_mat)
	body.scale = Vector3(1.15, 1.0, 0.95)
	for side in [-1.0, 1.0]:
		var eye := _sphere(self, Vector3(0.2, 0.08, side * 0.13), 0.1, eye_mat)
		eye.scale = Vector3(0.8, 1.1, 0.7)
		var leg := _cylinder(self, Vector3(0.0, -0.3, side * 0.1), 0.012, 0.016, 0.18, eye_mat)
		leg.rotation.x = side * 0.3
		var wing_pivot := Node3D.new()
		wing_pivot.position = Vector3(-0.05, 0.24, side * 0.1)
		add_child(wing_pivot)
		var wing := _sphere(wing_pivot, Vector3(-0.2, 0.05, side * 0.12), 0.22, wing_mat)
		wing.scale = Vector3(1.6, 0.12, 0.7)
		_wing_pivots.append(wing_pivot)


func _process(_delta: float) -> void:
	var buzz := sin(Time.get_ticks_msec() * 0.06)
	for i in _wing_pivots.size():
		var side := -1.0 if i == 0 else 1.0
		_wing_pivots[i].rotation.x = side * buzz * 0.55


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
