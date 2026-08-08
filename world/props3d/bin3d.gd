@tool
class_name Bin3D
extends StaticBody3D

## Street rubbish bin: body cylinder + oversized lid + knob. Climbable.

@export var radius := 1.1:
	set(value):
		radius = value
		_refresh()
@export var height := 2.6:
	set(value):
		height = value
		_refresh()
@export var body_color := Color(0.3, 0.36, 0.4):
	set(value):
		body_color = value
		_refresh()
@export var lid_color := Color(0.22, 0.26, 0.3):
	set(value):
		lid_color = value
		_refresh()

var _body: MeshInstance3D
var _lid: MeshInstance3D
var _knob: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	if _body == null:
		_body = MeshInstance3D.new()
		_body.mesh = CylinderMesh.new()
		add_child(_body)
		_lid = MeshInstance3D.new()
		_lid.mesh = CylinderMesh.new()
		add_child(_lid)
		_knob = MeshInstance3D.new()
		_knob.mesh = CylinderMesh.new()
		add_child(_knob)
		_shape = CollisionShape3D.new()
		_shape.shape = CylinderShape3D.new()
		add_child(_shape)
	var lid_h := 0.3
	var body_mesh := _body.mesh as CylinderMesh
	body_mesh.top_radius = radius * 0.92
	body_mesh.bottom_radius = radius * 0.8
	body_mesh.height = height - lid_h
	body_mesh.radial_segments = 12
	body_mesh.material = Block3D.flat_material(body_color)
	_body.position = Vector3(0, (height - lid_h) / 2.0 - height / 2.0, 0)
	var lid_mesh := _lid.mesh as CylinderMesh
	lid_mesh.top_radius = radius
	lid_mesh.bottom_radius = radius * 1.04
	lid_mesh.height = lid_h
	lid_mesh.radial_segments = 12
	lid_mesh.material = Block3D.flat_material(lid_color)
	_lid.position = Vector3(0, height / 2.0 - lid_h / 2.0, 0)
	var knob_mesh := _knob.mesh as CylinderMesh
	knob_mesh.top_radius = 0.12
	knob_mesh.bottom_radius = 0.16
	knob_mesh.height = 0.18
	knob_mesh.radial_segments = 8
	knob_mesh.material = Block3D.flat_material(lid_color)
	_knob.position = Vector3(0, height / 2.0 + 0.09, 0)
	var shape := _shape.shape as CylinderShape3D
	shape.radius = radius
	shape.height = height
