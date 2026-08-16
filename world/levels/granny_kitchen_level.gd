extends Level3D

## Level 5 — The Kitchen Floor. Granny's own ground: white tile up the walls,
## worn wooden boards underfoot, cupboards and skirting to scramble over, and
## Granny herself waiting at the far counter.
##
## Where the drain is lit from above by things Harry can't reach, this room is
## lit by a window he can see straight out of — the danger here is not the dark.


func _build_decor() -> void:
	_build_room()
	_build_cupboards()
	_build_clutter()
	# Warm morning light from the window, and a cool bounce off all that tile.
	decor_glow_box(Vector3(12.0, 7.2, -4.7), Vector3(5.0, 5.4, 0.4), Color(1.0, 0.95, 0.82), 1.5)
	decor_light(Vector3(12.0, 6.4, -1.5), Color(1.0, 0.94, 0.82), 1.5, 20.0)
	decor_light(Vector3(34.0, 4.0, 2.0), Color(0.82, 0.9, 1.0), 0.6, 22.0)
	decor_motes(Vector3(14, 4, 0), Vector3(9, 3, 2), Color(1.0, 0.95, 0.8, 0.22), 18)
	# Under the cupboards, and again before Granny notices him.
	decor_checkpoint(Vector3(19.0, 0.4, 1.4))
	decor_checkpoint(Vector3(36.0, 0.4, 1.4))
	# A tap she has left dripping — the only hazard that is not her.
	hazard_drip(Vector3(44.0, 6.6, 0), Color(0.55, 0.8, 1.0), 3.4)


## White tile above, worn boards below, skirting where they meet.
func _build_room() -> void:
	# Tiled back wall. Checker at this density reads as square wall tiles.
	decor_box(Vector3(26, 8.0, -5.6), Vector3(64, 20, 1.2), Color(0.88, 0.9, 0.9), "checker", 1.6)
	# Grout shadow line halfway up, where the tiling stops and plaster begins.
	decor_box(Vector3(26, 9.4, -4.92), Vector3(64, 0.18, 0.2), Color(0.62, 0.66, 0.68))
	# Skirting board along the foot of the wall.
	decor_box(Vector3(26, 0.42, -4.86), Vector3(64, 0.84, 0.3), Color(0.86, 0.87, 0.85))
	decor_box(Vector3(26, 0.86, -4.8), Vector3(64, 0.1, 0.42), Color(0.7, 0.71, 0.7))
	# Board seams down the floor, so the wood reads as planks and not a slab.
	for x in range(-2, 54, 3):
		decor_box(Vector3(x, 0.02, 0.6), Vector3(0.05, 0.02, 7.0), Color(0.3, 0.19, 0.11, 0.55))


## Cupboard fronts and kickboards: the climbable furniture of the room.
func _build_cupboards() -> void:
	for run in [[6.0, 7.0], [20.0, 8.0], [40.0, 12.0]]:
		var cx: float = run[0]
		var width: float = run[1]
		# Kickboard recess under the units.
		decor_box(Vector3(cx, 0.3, -3.4), Vector3(width, 0.6, 1.0), Color(0.24, 0.22, 0.21))
		# The top of each run of units: a step on the way up to the worktop.
		decor_platform(Vector3(cx, 4.7, 0), Vector3(width, 0.45, 2.6),
			Color(0.7, 0.64, 0.54), Color(0.5, 0.44, 0.36), "grain", 0.7)
		# Doors, with a seam and a knob each.
		decor_box(Vector3(cx, 2.6, -3.7), Vector3(width, 4.0, 0.5),
			Color(0.74, 0.68, 0.58), "grain", 0.6)
		decor_box(Vector3(cx, 2.6, -3.42), Vector3(0.08, 4.0, 0.06), Color(0.4, 0.34, 0.28))
		for side in [-1.0, 1.0]:
			decor_cylinder(Vector3(cx + side * width * 0.22, 2.6, -3.3), 0.12, 0.16,
				Color(0.55, 0.56, 0.6))
	# Worktop running over the units at the far end — Granny's side of the room,
	# and now somewhere to be. It was drawn as furniture but was scenery, which
	# meant the whole upper half of the room was a painting.
	decor_platform(Vector3(44, 4.9, 0), Vector3(20, 0.6, 3.2),
		Color(0.24, 0.25, 0.28), Color(0.17, 0.18, 0.21), "speckle", 1.4)
	# The back edge of it, purely visual, sitting where the units meet the wall.
	decor_box(Vector3(44, 4.9, -3.2), Vector3(20, 0.5, 2.2), Color(0.2, 0.21, 0.24), "speckle", 1.4)


## The floor-level obstacle course: things she has left lying about.
func _build_clutter() -> void:
	# Spilled sugar, swept into drifts.
	decor_scatter(Vector3(16.0, 0.1, 0.9), Vector3(2.6, 0.03, 1.0), 24,
		Color(0.95, 0.95, 0.93), 0.09, "speckle", 41)
	decor_scatter(Vector3(31.0, 0.1, 0.7), Vector3(1.8, 0.03, 0.9), 16,
		Color(0.93, 0.92, 0.88), 0.08, "speckle", 42)
	# A broom leaning against the units.
	decor_pipe_run(Vector3(26.5, 0.1, 0.4), Vector3(28.6, 4.6, -0.6), 0.09,
		Color(0.72, 0.58, 0.36))
	decor_box(Vector3(26.4, 0.22, 0.45), Vector3(1.3, 0.35, 0.8), Color(0.5, 0.36, 0.2), "grain", 1.4)
	# Foreground: the underside of a chair and a table leg sweeping past.
	const FORE := Color(0.06, 0.055, 0.05)
	decor_pipe_run(Vector3(9.0, -1.0, 3.1), Vector3(9.0, 5.4, 3.1), 0.34, FORE, true)
	decor_pipe_run(Vector3(36.0, -1.0, 3.3), Vector3(36.0, 5.0, 3.3), 0.3, FORE, true)
	decor_pipe_run(Vector3(4.0, 12.6, 3.4), Vector3(52.0, 12.0, 3.4), 0.55, FORE, true)
