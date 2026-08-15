class_name WebAnchor3D
extends StaticBody3D

## A web strand holding the Spider Queen up. Cut all of them and she comes down.
##
## The first destructible thing in the project. It lives on the enemy layer so
## Harry's existing bite area finds it with no special casing — and because the
## pogo's down-area uses that same layer, you can also cut one by dropping onto
## it from above, which is exactly the sort of overlap the movement brief wanted.

signal destroyed

@export var max_health := 2
## Where the strand is pinned. The visual runs from here up to it.
@export var ceiling_y := 14.0

var health := 2

var _visual: MeshInstance3D
var _strand: MeshInstance3D


func _ready() -> void:
	health = max_health
	collision_layer = 4 # enemy, so the bite area sees it
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 0.9, 0.7)
	shape.shape = box
	add_child(shape)

	var silk := Block3D.flat_material(Color(0.88, 0.9, 0.94, 0.85))
	silk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	silk.emission_enabled = true
	silk.emission = Color(0.75, 0.82, 0.9)
	silk.emission_energy_multiplier = 0.35

	# The strand climbing out of frame, so it reads as holding something up.
	_strand = MeshInstance3D.new()
	var strand_mesh := CylinderMesh.new()
	var span: float = maxf(ceiling_y - global_position.y, 0.5)
	strand_mesh.top_radius = 0.045
	strand_mesh.bottom_radius = 0.02
	strand_mesh.height = span
	strand_mesh.radial_segments = 5
	strand_mesh.material = silk
	_strand.mesh = strand_mesh
	_strand.position = Vector3(0, span * 0.5, 0)
	add_child(_strand)

	# The knot you actually hit.
	_visual = MeshInstance3D.new()
	var knot := SphereMesh.new()
	knot.radius = 0.42
	knot.height = 0.72
	knot.radial_segments = 8
	knot.rings = 4
	knot.material = silk
	_visual.mesh = knot
	add_child(_visual)
	for i in 5:
		var wisp := MeshInstance3D.new()
		var wisp_mesh := CylinderMesh.new()
		wisp_mesh.top_radius = 0.015
		wisp_mesh.bottom_radius = 0.005
		wisp_mesh.height = 0.5
		wisp_mesh.radial_segments = 3
		wisp_mesh.material = silk
		wisp.mesh = wisp_mesh
		var angle := TAU * i / 5.0
		wisp.position = Vector3(cos(angle) * 0.3, -0.2, sin(angle) * 0.2)
		wisp.rotation.z = cos(angle) * 0.6
		add_child(wisp)


func take_damage(amount: int, from_position: Vector3) -> void:
	if health <= 0:
		return
	health -= amount
	Fx.hit_flash(_visual, Color(1.0, 1.0, 0.9))
	Fx.spark_burst(get_parent(), global_position, Color(0.9, 0.93, 1.0))
	Snd.sfx("crumb", -2.0, 0.2)
	# Sags as it frays, so the next hit looks like it will finish it.
	var sag := float(max_health - health) / float(max_health) * 0.35
	var tween := create_tween()
	tween.tween_property(_visual, "position:y", -sag, 0.12)
	if health <= 0:
		_snap(from_position)


func _snap(from_position: Vector3) -> void:
	destroyed.emit()
	Snd.sfx("whoosh", -2.0, 0.25)
	Fx.impact_text(get_parent(), global_position, Color(0.9, 0.95, 1.0), "SNAP!", 0.7)
	var away := signf(global_position.x - from_position.x)
	if away == 0.0:
		away = 1.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position",
		position + Vector3(away * 0.8, -1.4, 0.0), 0.4).set_ease(Tween.EASE_IN)
	tween.tween_property(_strand, "scale", Vector3(1.0, 0.05, 1.0), 0.3)
	tween.chain().tween_callback(queue_free)
