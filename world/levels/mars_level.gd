extends Level3D

## Level 14 — MARS. The end of the itinerary and the point of the title:
## a butterscotch sky, red dust to the horizon, gravity a heavier cousin of
## the moon's (12 - real jumps again, still floaty at the top), and two small
## moons over the hills. The ship stands behind him and there is nowhere
## further to go: whatever walks this dust is what he came to take it from.
##
## THE WAR TRIPOD strides the last basin: fourteenth verb, TOPPLE. The eye
## rides high above the plane he fights on; the knees do not.

## 0.38 g, tripled for game feel: between the moon's 8 and home's 26.
const MARS_GRAVITY := 12.0
const MARS_FALL_SPEED := 10.0


func _ready() -> void:
	super()
	var p := get_node_or_null("Player")
	if p:
		p.gravity = MARS_GRAVITY
		p.max_fall_speed = MARS_FALL_SPEED


func _build_decor() -> void:
	# The user's painted Mars sky, behind everything procedural. It replaces
	# the old boxy hills/volcano/moons - the dunes roll in front of it.
	var backdrop := ParallaxBackdrop.new()
	backdrop.texture_path = "res://art/backgrounds/mars_bg.jpeg"
	backdrop.size = Vector2(50.0, 33.3)
	backdrop.base_y = 8.0
	backdrop.depth_z = -9.5
	add_child(backdrop)
	_build_desert()
	_build_wreck()
	decor_light(Vector3(16, 7, 3), Color(0.95, 0.75, 0.5), 0.8, 28.0)
	decor_light(Vector3(50, 7, 3), Color(0.9, 0.6, 0.4), 0.7, 26.0)
	decor_checkpoint(Vector3(39.5, 0.6, 1.4))
	_build_foreground()


func _build_desert() -> void:
	# Red rubble lines, ripples in the dust, and the two moons.
	for rubble in [[6.0, 1.8], [19.0, 2.4], [33.0, 2.0], [47.0, 2.8], [62.0, 2.2]]:
		decor_scatter(Vector3(rubble[0], 0.25, -0.8), Vector3(rubble[1], 0.3, 1.0), 11,
			Color(0.6, 0.3, 0.2), 0.17, "concrete", int(rubble[0]))
	# Dunes are OVALS now (user's call: Mars looked "very square") - big
	# squashed spheres in three depths, so the horizon rolls instead of steps.
	# BEHIND the play plane (live report: Harry and the fauna vanished
	# behind sand when this row sat at z 1.6, in front of them).
	for dune in [[12.0, 3.2], [28.0, 4.0], [44.0, 3.0], [58.0, 3.6]]:
		_dune(Vector3(dune[0], 0.0, -1.7), dune[1], Color(0.66, 0.34, 0.22))
	for dune in [[6.0, 7.0], [22.0, 9.5], [40.0, 8.0], [56.0, 10.0], [74.0, 7.5]]:
		_dune(Vector3(dune[0], 0.1, -3.5), dune[1], Color(0.55, 0.27, 0.18))
	for dune in [[15.0, 14.0], [38.0, 17.0], [60.0, 15.0]]:
		_dune(Vector3(dune[0], 0.2, -8.0), dune[1], Color(0.42, 0.2, 0.14))
	# Hills, volcano, moons and stars all retired: the painted backdrop at
	# z -9.5 is the sky now, and anything deeper would hide behind it anyway.
	decor_motes(Vector3(30, 2.5, 0), Vector3(32, 2.5, 2), Color(0.85, 0.6, 0.4, 0.2), 26)


## Somebody's rover, dead on its side, half in the dust. The tripods won.
## Until today.
func _build_wreck() -> void:
	decor_box(Vector3(24.0, 0.9, -3.2), Vector3(2.6, 1.2, 1.6), Color(0.55, 0.5, 0.46), "speckle", 1.3)
	decor_cylinder(Vector3(22.9, 0.5, -2.5), 0.5, 0.3, Color(0.3, 0.3, 0.32))
	decor_cylinder(Vector3(25.1, 0.5, -2.5), 0.5, 0.3, Color(0.3, 0.3, 0.32))
	decor_pipe_run(Vector3(24.0, 1.5, -3.2), Vector3(24.7, 2.6, -3.2), 0.06,
		Color(0.6, 0.6, 0.62), true, false)
	decor_glow_box(Vector3(23.4, 1.3, -2.4), Vector3(0.2, 0.2, 0.1),
		Color(0.9, 0.3, 0.2), 0.9)


## One rolling dune: a sphere squashed flat, mostly buried. Low-poly on
## purpose - the web budget pays per segment.
func _dune(pos: Vector3, radius: float, color: Color) -> void:
	var dune := decor_box(pos, Vector3(0.1, 0.1, 0.1), Color(1, 1, 1))
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 0.5
	mesh.radial_segments = 12
	mesh.rings = 5
	mesh.material = Block3D.flat_material(color)
	dune.mesh = mesh
	dune.position.y = pos.y - radius * 0.05


func _build_foreground() -> void:
	const FORE := Color(0.12, 0.05, 0.04)
	decor_box(Vector3(31, -1.9, 3.2), Vector3(80, 2.0, 1.0), FORE)
	decor_scatter(Vector3(30, -0.6, 3.2), Vector3(26, 0.3, 0.3), 18, FORE, 0.24, "concrete", 55)
	for dune in [[10.0, 4.5], [34.0, 5.5], [58.0, 4.0]]:
		_dune(Vector3(dune[0], -1.6, 3.4), dune[1], FORE)
