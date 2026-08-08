@tool
class_name Block3D
extends StaticBody3D

## Chunky low-poly platform block: base box + slightly oversized top slab
## (the "lip" that gives the toy-diorama look from the art reference).
## Meshes and collision are built in code so levels stay tiny.

@export var size := Vector3(4.0, 2.0, 3.0):
	set(value):
		size = value
		_refresh()
@export var top_color := Color(0.45, 0.62, 0.4):
	set(value):
		top_color = value
		_refresh()
@export var base_color := Color(0.42, 0.34, 0.28):
	set(value):
		base_color = value
		_refresh()
@export var top_thickness := 0.4:
	set(value):
		top_thickness = value
		_refresh()

var _base: MeshInstance3D
var _top: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	_refresh()


static func flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat


func _refresh() -> void:
	if not is_inside_tree():
		return
	if _base == null:
		_base = MeshInstance3D.new()
		_base.mesh = BoxMesh.new()
		add_child(_base)
		_top = MeshInstance3D.new()
		_top.mesh = BoxMesh.new()
		add_child(_top)
		_shape = CollisionShape3D.new()
		_shape.shape = BoxShape3D.new()
		add_child(_shape)
	var t := minf(top_thickness, size.y * 0.5)
	(_base.mesh as BoxMesh).size = Vector3(size.x, size.y - t, size.z)
	_base.position = Vector3(0, -t / 2.0, 0)
	(_base.mesh as BoxMesh).material = flat_material(base_color)
	(_top.mesh as BoxMesh).size = Vector3(size.x + 0.12, t, size.z + 0.12)
	_top.position = Vector3(0, (size.y - t) / 2.0, 0)
	(_top.mesh as BoxMesh).material = flat_material(top_color)
	(_shape.shape as BoxShape3D).size = size
