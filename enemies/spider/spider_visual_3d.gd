@tool
extends Node3D

## Placeholder low-poly spider: two body spheres, eight animated legs, red eyes.
## Legs scurry with movement speed; the body bobs menacingly while walking.
## Built facing +X.

@export var body_color := Color(0.17, 0.11, 0.2)
@export var leg_color := Color(0.26, 0.18, 0.28)
@export var eye_color := Color(0.85, 0.12, 0.08)

var _built := false
var _body_ref: CharacterBody3D
var _leg_pivots: Array[Node3D] = []
var _leg_base_z: Array[float] = []
var _abdomen: MeshInstance3D
var _time := 0.0


func _ready() -> void:
	_body_ref = get_parent() as CharacterBody3D
	if _built:
		return
	_built = true
	var body_mat := Block3D.flat_material(body_color)
	var leg_mat := Block3D.flat_material(leg_color)
	var eye_mat := Block3D.flat_material(eye_color)
	eye_mat.emission_enabled = true
	eye_mat.emission = eye_color
	eye_mat.emission_energy_multiplier = 1.4

	_abdomen = _add_mesh(SphereMesh.new(), Vector3(-0.18, 0.34, 0), body_mat)
	(_abdomen.mesh as SphereMesh).radius = 0.34
	(_abdomen.mesh as SphereMesh).height = 0.68
	var head := _add_mesh(SphereMesh.new(), Vector3(0.24, 0.26, 0), body_mat)
	(head.mesh as SphereMesh).radius = 0.2
	(head.mesh as SphereMesh).height = 0.4
	for z in [-0.07, 0.07]:
		var eye := _add_mesh(SphereMesh.new(), Vector3(0.4, 0.3, z), eye_mat)
		(eye.mesh as SphereMesh).radius = 0.045
		(eye.mesh as SphereMesh).height = 0.09
	# Eight legs on hip pivots, four per side, splayed and ready to scuttle.
	for i in 4:
		for side in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(-0.25 + i * 0.16, 0.3, side * 0.18)
			pivot.rotation.x = side * 0.85
			pivot.rotation.z = 0.35 - i * 0.22
			add_child(pivot)
			var leg := _add_mesh(CylinderMesh.new(), Vector3(0, -0.22, 0), leg_mat)
			var mesh := leg.mesh as CylinderMesh
			mesh.top_radius = 0.02
			mesh.bottom_radius = 0.03
			mesh.height = 0.5
			mesh.radial_segments = 6
			_leg_pivots.append(pivot)
			_leg_base_z.append(pivot.rotation.z)


func _process(delta: float) -> void:
	var speed := 0.0
	if _body_ref:
		speed = clampf(absf(_body_ref.velocity.x) / 3.0, 0.0, 1.3)
	_time += delta * lerpf(3.0, 18.0, minf(speed, 1.0))
	var amplitude := lerpf(0.05, 0.45, minf(speed, 1.0))
	for i in _leg_pivots.size():
		# Opposite phases across pairs so the gait alternates.
		var phase := PI * ((i / 2 + i) % 2) + float(i) * 0.4
		_leg_pivots[i].rotation.z = _leg_base_z[i] + sin(_time + phase) * amplitude
	if _abdomen:
		_abdomen.position.y = 0.34 + sin(_time * 2.0) * 0.02 * (0.5 + speed)


func _add_mesh(mesh: Mesh, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = mat
	add_child(inst)
	return inst
