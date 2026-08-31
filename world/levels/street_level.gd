extends Level3D

## Level 2 — The Street. Night-time pavement, climbable bins, gutter dash gap.


func _build_decor() -> void:
	# The user's painted night street is the backdrop now: gas lamps, misty
	# terraces and a footbridge. It replaces the flat brick facades, their
	# lit windows and the old sphere moon. 60 wide because this level runs
	# 90 m and a 50 quad shows its edge at the far door.
	var backdrop := ParallaxBackdrop.new()
	backdrop.texture_path = "res://art/backgrounds/street_bg.jpeg"
	backdrop.size = Vector2(60.0, 35.5)
	backdrop.base_y = 8.0
	backdrop.depth_z = -5.8
	add_child(backdrop)
	# Drainpipes and window ledges: the facades were a flat backdrop with lit
	# rectangles on them, and the whole upper storey was unreachable.
	# Note the z: these have to REACH the play plane. Harry is locked to z=0, so
	# a ledge tucked back at z=-3.6 against the facade is scenery with collision
	# on it — which is exactly what these were on the first attempt, and what
	# the comment on decor_pipe_run already warned about.
	for ledge in [[5.0, 5.0], [11.0, 6.5], [46.0, 6.0], [52.0, 3.5]]:
		decor_platform(Vector3(ledge[0], ledge[1], -1.4), Vector3(3.0, 0.4, 3.8),
			Color(0.3, 0.29, 0.36), Color(0.22, 0.21, 0.27), "brick", 0.8)
	# A downpipe bridging pavement to the first ledge, same caveat.
	decor_pipe_run(Vector3(8.0, 0.2, -1.0), Vector3(8.0, 6.2, -1.0), 0.3,
		Color(0.26, 0.27, 0.33), false, true, true)
	decor_pipe_run(Vector3(8.0, 6.0, -1.0), Vector3(13.5, 6.0, -1.0), 0.26,
		Color(0.26, 0.27, 0.33), false, true, true)
	# Street lamp over the road, and a second at the alley mouth so the new
	# opening is not thirty metres of unlit run.
	decor_cylinder(Vector3(22, 2.4, -1.4), 0.12, 6.4, Color(0.16, 0.17, 0.2))
	decor_glow_box(Vector3(22, 5.8, -1.1), Vector3(1.3, 0.5, 0.8), Color(1.0, 0.85, 0.55), 2.0)
	decor_light(Vector3(22, 5.2, 0.5), Color(1.0, 0.85, 0.55), 1.6, 12.0)
	decor_cylinder(Vector3(-18, 2.4, -1.4), 0.12, 6.4, Color(0.16, 0.17, 0.2))
	decor_glow_box(Vector3(-18, 5.8, -1.1), Vector3(1.3, 0.5, 0.8), Color(1.0, 0.85, 0.55), 1.6)
	decor_light(Vector3(-18, 5.2, 0.5), Color(1.0, 0.85, 0.55), 1.4, 11.0)
	# Something green in the flower pot, wilting over its rim.
	decor_pipe_run(Vector3(-23.0, 1.6, -0.3), Vector3(-23.9, 2.6, -0.3), 0.09,
		Color(0.36, 0.5, 0.28))
	decor_pipe_run(Vector3(-23.0, 1.6, 0.3), Vector3(-22.3, 2.8, 0.3), 0.09,
		Color(0.4, 0.55, 0.3))
	# Fireflies and night dust — the alley gets its own thinner field, because a
	# mote box that stops at the old spawn leaves the new opening as dead air.
	decor_motes(Vector3(28, 3.5, 0), Vector3(30, 4, 2), Color(1.0, 0.85, 0.5, 0.3), 22)
	decor_motes(Vector3(-16, 3, 0), Vector3(13, 3.5, 2), Color(1.0, 0.85, 0.5, 0.26), 14)
	# Cold moonlight fill from the left.
	decor_light(Vector3(2, 6, 3), Color(0.6, 0.7, 1.0), 0.5, 16.0)
	# Where the alley meets the street proper, and halfway along the gutter run.
	decor_checkpoint(Vector3(-4.5, 0.5, 1.4))
	decor_checkpoint(Vector3(28.0, 0.5, 1.4))
	# Glowing gap under the house door at the exit.
	decor_glow_box(Vector3(58.4, 0.5, -0.4), Vector3(0.5, 1.2, 1.6), Color(1.0, 0.8, 0.5), 2.2)
	decor_light(Vector3(57.5, 1.0, 1.0), Color(1.0, 0.8, 0.5), 1.2, 5.0)
	# Storm-drain grate hint below the gutter gap, and below the alley gully.
	decor_box(Vector3(37.9, -1.7, 0), Vector3(5.4, 0.3, 4.4), Color(0.08, 0.09, 0.1))
	decor_box(Vector3(-19.5, -1.7, 0), Vector3(2.6, 0.3, 4.4), Color(0.08, 0.09, 0.1))
	# Filthy gutter water dripping off the rooflines. One in the alley too.
	hazard_drip(Vector3(-11.0, 6.8, 0), Color(0.55, 0.7, 0.35), 3.2)
	hazard_drip(Vector3(24.0, 7.5, 0), Color(0.55, 0.7, 0.35), 2.6)
	hazard_drip(Vector3(30.0, 7.2, 0), Color(0.55, 0.7, 0.35), 3.1)
	hazard_drip(Vector3(52.0, 7.0, 0), Color(0.55, 0.7, 0.35), 2.8)
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
	const FORE := Color(0.03, 0.035, 0.05)
	# The near kerb, low enough to frame the bottom of the shot without ever
	# covering his feet on the gutter floor. Continues down the alley.
	decor_box(Vector3(30, -1.5, 3.2), Vector3(64, 2.2, 1.0), FORE)
	decor_box(Vector3(-17, -1.5, 3.2), Vector3(30, 2.2, 1.0), FORE)
	# Railings between the kerb and the road, thin enough to run behind. They
	# stop at x 38: the mantis owns 43 to 57 and her lunges read in silhouette.
	for x in [-29.0, -21.5, -14.0, -6.5, 4.0, 11.5, 19.0, 26.5, 34.0]:
		decor_pipe_run(Vector3(x, -0.6, 3.05), Vector3(x, 2.6, 3.05), 0.09,
			FORE, true, false)
	decor_pipe_run(Vector3(2.0, 2.55, 3.05), Vector3(36.0, 2.55, 3.05), 0.07,
		FORE, true, false)
	decor_pipe_run(Vector3(-31.0, 2.55, 3.05), Vector3(-4.5, 2.55, 3.05), 0.07,
		FORE, true, false)
	# Downpipe off the house front, stopping well above head height.
	decor_pipe_run(Vector3(8.5, 14.0, 3.4), Vector3(8.5, 6.2, 3.4), 0.46,
		FORE, true, false)
	# Telephone wire sagging across the top of frame, short of the arena.
	decor_pipe_run(Vector3(1.0, 10.6, 3.5), Vector3(40.0, 9.4, 3.5), 0.08,
		FORE, true, false)
	# Litter blown up against the kerb — the alley collects more of it.
	decor_scatter(Vector3(-24.0, -0.35, 3.15), Vector3(6.0, 0.2, 0.3), 10, FORE, 0.22, "concrete", 2)
	decor_scatter(Vector3(16.0, -0.35, 3.15), Vector3(9.0, 0.2, 0.3), 14, FORE, 0.22)
	decor_scatter(Vector3(33.0, -0.35, 3.15), Vector3(5.0, 0.2, 0.3), 8, FORE, 0.18)
