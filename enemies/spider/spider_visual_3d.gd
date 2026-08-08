@tool
extends Node3D

## Placeholder low-poly spider: two body spheres, eight legs, red eyes.
## Built facing +X.

@export var body_color := Color(0.17, 0.11, 0.2)
@export var leg_color := Color(0.26, 0.18, 0.28)
@export var eye_color := Color(0.85, 0.12, 0.08)

var _built := false


func _ready() -> void:
	if _built:
		return
	_built = true
	var body_mat := Block3D.flat_material(body_color)
	var leg_mat := Block3D.flat_material(leg_color)
	var eye_mat := Block3D.flat_material(eye_color)
	eye_mat.emission_enabled = true
	eye_mat.emission = eye_color
	eye_mat.emission_energy_multiplier = 1.4

	var abdomen := _add_mesh(SphereMesh.new(), Vector3(-0.18, 0.34, 0), body_mat)
	(abdomen.mesh as SphereMesh).radius = 0.34
	(abdomen.mesh as SphereMesh).height = 0.68
	var head := _add_mesh(SphereMesh.new(), Vector3(0.24, 0.26, 0), body_mat)
	(head.mesh as SphereMesh).radius = 0.2
	(head.mesh as SphereMesh).height = 0.4
	for z in [-0.07, 0.07]:
		var eye := _add_mesh(SphereMesh.new(), Vector3(0.4, 0.3, z), eye_mat)
		(eye.mesh as SphereMesh).radius = 0.045
		(eye.mesh as SphereMesh).height = 0.09
	# Eight legs, four per side, splayed.
	for i in 4:
		for side in [-1.0, 1.0]:
			var leg := _add_mesh(CylinderMesh.new(), Vector3(-0.25 + i * 0.16, 0.22, side * 0.3), leg_mat)
			var mesh := leg.mesh as CylinderMesh
			mesh.top_radius = 0.02
			mesh.bottom_radius = 0.03
			mesh.height = 0.5
			mesh.radial_segments = 6
			leg.rotation.x = side * 0.85
			leg.rotation.z = 0.35 - i * 0.22


func _add_mesh(mesh: Mesh, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = mat
	add_child(inst)
	return inst
