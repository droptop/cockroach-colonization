@tool
class_name Pipe3D
extends Node3D

## Decorative drain-pipe mouth: outer ring cylinder pointing at the camera
## with a dark inner disc faking the hole. No collision.

@export var radius := 2.2:
	set(value):
		radius = value
		_refresh()
@export var length := 3.0:
	set(value):
		length = value
		_refresh()
@export var pipe_color := Color(0.3, 0.38, 0.36):
	set(value):
		pipe_color = value
		_refresh()

var _ring: MeshInstance3D
var _hole: MeshInstance3D


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	if _ring == null:
		_ring = MeshInstance3D.new()
		_ring.mesh = CylinderMesh.new()
		add_child(_ring)
		_hole = MeshInstance3D.new()
		_hole.mesh = CylinderMesh.new()
		add_child(_hole)
	for entry in [[_ring, radius, length, pipe_color], [_hole, radius * 0.82, length + 0.15, Color(0.02, 0.03, 0.03)]]:
		var inst: MeshInstance3D = entry[0]
		var mesh := inst.mesh as CylinderMesh
		mesh.top_radius = entry[1]
		mesh.bottom_radius = entry[1]
		mesh.height = entry[2]
		mesh.radial_segments = 16
		mesh.material = Block3D.flat_material(entry[3])
		inst.rotation.x = PI / 2.0 # axis along Z, mouth facing the camera
