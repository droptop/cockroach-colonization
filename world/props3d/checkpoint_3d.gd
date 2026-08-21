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

	# Plank grain across the face, and a darker frame around it.
	var dark := Block3D.flat_material(Color(0.24, 0.15, 0.09))
	for i in 3:
		var groove := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(1.42, 0.035, 0.03)
		gm.material = dark
		groove.mesh = gm
		groove.position = Vector3(0, 1.32 + (i - 1) * 0.22, 0.08)
		add_child(groove)
	for edge in [-0.44, 0.44]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(1.56, 0.1, 0.14)
		rm.material = dark
		rail.mesh = rm
		rail.position = Vector3(0, 1.32 + edge, 0)
		add_child(rail)

	# Two posts into the ground.
	for side in [-0.5, 0.5]:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.17, 1.0, 0.12)
		pm.material = Block3D.flat_material(Color(0.4, 0.27, 0.15))
		post.mesh = pm
		post.position = Vector3(side, 0.42, 0)
		add_child(post)

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
