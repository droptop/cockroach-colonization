extends Level3D

## Level 6 — The Tabletop. Up among the crockery, where every platform is
## something Granny eats off and the floor is a very long way down.
##
## Deliberately not the kitchen floor with a new backdrop: the route is a
## scramble across scattered objects rather than a run along a flat boards, the
## danger comes from the sides rather than from above, and the level ends with
## something looking at you.


func _build_decor() -> void:
	_build_room_beyond()
	_build_settings()
	_build_spills()
	_build_edges()
	_build_cat_presence()
	# Beside the cup, and again before the cat is close enough to swipe.
	decor_checkpoint(Vector3(22.5, 0.4, 1.4))
	decor_checkpoint(Vector3(38.5, 0.4, 1.4))
	# Overhead lamp, low and warm — this is a laid table.
	decor_glow_box(Vector3(26, 12.4, -2.0), Vector3(4.0, 0.5, 3.0), Color(1.0, 0.92, 0.75), 1.6)
	decor_light(Vector3(26, 11.4, 0.0), Color(1.0, 0.92, 0.78), 1.8, 26.0)
	decor_light(Vector3(50, 6.0, 2.0), Color(0.9, 0.85, 1.0), 0.5, 20.0)
	decor_motes(Vector3(26, 5, 0), Vector3(24, 4, 2), Color(1.0, 0.95, 0.85, 0.2), 20)


## The room carries on past the table: a far wall a long way back, so the table
## reads as furniture in a room rather than as the ground.
func _build_room_beyond() -> void:
	decor_box(Vector3(26, 10.0, -13.0), Vector3(90, 30, 1.2), Color(0.5, 0.46, 0.44), "speckle", 0.5)
	decor_box(Vector3(26, -6.0, -11.0), Vector3(90, 1.0, 1.0), Color(0.34, 0.24, 0.18))


## Crockery and cutlery: the platforms, given their tells so each reads as an
## object rather than as a coloured block.
func _build_settings() -> void:
	# Dinner plate, with a rim.
	decor_cylinder(Vector3(9.0, 0.28, 0), 3.0, 0.42, Color(0.93, 0.93, 0.9))
	decor_cylinder(Vector3(9.0, 0.5, 0), 2.3, 0.12, Color(0.86, 0.87, 0.86))
	# Cup and its saucer.
	decor_cylinder(Vector3(20.0, 0.16, 0), 2.2, 0.24, Color(0.92, 0.92, 0.89))
	decor_cylinder(Vector3(20.0, 1.5, 0), 1.5, 2.4, Color(0.95, 0.94, 0.9))
	decor_cylinder(Vector3(20.0, 2.6, 0), 1.25, 0.3, Color(0.5, 0.34, 0.22)) # cold tea
	# Handle.
	decor_pipe_run(Vector3(21.4, 1.0, 0), Vector3(21.4, 2.2, 0), 0.22, Color(0.95, 0.94, 0.9))
	# Salt and pepper, side by side, with perforated caps.
	for shaker in [[30.0, Color(0.95, 0.95, 0.93), Color(0.85, 0.86, 0.88)],
			[33.2, Color(0.42, 0.36, 0.32), Color(0.7, 0.7, 0.72)]]:
		var x: float = shaker[0]
		decor_cylinder(Vector3(x, 1.6, 0), 1.0, 3.2, shaker[1])
		decor_cylinder(Vector3(x, 3.35, 0), 1.05, 0.4, shaker[2])
		for hole in [-0.35, 0.0, 0.35]:
			decor_box(Vector3(x + hole, 3.56, 0.0), Vector3(0.12, 0.04, 0.12),
				Color(0.2, 0.2, 0.22))
	# The vase, tallest thing on the table, with something in it.
	decor_cylinder(Vector3(41.0, 2.4, -0.4), 1.7, 4.8, Color(0.35, 0.55, 0.62))
	decor_cylinder(Vector3(41.0, 5.0, -0.4), 1.2, 0.6, Color(0.28, 0.45, 0.52))
	for stem in [[-0.5, 6.6, Color(0.85, 0.7, 0.3)], [0.4, 7.2, Color(0.8, 0.4, 0.5)]]:
		decor_pipe_run(Vector3(41.0, 5.0, -0.4),
			Vector3(41.0 + stem[0] * 2.0, stem[1], -0.4), 0.09, Color(0.35, 0.5, 0.28))
		decor_glow_box(Vector3(41.0 + stem[0] * 2.0, stem[1], -0.4),
			Vector3(0.7, 0.7, 0.5), stem[2], 0.4)
	# Cutlery laid out: a fork and a spoon to run along.
	decor_box(Vector3(15.0, 0.14, 1.2), Vector3(4.5, 0.16, 0.7), Color(0.78, 0.8, 0.84))
	decor_box(Vector3(26.0, 0.1, 0.0), Vector3(5.0, 0.16, 1.0), Color(0.78, 0.8, 0.84))
	decor_cylinder(Vector3(28.2, 0.16, 0.0), 0.7, 0.22, Color(0.8, 0.82, 0.86))
	# Napkin, folded.
	decor_box(Vector3(36.0, 0.1, 0.8), Vector3(4.0, 0.12, 3.0), Color(0.82, 0.5, 0.5))
	decor_box(Vector3(36.0, 0.2, 0.8), Vector3(3.2, 0.1, 2.2), Color(0.88, 0.58, 0.58))


## Crumbs, sugar and a spill — the small stuff that makes a table look used.
func _build_spills() -> void:
	decor_scatter(Vector3(13.0, 0.12, 0.6), Vector3(3.0, 0.03, 1.4), 26,
		Color(0.85, 0.72, 0.48), 0.11, "speckle", 61)
	decor_scatter(Vector3(31.5, 0.12, 1.2), Vector3(2.4, 0.03, 1.2), 20,
		Color(0.96, 0.96, 0.94), 0.08, "speckle", 62)
	decor_scatter(Vector3(45.0, 0.12, -0.6), Vector3(2.0, 0.03, 1.0), 14,
		Color(0.8, 0.66, 0.42), 0.1, "speckle", 63)
	# A ring of spilled tea, still wet.
	var spill := decor_cylinder(Vector3(24.0, 0.06, 1.6), 1.8, 0.08, Color(0.4, 0.28, 0.18))
	var mat := (spill.mesh as CylinderMesh).material as StandardMaterial3D
	mat.roughness = 0.35 # the sheen is what says "wet"


## The table ends, and the ends are lethal. Say so before he finds out.
func _build_edges() -> void:
	for edge in [-1.0, 55.0]:
		decor_box(Vector3(edge, -0.1, 0), Vector3(1.2, 0.5, 8.0), Color(0.42, 0.28, 0.16), "grain", 1.2)
		# Hazard banding right at the lip.
		for i in 7:
			decor_glow_box(Vector3(edge, 0.22, -3.2 + i * 1.05), Vector3(1.0, 0.06, 0.5),
				Color(1.0, 0.75, 0.2) if i % 2 == 0 else Color(0.2, 0.18, 0.16), 0.5)


## The cat, before the cat: eyes in the dark and a paw print, so the encounter
## is foreshadowed rather than sprung.
func _build_cat_presence() -> void:
	for eye in [-0.9, 0.9]:
		decor_glow_box(Vector3(52.0 + eye * 1.6, 9.0, -10.5), Vector3(0.9, 0.5, 0.3),
			Color(0.95, 0.85, 0.3), 1.4)
	# A dusty print left on the table earlier.
	decor_box(Vector3(48.0, 0.05, 1.0), Vector3(2.2, 0.04, 1.8), Color(0.55, 0.5, 0.46, 0.5))
	for toe in [-0.7, 0.0, 0.7]:
		decor_box(Vector3(48.0 + toe * 0.8, 0.05, 2.1), Vector3(0.55, 0.04, 0.6),
			Color(0.55, 0.5, 0.46, 0.5))
