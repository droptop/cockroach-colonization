class_name Checkpoint3D
extends Area3D

## A signpost by a crack in the skirting: somewhere safe to stash things.
##
## Touching one does two jobs: it moves where Harry respawns, and it BANKS what
## he is carrying. Banked crumbs survive a death; anything gathered since the
## last one does not — it goes to the ghost instead. So the shelter is a real
## decision point rather than just a convenience.
##
## Levels add these through `Level3D.decor_checkpoint()`, near the run-up to
## anything that can kill you repeatedly.

signal reached

@export var radius := 1.1
@export var color := Color(0.55, 0.9, 0.7)

var used := false

var _glow: MeshInstance3D
var _mat: StandardMaterial3D
var _time := 0.0


func _ready() -> void:
	collision_layer = 16 # pickup
	collision_mask = 2 # player
	monitorable = false
	_time = randf() * TAU
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	add_child(shape)

	# A wooden signpost. This was a cone of light, which read as a mysterious
	# prop rather than a marker and sat in the play space looking like a bug.
	# The board still carries the pulse, so an unclaimed shelter still breathes.
	_mat = Block3D.flat_material(Color(0.55, 0.38, 0.22))
	_mat.emission_enabled = true
	_mat.emission = color
	_mat.emission_energy_multiplier = 0.8

	_glow = MeshInstance3D.new()
	var board := BoxMesh.new()
	board.size = Vector3(1.5, 0.82, 0.12)
	board.material = _mat
	_glow.mesh = board
	_glow.position = Vector3(0, 1.32, 0)
	add_child(_glow)

	# Grain, frame rails and both posts in ONE MultiMesh. As eight separate
	# MeshInstances the sign cost eight draw calls, and the drain has three of
	# them: perf_budget_test caught the level going over on exactly this kind of
	# thing. Batched it is one.
	var dark := Block3D.flat_material(Color(0.26, 0.17, 0.1))
	var unit := BoxMesh.new()
	unit.size = Vector3(1.0, 1.0, 1.0)
	unit.material = dark
	var detail := MultiMesh.new()
	detail.transform_format = MultiMesh.TRANSFORM_3D
	detail.mesh = unit
	const PIECES := [
		# Grain, top and bottom only: a line through the middle would strike out
		# the word.
		[Vector3(0, 1.04, 0.07), Vector3(1.42, 0.035, 0.03)],
		[Vector3(0, 1.6, 0.07), Vector3(1.42, 0.035, 0.03)],
		# Frame rails.
		[Vector3(0, 0.88, 0.0), Vector3(1.56, 0.1, 0.14)],
		[Vector3(0, 1.76, 0.0), Vector3(1.56, 0.1, 0.14)],
		# Posts.
		[Vector3(-0.5, 0.42, 0.0), Vector3(0.17, 1.0, 0.12)],
		[Vector3(0.5, 0.42, 0.0), Vector3(0.17, 1.0, 0.12)],
	]
	detail.instance_count = PIECES.size()
	for i in PIECES.size():
		detail.set_instance_transform(i,
			Transform3D(Basis().scaled(PIECES[i][1]), PIECES[i][0]))
	var detail_node := MultiMeshInstance3D.new()
	detail_node.multimesh = detail
	add_child(detail_node)

	# Say what it is. A blank board is just scenery.
	var sign_text := Label3D.new()
	sign_text.text = "CHECKPOINT"
	sign_text.font_size = 64
	sign_text.pixel_size = 0.0075
	sign_text.modulate = Color(0.18, 0.12, 0.07)
	sign_text.outline_size = 0
	sign_text.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign_text.no_depth_test = false
	sign_text.position = Vector3(0, 1.32, 0.08)
	add_child(sign_text)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	# Breathes while unused, steady once claimed.
	var pulse := 0.8 + sin(_time * 2.2) * 0.25 if not used else 1.5
	_mat.emission_energy_multiplier = pulse


func _on_body_entered(body: Node3D) -> void:
	if used or not body.has_method("set_checkpoint"):
		return
	used = true
	body.set_checkpoint(global_position + Vector3(0, 0.4, 0))
	reached.emit()
	Snd.sfx("complete", -8.0, 0.05)
	_mat.emission = Color(1.0, 0.95, 0.7)
	Fx.impact_text(get_parent(), global_position + Vector3(0, 1.2, 0),
		Color(0.7, 1.0, 0.85), "SAFE SPOT", 0.65)
	var tween := create_tween()
	tween.tween_property(_glow, "scale", Vector3(1.35, 1.15, 1.35), 0.16)
	tween.tween_property(_glow, "scale", Vector3.ONE, 0.3)
