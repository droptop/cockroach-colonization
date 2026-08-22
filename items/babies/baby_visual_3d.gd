@tool
extends Node3D

## A BABY, drawn cheaply. Reads as a tiny Harry at a fifth of the draw calls.
##
## Babies used to borrow `roach_visual_3d.gd` — the full player model, scaled to
## 0.4. That is 21 visible meshes each: head, two eyes, two glints, two blush
## spots, three shell segments, a belly, four antenna parts and six legs. At 0.4
## scale a glint is eight millimetres across and costs a draw call.
##
## It matters because banked babies FOLLOW YOU INTO EVERY LEVEL, and they are
## all on screen at once, clustered on the player, exactly where the camera is
## looking. Eight of them added 184 draw calls and took the tabletop from
## 6.19 draws/m to 11.94 against a ceiling of 6.5. The game got heavier the
## better you played, which is what "feels glitchy now" was.
##
## So: one shell, one head, and three MultiMeshes. Five draw calls. The legs
## still scurry, because a baby that does not is a pebble.

@export var shell_color := Color(0.85, 0.75, 0.65)
@export var body_color := Color(0.96, 0.93, 0.88)

const LEGS := 6
const LEG_ROWS := 3

var _legs: MultiMesh
var _time := 0.0
var _built := false


func _ready() -> void:
	if _built:
		return
	_built = true
	var shell_mat := Block3D.flat_material(shell_color)
	var body_mat := Block3D.flat_material(body_color)

	# One body instead of three shell segments plus a belly. At this size the
	# segmentation was never legible anyway.
	var shell := MeshInstance3D.new()
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.26
	shell_mesh.height = 0.52
	shell_mesh.radial_segments = 8
	shell_mesh.rings = 5
	shell_mesh.material = shell_mat
	shell.mesh = shell_mesh
	shell.position = Vector3(-0.08, 0.27, 0)
	shell.scale = Vector3(1.35, 0.8, 1.0)
	add_child(shell)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.2
	head_mesh.height = 0.4
	head_mesh.radial_segments = 8
	head_mesh.rings = 5
	head_mesh.material = body_mat
	head.mesh = head_mesh
	head.position = Vector3(0.24, 0.26, 0)
	add_child(head)

	# Eyes: the one piece of face that survives being shrunk. Glints and blush
	# do not, so they are gone.
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.07
	eye_mesh.height = 0.14
	eye_mesh.radial_segments = 6
	eye_mesh.rings = 4
	eye_mesh.material = Block3D.flat_material(Color(0.05, 0.05, 0.06))
	var eyes := MultiMesh.new()
	eyes.transform_format = MultiMesh.TRANSFORM_3D
	eyes.mesh = eye_mesh
	eyes.instance_count = 2
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		eyes.set_instance_transform(i, Transform3D(Basis(),
			Vector3(0.37, 0.3, side * 0.11)))
	var eye_node := MultiMeshInstance3D.new()
	eye_node.multimesh = eyes
	add_child(eye_node)

	var antenna_mesh := CylinderMesh.new()
	antenna_mesh.top_radius = 0.012
	antenna_mesh.bottom_radius = 0.018
	antenna_mesh.height = 0.34
	antenna_mesh.radial_segments = 4
	antenna_mesh.material = body_mat
	var antennae := MultiMesh.new()
	antennae.transform_format = MultiMesh.TRANSFORM_3D
	antennae.mesh = antenna_mesh
	antennae.instance_count = 2
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		antennae.set_instance_transform(i, Transform3D(
			Basis.from_euler(Vector3(side * 0.35, 0, -0.7)),
			Vector3(0.34, 0.46, side * 0.07)))
	var antenna_node := MultiMeshInstance3D.new()
	antenna_node.multimesh = antennae
	add_child(antenna_node)

	var leg_mesh := CylinderMesh.new()
	leg_mesh.top_radius = 0.025
	leg_mesh.bottom_radius = 0.035
	leg_mesh.height = 0.18
	leg_mesh.radial_segments = 4
	leg_mesh.material = body_mat
	_legs = MultiMesh.new()
	_legs.transform_format = MultiMesh.TRANSFORM_3D
	_legs.mesh = leg_mesh
	_legs.instance_count = LEGS
	var leg_node := MultiMeshInstance3D.new()
	leg_node.multimesh = _legs
	add_child(leg_node)
	_pose_legs(0.0)


## Six legs in one MultiMesh, re-posed each frame. Writing six transforms is
## cheaper than six nodes to draw, and it keeps the scurry.
func _pose_legs(phase: float) -> void:
	if _legs == null:
		return
	var n := 0
	for row in LEG_ROWS:
		for i in 2:
			var side := -1.0 if i == 0 else 1.0
			# Alternate tripod, the way a real roach walks.
			# Shallow. A big swing splays them out sideways into a row of Vs
			# rather than reading as a scurry.
			var swing := sin(phase + float(row) * 2.1 + (0.0 if side < 0.0 else PI)) * 0.28
			_legs.set_instance_transform(n, Transform3D(
				Basis.from_euler(Vector3(side * 0.3, 0.0, swing)),
				Vector3(-0.24 + row * 0.19, 0.02, side * 0.12)))
			n += 1


func _process(delta: float) -> void:
	_time += delta * 9.0
	_pose_legs(_time)
