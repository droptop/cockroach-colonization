@tool
extends Node3D

## Placeholder cute-toy Harry, matching the designer's character references:
## chubby segmented shell (pill-bug style), big head, huge black eyes with
## glints, blush cheeks, stubby legs. Rusty-red shell over a cream body.
## Built facing +X; Player3D rotates this node to turn around.
## Legs scurry with run speed; antennae sway and randomly twitch.

@export var shell_color := Color(0.72, 0.3, 0.2)
@export var body_color := Color(0.93, 0.87, 0.78)
@export var blush_color := Color(0.95, 0.55, 0.5)

var _built := false
var _body_ref: CharacterBody3D
var _leg_pivots: Array[Node3D] = []
var _leg_base_z: Array[float] = []
var _antenna_pivots: Array[Node3D] = []
var _antenna_base_z: Array[float] = []
var _wing_pivots: Array[Node3D] = []
var _flying := false
var _time := 0.0
var _twitch := 0.0
var _twitch_timer := 1.2


func _ready() -> void:
	_body_ref = get_parent() as CharacterBody3D
	if _built:
		return
	_built = true
	var shell_mat := Block3D.flat_material(shell_color)
	var body_mat := Block3D.flat_material(body_color)
	var black_mat := Block3D.flat_material(Color(0.05, 0.05, 0.06))
	var white_mat := Block3D.flat_material(Color(0.98, 0.98, 0.98))
	var blush_mat := Block3D.flat_material(blush_color)

	# Big round head at the front.
	var head := _sphere(self, Vector3(0.24, 0.26, 0), 0.21, body_mat)
	head.scale = Vector3(0.95, 1.0, 0.95)
	# Huge black eyes + glints, blush cheeks — one set per side.
	for side in [-1.0, 1.0]:
		_sphere(self, Vector3(0.38, 0.3, side * 0.11), 0.065, black_mat)
		_sphere(self, Vector3(0.41, 0.33, side * 0.09), 0.02, white_mat)
		var blush := _sphere(self, Vector3(0.33, 0.2, side * 0.16), 0.045, blush_mat)
		blush.scale = Vector3(1.0, 0.6, 0.6)
	# Segmented shell: three overlapping flattened spheres, shrinking rearward.
	for seg in [[Vector3(0.02, 0.3, 0), 0.24], [Vector3(-0.18, 0.28, 0), 0.21], [Vector3(-0.34, 0.24, 0), 0.17]]:
		var s := _sphere(self, seg[0], seg[1], shell_mat)
		s.scale = Vector3(1.1, 0.85, 1.0)
	# Cream belly under the shell.
	var belly := _sphere(self, Vector3(-0.1, 0.16, 0), 0.19, body_mat)
	belly.scale = Vector3(1.5, 0.7, 0.9)
	# Antennae on pivots at the head so they can sway/twitch from the base.
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.3, 0.4, side * 0.07)
		pivot.rotation.z = -0.7
		pivot.rotation.x = side * 0.35
		add_child(pivot)
		var stalk := _cylinder(pivot, Vector3(0, 0.21, 0), 0.01, 0.016, 0.42, body_mat)
		stalk.rotation = Vector3.ZERO
		_sphere(pivot, Vector3(0, 0.44, 0), 0.028, shell_mat)
		_antenna_pivots.append(pivot)
		_antenna_base_z.append(pivot.rotation.z)
	# Little translucent wings, folded away (hidden) unless flying.
	var wing_mat := Block3D.flat_material(Color(0.96, 0.94, 0.82, 0.55))
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(-0.02, 0.4, side * 0.08)
		pivot.visible = false
		add_child(pivot)
		var wing := _sphere(pivot, Vector3(-0.16, 0.06, side * 0.1), 0.16, wing_mat)
		wing.scale = Vector3(1.7, 0.15, 0.7)
		_wing_pivots.append(pivot)
	# Six stubby legs on hip pivots so they can scurry.
	for i in 3:
		for side in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(-0.28 + i * 0.2, 0.12, side * 0.13)
			pivot.rotation.x = side * 0.4
			add_child(pivot)
			_cylinder(pivot, Vector3(0, -0.09, 0), 0.025, 0.035, 0.18, body_mat)
			_leg_pivots.append(pivot)
			_leg_base_z.append(0.0)


func set_flying(flying: bool) -> void:
	if flying == _flying:
		return
	_flying = flying
	for pivot in _wing_pivots:
		pivot.visible = flying


func _process(delta: float) -> void:
	var speed := 0.0
	if _body_ref:
		speed = clampf(absf(_body_ref.velocity.x) / 4.5, 0.0, 1.2)
	_time += delta * lerpf(2.0, 16.0, minf(speed, 1.0))
	# Wing flutter: fast buzz while flying.
	if _flying:
		var buzz := sin(Time.get_ticks_msec() * 0.05) * 0.6
		for i in _wing_pivots.size():
			var side := -1.0 if i == 0 else 1.0
			_wing_pivots[i].rotation.x = side * (0.5 + buzz)
	# Legs: alternating scurry, tiny idle shuffle when standing.
	var amplitude := lerpf(0.05, 0.55, minf(speed, 1.0))
	for i in _leg_pivots.size():
		var phase := PI * (i % 2) + float(i) * 0.3
		_leg_pivots[i].rotation.z = _leg_base_z[i] + sin(_time + phase) * amplitude
	# Antennae: constant gentle sway plus a random sharp twitch now and then.
	_twitch_timer -= delta
	if _twitch_timer <= 0.0:
		_twitch = 1.0
		_twitch_timer = randf_range(0.9, 2.8)
	_twitch = maxf(_twitch - delta * 5.0, 0.0)
	for i in _antenna_pivots.size():
		var side := -1.0 if i == 0 else 1.0
		var sway := sin(_time * 0.9 + side * 1.7) * 0.07 + sin(_time * 2.3 + side * 0.6) * 0.035
		var twitch_kick := _twitch * 0.4 * (1.0 if i == 0 else 0.7)
		_antenna_pivots[i].rotation.z = _antenna_base_z[i] + sway - twitch_kick


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
