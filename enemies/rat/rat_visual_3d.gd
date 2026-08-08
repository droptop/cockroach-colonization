@tool
extends Node3D

## THE RAT: hulking grey-brown body, pointed snout with pink nose, round pink
## ears, glowing red eyes, whiskers, long pink tail, four stomping legs.
## Built facing +X; the boss flips scale.x. set_rearing() tips it back for
## the charge telegraph.

@export var fur_color := Color(0.45, 0.4, 0.38)
@export var belly_color := Color(0.55, 0.5, 0.47)
@export var pink_color := Color(0.85, 0.6, 0.6)
@export var eye_color := Color(0.9, 0.15, 0.1)

var _built := false
var _body_ref: CharacterBody3D
var _leg_pivots: Array[Node3D] = []
var _root: Node3D
var _time := 0.0


func _ready() -> void:
	_body_ref = get_parent() as CharacterBody3D
	if _built:
		return
	_built = true
	var fur := Block3D.flat_material(fur_color)
	var belly := Block3D.flat_material(belly_color)
	var pink := Block3D.flat_material(pink_color)
	var eye_mat := Block3D.flat_material(eye_color)
	eye_mat.emission_enabled = true
	eye_mat.emission = eye_color
	eye_mat.emission_energy_multiplier = 1.6

	_root = Node3D.new()
	add_child(_root)
	# Big haunched body.
	var body := _sphere(_root, Vector3(-0.3, 1.05, 0), 0.95, fur)
	body.scale = Vector3(1.35, 1.0, 0.85)
	var chest := _sphere(_root, Vector3(0.55, 0.85, 0), 0.6, belly)
	chest.scale = Vector3(1.0, 0.95, 0.8)
	# Head + snout.
	var head := _sphere(_root, Vector3(1.15, 1.15, 0), 0.42, fur)
	head.scale = Vector3(1.1, 0.95, 0.85)
	var snout := _cylinder(_root, Vector3(1.62, 1.05, 0), 0.05, 0.3, 0.5, belly)
	snout.rotation.z = -PI / 2
	_sphere(_root, Vector3(1.88, 1.05, 0), 0.08, pink) # nose
	# Ears.
	for side in [-1.0, 1.0]:
		var ear := _sphere(_root, Vector3(0.95, 1.62, side * 0.28), 0.2, pink)
		ear.scale = Vector3(0.9, 1.0, 0.35)
		_sphere(_root, Vector3(1.42, 1.28, side * 0.18), 0.07, eye_mat)
		# Whiskers.
		for w in 2:
			var whisker := _cylinder(_root, Vector3(1.7, 1.0 - w * 0.08, side * 0.2), 0.006, 0.006, 0.5, belly)
			whisker.rotation.x = side * (1.25 + w * 0.2)
	# Tail: three curved pink segments trailing behind.
	for i in 3:
		var seg := _cylinder(_root, Vector3(-1.35 - i * 0.42, 0.75 + i * 0.18, 0), 0.05 - i * 0.01, 0.06 - i * 0.01, 0.5, pink)
		seg.rotation.z = 1.2 + i * 0.35
	# Four stout legs.
	for i in 2:
		for side in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(-0.75 + i * 1.35, 0.45, side * 0.4)
			add_child(pivot)
			_cylinder(pivot, Vector3(0, -0.22, 0), 0.11, 0.14, 0.5, fur)
			_leg_pivots.append(pivot)


func set_rearing(rearing: bool) -> void:
	if _root == null:
		return
	var tween := create_tween()
	tween.tween_property(_root, "rotation:z", 0.5 if rearing else 0.0, 0.25)


func _process(delta: float) -> void:
	var speed := 0.0
	if _body_ref:
		speed = clampf(absf(_body_ref.velocity.x) / 5.0, 0.0, 1.2)
	_time += delta * lerpf(3.0, 16.0, minf(speed, 1.0))
	var amplitude := lerpf(0.03, 0.5, minf(speed, 1.0))
	for i in _leg_pivots.size():
		_leg_pivots[i].rotation.z = sin(_time + PI * (i % 2)) * amplitude


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
	mesh.radial_segments = 8
	mesh.material = mat
	inst.mesh = mesh
	inst.position = pos
	parent.add_child(inst)
	return inst
