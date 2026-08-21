@tool
extends Node3D

## Low-poly spider: faceted body, eight knee-jointed legs tapering to points.
## Legs scurry with movement speed; the body bobs menacingly while walking.
## Built facing +X.

@export var body_color := Color(0.11, 0.1, 0.12)
@export var leg_color := Color(0.16, 0.15, 0.17)
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

	# Faceted, not smooth: low segment counts are what give the reference its
	# cut-gem look, and they cost fewer tris than the round version did.
	_abdomen = _add_mesh(SphereMesh.new(), Vector3(-0.2, 0.36, 0), body_mat)
	var ab := _abdomen.mesh as SphereMesh
	ab.radius = 0.36
	ab.height = 0.66
	ab.radial_segments = 7
	ab.rings = 4
	_abdomen.rotation.z = 0.25
	var head := _add_mesh(SphereMesh.new(), Vector3(0.22, 0.28, 0), body_mat)
	var hd := head.mesh as SphereMesh
	hd.radius = 0.21
	hd.height = 0.34
	hd.radial_segments = 6
	hd.rings = 3
	# Eight eyes, in the arrangement a real spider has: a big forward-facing
	# pair, a row of four above them, and two small ones out at the sides. Two
	# dots read as a bug; eight reads as a spider.
	const EYES := [
		[Vector3(0.42, 0.30, -0.06), 0.05], [Vector3(0.42, 0.30, 0.06), 0.05],
		[Vector3(0.40, 0.38, -0.11), 0.032], [Vector3(0.40, 0.38, -0.04), 0.032],
		[Vector3(0.40, 0.38, 0.04), 0.032], [Vector3(0.40, 0.38, 0.11), 0.032],
		[Vector3(0.33, 0.33, -0.15), 0.026], [Vector3(0.33, 0.33, 0.15), 0.026],
	]
	for spec in EYES:
		var eye := _add_mesh(SphereMesh.new(), spec[0], eye_mat)
		var m := eye.mesh as SphereMesh
		m.radius = spec[1]
		m.height = spec[1] * 2.0
		m.radial_segments = 6
		m.rings = 3
	# Eight legs on hip pivots, four per side, splayed and ready to scuttle.
	# (The legs must be children of their PIVOTS — parenting them to the body
	# root left all eight stacked invisibly inside the abdomen.)
	for i in 4:
		for side in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(-0.25 + i * 0.16, 0.3, side * 0.18)
			pivot.rotation.x = side * 0.85
			pivot.rotation.z = 0.35 - i * 0.22
			add_child(pivot)
			# TWO segments with a knee between them. A single straight rod is
			# what made these read as a bug on sticks; the reference's whole
			# silhouette is the high angular knee and the long taper to a point.
			var femur := MeshInstance3D.new()
			var femur_mesh := CylinderMesh.new()
			femur_mesh.top_radius = 0.028
			femur_mesh.bottom_radius = 0.042
			femur_mesh.height = 0.34
			femur_mesh.radial_segments = 4
			femur_mesh.material = leg_mat
			femur.mesh = femur_mesh
			femur.position = Vector3(0, -0.15, 0)
			pivot.add_child(femur)

			var knee := Node3D.new()
			knee.position = Vector3(0, -0.32, 0)
			knee.rotation.z = -0.95 # kicks the shin back down and outward
			pivot.add_child(knee)

			var tibia := MeshInstance3D.new()
			var tibia_mesh := CylinderMesh.new()
			tibia_mesh.top_radius = 0.026
			tibia_mesh.bottom_radius = 0.004 # to a point, like the reference
			tibia_mesh.height = 0.46
			tibia_mesh.radial_segments = 4
			tibia_mesh.material = leg_mat
			tibia.mesh = tibia_mesh
			tibia.position = Vector3(0, -0.23, 0)
			knee.add_child(tibia)
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
