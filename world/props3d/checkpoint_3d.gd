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
	# The TRIGGER sits on the play plane, wherever the sign is standing.
	#
	# This was a sphere of radius 1.1 centred on the node, and the signs are
	# placed at z 1.2 to 1.4 so they read against the wall. That put the near
	# face of the sphere at z 0.1 to 0.3 while Harry runs at z 0, so most of
	# them could never fire at all: the ones at 1.4 were dead, and the drain's
	# at 1.2 were a coin toss. Offsetting by -position.z pins the box to z 0 no
	# matter where the post goes, and a box rather than a sphere means the
	# corners reach as far as the middle does.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(radius * 2.0, radius * 2.6, 2.2)
	shape.shape = box
	shape.position = Vector3(0, radius * 0.5, -position.z)
	add_child(shape)

	# A wooden signpost. This was a cone of light, which read as a mysterious
	# prop rather than a marker and sat in the play space looking like a bug.
	# The board still carries the pulse, so an unclaimed shelter still breathes.
	# Grey, not brown. A warm dark board vanished against the drain's wet
	# blue-greys and the granny kitchen's dark units alike; mid grey is the one
	# value that separates from every background in the game.
	_mat = Block3D.flat_material(Color(0.62, 0.64, 0.67))
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
	var dark := Block3D.flat_material(Color(0.3, 0.32, 0.35))
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
	# Small enough to sit ON the board. At 64/0.0075 the word was about three
	# metres wide across a board 1.5 metres across, so it hung off both ends.
	sign_text.font_size = 44
	sign_text.pixel_size = 0.0032
	sign_text.modulate = Color(0.13, 0.14, 0.16)
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
	_raise_banner()
	reached.emit()
	Snd.sfx("complete", -8.0, 0.05)
	_mat.emission = Color(1.0, 0.95, 0.7)
	Fx.impact_text(get_parent(), global_position + Vector3(0, 1.2, 0),
		Color(0.7, 1.0, 0.85), "SAFE SPOT", 0.65)
	var tween := create_tween()
	tween.tween_property(_glow, "scale", Vector3(1.35, 1.15, 1.35), 0.16)
	tween.tween_property(_glow, "scale", Vector3.ONE, 0.3)


## The moment made VISIBLE (user's call): a huge CHECKPOINT banner rises out
## of the floor BEHIND the play plane - in front of the backdrop, never over
## the action - climbs to head height, holds a beat, and drifts up and away.
## Stadium energy, zero obstruction. Once per checkpoint, with the chime.
func _raise_banner() -> void:
	var banner := Label3D.new()
	banner.text = "CHECKPOINT"
	banner.font = load("res://ui/fonts/IronDiceGrit-Black.ttf")
	banner.font_size = 220
	banner.pixel_size = 0.012
	banner.modulate = Color(0.55, 0.95, 0.7, 0.0)
	banner.outline_size = 30
	banner.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	get_parent().add_child(banner)
	banner.global_position = Vector3(global_position.x, global_position.y - 3.0, -3.5)
	var tween := banner.create_tween()
	tween.set_parallel(true)
	tween.tween_property(banner, "global_position:y", global_position.y + 4.5, 0.9
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(banner, "modulate:a", 0.9, 0.35)
	tween.chain().tween_interval(0.9)
	tween.chain().tween_property(banner, "global_position:y",
		global_position.y + 8.0, 0.8).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(banner, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(banner.queue_free)
