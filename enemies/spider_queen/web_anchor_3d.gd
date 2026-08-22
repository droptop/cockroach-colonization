class_name WebAnchor3D
extends AnimatableBody3D

## NOTE ON THE BASE CLASS: AnimatableBody3D, not StaticBody3D.
## AnimatableBody3D *extends* StaticBody3D, so this still collides exactly like
## static level geometry — but an Area3D will not report a StaticBody3D in
## get_overlapping_bodies(), which is how the attack volumes find things. As a
## StaticBody3D this was invisible to every attack in the game: unhittable, by
## anything, ever. Verified in tests/destructible_reachable_test.gd.

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
	# Generous, and deliberately bigger than the KNOT it is drawn around: the
	# web's strands and rings spread wider than the knot does, so this still
	# sits inside what the player can see, and a swing that looks like it
	# connected now does. The opposite rule to a hazard, where the hurtbox may
	# never exceed the visible mesh.
	box.size = Vector3(1.3, 1.2, 0.9)
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
	_build_web(silk)


## An actual orb web rather than five loose threads: SPOKES radiating from the
## knot, and RINGS of chord segments strung between them. It reads as webbing
## from a distance, which five strands never did.
##
## Every segment is one instance of a single unit-height cylinder in ONE
## MultiMesh, scaled per instance, so the whole web is one draw call. Three
## anchors used to cost 15 draw calls in wisps alone, and perf_budget_test
## enforces the per-level ceiling.
func _build_web(silk: StandardMaterial3D) -> void:
	const SPOKES := 9
	const RINGS := [0.42, 0.72, 1.05]
	const OUTER := 1.15

	var seg := CylinderMesh.new()
	seg.top_radius = 0.012
	seg.bottom_radius = 0.012
	seg.height = 1.0
	seg.radial_segments = 3
	seg.material = silk

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = seg
	multi.instance_count = SPOKES + SPOKES * RINGS.size()

	var n := 0
	# Spokes, slightly uneven so it does not read as a wheel.
	for i in SPOKES:
		var a: float = TAU * i / float(SPOKES)
		var reach: float = OUTER * (0.82 + 0.18 * absf(sin(a * 2.0)))
		multi.set_instance_transform(n, _segment(
			Vector3.ZERO, Vector3(cos(a) * reach, sin(a) * reach, 0.0)))
		n += 1
	# Rings: a chord between each neighbouring pair of spokes, sagging inward
	# the way real silk does rather than sitting on a perfect circle.
	for r in RINGS:
		for i in SPOKES:
			var a1: float = TAU * i / float(SPOKES)
			var a2: float = TAU * (i + 1) / float(SPOKES)
			var rr: float = r * (0.92 + 0.08 * sin(a1 * 3.0))
			multi.set_instance_transform(n, _segment(
				Vector3(cos(a1) * rr, sin(a1) * rr, 0.0),
				Vector3(cos(a2) * rr, sin(a2) * rr, 0.0)))
			n += 1

	var web := MultiMeshInstance3D.new()
	web.multimesh = multi
	web.position.z = -0.06 # behind the knot, clear of z-fighting
	add_child(web)


## Places the unit cylinder (which runs along its own Y) so it spans `from` to
## `to` in the XY plane, by scaling Y to the length and spinning about Z.
func _segment(from: Vector3, to: Vector3) -> Transform3D:
	var delta := to - from
	var length := delta.length()
	if length < 0.001:
		return Transform3D(Basis(), from)
	var basis := Basis.from_euler(Vector3(0.0, 0.0, atan2(delta.y, delta.x) - PI / 2.0))
	basis = basis.scaled_local(Vector3(1.0, length, 1.0))
	return Transform3D(basis, from + delta * 0.5)


## `cause` is accepted and ignored here — it only decides the PLAYER's
## death message. Taking it keeps one duck-typed signature across
## everything that can be hurt, so a caller never has to ask what it is
## hitting before it hits it.
func take_damage(amount: int, from_position: Vector3, _cause := "") -> void:
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
