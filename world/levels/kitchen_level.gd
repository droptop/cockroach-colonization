extends Level3D

## Level 3 — The Kitchen. Warm interior, furniture climb, fridge-cabinet
## wall-jump, pantry crack finale.


func _build_decor() -> void:
	# Kitchen wall — rough plaster. The hallway's stretch is darker: no window
	# in there, and the gloom is what makes the kitchen ahead read as the goal.
	decor_box(Vector3(24, 6, -5.6), Vector3(58, 18, 1.2), Color(0.36, 0.31, 0.27), "speckle", 0.7)
	decor_box(Vector3(-16.5, 6, -5.6), Vector3(27, 18, 1.2), Color(0.27, 0.23, 0.2), "speckle", 0.7)
	# The doorway between hall and kitchen, framed behind the play plane so he
	# walks THROUGH it rather than into it.
	decor_box(Vector3(-3.6, 4.5, -2.1), Vector3(0.7, 9.0, 0.5), Color(0.5, 0.4, 0.3), "grain", 0.8)
	decor_box(Vector3(-1.4, 4.5, -2.1), Vector3(0.7, 9.0, 0.5), Color(0.5, 0.4, 0.3), "grain", 0.8)
	decor_box(Vector3(-2.5, 9.2, -2.1), Vector3(3.4, 0.7, 0.5), Color(0.5, 0.4, 0.3), "grain", 0.8)
	_build_hallway()
	# Window with warm morning glow.
	decor_glow_box(Vector3(20.5, 7.5, -4.76), Vector3(4.2, 5, 0.4), Color(1.0, 0.9, 0.7), 1.4)
	decor_light(Vector3(20.5, 7, -2), Color(1.0, 0.92, 0.75), 1.2, 16.0)
	# Table legs under the table top.
	decor_cylinder(Vector3(8.6, 2, 0.8), 0.22, 4.0, Color(0.4, 0.27, 0.17))
	decor_cylinder(Vector3(15.4, 2, 0.8), 0.22, 4.0, Color(0.4, 0.27, 0.17))
	decor_cylinder(Vector3(8.6, 2, -0.8), 0.22, 4.0, Color(0.4, 0.27, 0.17))
	decor_cylinder(Vector3(15.4, 2, -0.8), 0.22, 4.0, Color(0.4, 0.27, 0.17))
	# Fridge handle + cabinet knobs.
	decor_box(Vector3(30.8, 3.6, 0.9), Vector3(0.18, 1.6, 0.18), Color(0.85, 0.87, 0.9))
	decor_box(Vector3(27.7, 1.4, 1.1), Vector3(0.16, 0.16, 0.16), Color(0.8, 0.7, 0.5))
	# A shelf over the counter, so the room has a top storey rather than a
	# ceiling nobody visits.
	decor_platform(Vector3(20.0, 7.4, -1.0), Vector3(11.0, 0.45, 2.6),
		Color(0.58, 0.44, 0.3), Color(0.42, 0.31, 0.21), "grain", 0.8)
	decor_platform(Vector3(38.0, 5.6, -1.0), Vector3(8.0, 0.45, 2.6),
		Color(0.58, 0.44, 0.3), Color(0.42, 0.31, 0.21), "grain", 0.8)
	# Skirting-board shadow line along the floor.
	decor_box(Vector3(24, 0.35, -4.82), Vector3(58, 0.7, 0.3), Color(0.2, 0.17, 0.15))
	# Rug.
	decor_box(Vector3(40, 0.07, 0.2), Vector3(7, 0.14, 3.2), Color(0.5, 0.24, 0.2))
	# Where the hall opens into the kitchen, and before the rat's patch of floor.
	decor_checkpoint(Vector3(-6.5, 0.5, 1.4))
	decor_checkpoint(Vector3(34.0, 0.5, 1.4))
	# Pantry crack glow at the exit.
	decor_glow_box(Vector3(48.3, 0.8, -0.4), Vector3(0.4, 1.8, 1.4), Color(1.0, 0.75, 0.4), 2.4)
	decor_light(Vector3(47.5, 1.2, 1.0), Color(1.0, 0.75, 0.4), 1.4, 6.0)
	# Hot grease dripping from the stove hood above the counter run.
	# No drips in here. A kitchen worktop is not a sewer, and acid falling out
	# of a ceiling nobody can see read as a leftover from the drain rather than
	# as anything the kitchen was doing.
	# Dust motes floating in the window light.
	decor_motes(Vector3(22, 5, 0), Vector3(24, 4, 2), Color(1.0, 0.92, 0.7, 0.25), 20)
	# Warm ceiling bounce light.
	decor_light(Vector3(12, 8, 2), Color(1.0, 0.9, 0.75), 0.7, 20.0)
	_build_foreground()


## The hallway he comes in along: doormat grime, a hall lamp, and a soft spot
## in the skirting for a heavy Harry to break — the same optional-nook deal as
## the drain and Granny's floor, tucked BEHIND the spawn so it can never gate
## the route.
func _build_hallway() -> void:
	# Dim hall lamp, high up: enough to see by, nothing like the kitchen's sun.
	decor_glow_box(Vector3(-16, 9.5, -4.7), Vector3(2.2, 1.0, 0.4), Color(1.0, 0.85, 0.6), 1.0)
	decor_light(Vector3(-16, 8.5, -1.5), Color(1.0, 0.85, 0.62), 0.9, 15.0)
	# Skirting-board shadow line continues down the hall.
	decor_box(Vector3(-16.5, 0.35, -4.82), Vector3(27, 0.7, 0.3), Color(0.16, 0.13, 0.11))
	# Mud tracked in over the mat.
	decor_scatter(Vector3(-20.0, 0.66, 0.6), Vector3(2.2, 0.03, 1.2), 14,
		Color(0.3, 0.22, 0.15), 0.11, "speckle", 71)
	# Dust in the lamp light.
	decor_motes(Vector3(-16, 4, 0), Vector3(12, 3, 2), Color(0.9, 0.85, 0.7, 0.2), 12)
	# The soft skirting panel and the nook it hides, against the left wall.
	var panel := decor_breakable(Vector3(-29.3, 1.05, 0), Vector3(1.0, 2.1, 3.0), 2, 2, "grain")
	panel.too_weak_hint = "NEEDS A HEAVIER HIT!"
	decor_glow_box(Vector3(-30.0, 0.15, 0), Vector3(0.7, 0.06, 2.2),
		Color(1.0, 0.85, 0.55), 0.8)
	# Hall foreground: banister posts sweeping past, litter along the front.
	const FORE := Color(0.035, 0.03, 0.028)
	for x in [-25.0, -11.0]:
		decor_pipe_run(Vector3(x, -1.2, 3.0), Vector3(x, 9.0, 3.0), 0.34,
			FORE, true, false)
	decor_pipe_run(Vector3(-25.0, 1.4, 3.0), Vector3(-11.0, 1.4, 3.0), 0.16,
		FORE, true, false)
	decor_box(Vector3(-16.5, -1.55, 3.25), Vector3(27, 2.0, 0.9), FORE)
	decor_scatter(Vector3(-18.0, -0.42, 3.2), Vector3(9.0, 0.2, 0.3), 10, FORE, 0.2, "concrete", 72)


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
	const FORE := Color(0.035, 0.03, 0.028)
	# Near table and chair legs, full height and narrow: the strongest depth cue
	# a kitchen has, and you can still read everything between them. Nothing
	# past x 30 — the rat owns the far end of the room.
	for x in [5.0, 13.5, 29.0]:
		decor_pipe_run(Vector3(x, -1.2, 3.0), Vector3(x, 9.0, 3.0), 0.34,
			FORE, true, false)
	# The stretcher bar between the near pair.
	decor_pipe_run(Vector3(5.0, 1.4, 3.0), Vector3(13.5, 1.4, 3.0), 0.16,
		FORE, true, false)
	# Flex hanging down from something on the counter above, well over his head.
	decor_pipe_run(Vector3(21.0, 13.0, 3.4), Vector3(21.0, 7.4, 3.4), 0.1,
		FORE, true, false)
	decor_chain(Vector3(21.0, 7.4, 3.4), 5, FORE, 0.12)
	# Skirting and floor litter along the very front.
	decor_box(Vector3(24, -1.55, 3.25), Vector3(58, 2.0, 0.9), FORE)
	decor_scatter(Vector3(18.0, -0.42, 3.2), Vector3(12.0, 0.2, 0.3), 16, FORE, 0.2)
