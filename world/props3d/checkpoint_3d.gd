class_name Checkpoint3D
extends Area3D

## A crack in the skirting, a drain cover, somewhere safe to stash things.
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

	# A low arch of light against the skirting — reads as a way in, not a pickup.
	_mat = Block3D.flat_material(Color(color.r, color.g, color.b, 0.55))
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.emission_enabled = true
	_mat.emission = color
	_mat.emission_energy_multiplier = 0.8
	_glow = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.55
	mesh.height = 1.3
	mesh.radial_segments = 10
	mesh.material = _mat
	_glow.mesh = mesh
	_glow.position = Vector3(0, 0.65, 0)
	add_child(_glow)
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
