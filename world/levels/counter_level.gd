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
	# Granny prowls this whole level, so a shelter partway is not optional.
	decor_checkpoint(Vector3(26.0, 0.5, 1.4))
	decor_granny_hazard()
	_build_foreground()


## In FRONT of the play plane — the layer this level never had. Near-black
## silhouettes that sweep past the camera as Harry runs, which is most of what
## sells depth in a 2.5D frame. Without it he is drawn on top of the entire
## level, everywhere, and the picture goes flat.
##
## The rules the drain learned the hard way: keep them narrow and sparse, hang
## them from the roof stopping above his head or rise them from below the floor
## line, and keep them OFF the boss arena, where a black bar covers the one
## thing the fight asks you to read.
func _build_foreground() -> void:
	const FORE := Color(0.035, 0.032, 0.03)
	# You are up on the worktop, so the front of the shot is the counter's own
	# edge: a long lip below the play plane that the camera looks over.
	decor_box(Vector3(28, -1.6, 3.1), Vector3(64, 2.0, 1.1), FORE)
	decor_box(Vector3(28, -0.62, 3.15), Vector3(64, 0.12, 1.2), Color(0.1, 0.1, 0.11))
	# Things stood on the near edge of the counter, between the play and the
	# camera. Kept to x 4-26: the wasp owns 33 to 51 and that fight is entirely
	# about where you are standing.
	decor_cylinder(Vector3(6.0, 1.1, 3.05), 0.75, 3.4, FORE)
	decor_cylinder(Vector3(17.0, 0.5, 3.1), 0.5, 2.2, FORE)
	decor_cylinder(Vector3(25.5, 1.4, 3.0), 0.34, 4.0, FORE)
	# Utensil rail across the top of frame, stopping short of the arena.
	decor_pipe_run(Vector3(2.0, 9.4, 3.4), Vector3(30.0, 9.0, 3.4), 0.12,
		FORE, true, false)
	decor_chain(Vector3(9.0, 8.9, 3.35), 4, FORE, 0.14)
	decor_chain(Vector3(23.0, 8.7, 3.35), 5, FORE, 0.14)
	# Crumbs and spills swept to the near edge.
	decor_scatter(Vector3(14.0, -0.5, 3.2), Vector3(10.0, 0.2, 0.3), 14, FORE, 0.2)
