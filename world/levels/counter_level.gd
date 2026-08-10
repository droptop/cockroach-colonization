extends Level3D

## Level 4 — The Counter. Up off the kitchen floor and onto the counter and
## table, closing out with a sugar-bowl finale. Granny prowls this level as
## an environmental hazard rather than a traditional boss (GAME.md §11).


func _build_decor() -> void:
	# Kitchen wall continues up here — same room as level 3.
	decor_box(Vector3(28, 8, -5.6), Vector3(64, 20, 1.2), Color(0.36, 0.31, 0.27), "speckle", 0.7)
	decor_glow_box(Vector3(16, 6.5, -4.76), Vector3(4.2, 5, 0.4), Color(1.0, 0.9, 0.7), 1.4)
	decor_light(Vector3(16, 6, -2), Color(1.0, 0.92, 0.75), 1.2, 16.0)
	decor_light(Vector3(38, 7, 2), Color(1.0, 0.9, 0.75), 0.7, 22.0)
	# Skirting/edge shadow along the counter and table fronts.
	decor_box(Vector3(10, -0.35, -1.98), Vector3(24, 0.7, 0.1), Color(0.2, 0.2, 0.22))
	decor_box(Vector3(40, -0.02, -1.98), Vector3(28, 0.7, 0.1), Color(0.18, 0.14, 0.11))
	# Sugar bowl — the finale, sitting right at the exit.
	decor_cylinder(Vector3(50, 0.9, 0), 0.9, 0.8, Color(0.95, 0.95, 0.98))
	decor_cylinder(Vector3(50, 1.35, 0), 0.7, 0.35, Color(1.0, 1.0, 1.0))
	decor_glow_box(Vector3(50, 1.6, 0), Vector3(0.3, 0.3, 0.3), Color(1, 1, 0.9), 1.0)
	decor_light(Vector3(50, 2.2, 0.5), Color(1.0, 0.98, 0.9), 1.0, 6.0)
	decor_motes(Vector3(30, 4, 0), Vector3(30, 3, 2), Color(1.0, 0.92, 0.7, 0.2), 18)
	decor_granny_hazard()
