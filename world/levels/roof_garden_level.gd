extends Level3D

## Level 9 — The Roof Garden. The user's addition to the arc: after the
## wind-scoured roof, a walled oasis at dawn. The wind stops at the walls —
## that is the roof's lesson paying off as ARCHITECTURE — and the dangers go
## soft and green: a pond that will not hold him, slime, and a fortress with
## eyestalks in the greenhouse. The FORK lives here, because the Snail is the
## fight that finally makes its launch load-bearing.


func _build_decor() -> void:
	_build_walls_and_sky()
	_build_beds()
	_build_pond()
	_build_greenhouse()
	# Dawn: one long warm light and a cool counter from the shade side.
	decor_light(Vector3(14, 6, 2), Color(1.0, 0.8, 0.65), 1.2, 22.0)
	decor_light(Vector3(52, 5, 2), Color(0.8, 0.85, 1.0), 0.6, 20.0)
	# Pollen drifting in the first light.
	decor_motes(Vector3(30, 4, 0), Vector3(34, 4, 2), Color(1.0, 0.92, 0.6, 0.3), 30)
	# The sprinkler, ticking round: cold water off the seed beds.
	hazard_drip(Vector3(13.0, 6.0, 0), Color(0.55, 0.8, 1.0), 2.6)
	hazard_drip(Vector3(41.0, 6.5, 0), Color(0.55, 0.8, 1.0), 3.1)
	# Past the pond, and at the greenhouse door.
	decor_checkpoint(Vector3(34.5, 0.5, 1.4))
	decor_checkpoint(Vector3(51.5, 0.5, 1.4))
	_build_foreground()


## Brick walls all round (the wind-break the level is named for), and a soft
## dawn sky over them.
func _build_walls_and_sky() -> void:
	decor_box(Vector3(34, 6, -5.8), Vector3(80, 16, 1.2), Color(0.4, 0.28, 0.24), "brick", 0.7)
	# Ivy over the back wall in ragged patches.
	for ivy in [[6.0, 4.0, 7.0], [30.0, 6.5, 9.0], [58.0, 3.5, 6.0]]:
		decor_box(Vector3(ivy[0], ivy[1], -5.1), Vector3(ivy[2], 5.0, 0.3),
			Color(0.25, 0.42, 0.24), "speckle", 1.2)
	# The dawn: a glow band along the wall tops.
	decor_glow_box(Vector3(34, 14.5, -6.0), Vector3(80, 2.0, 0.5), Color(1.0, 0.6, 0.5), 0.9)


## Flowers on stems out of every planter: bright heads at hop height, the
## garden's whole colour budget in a few emissive blobs.
func _build_beds() -> void:
	for flower in [[6.5, 2.2, Color(0.95, 0.4, 0.5)], [9.5, 2.4, Color(1.0, 0.8, 0.3)],
			[15.8, 3.8, Color(0.7, 0.5, 0.95)], [18.2, 3.9, Color(0.95, 0.4, 0.5)],
			[37.0, 2.0, Color(1.0, 0.8, 0.3)], [43.0, 1.9, Color(0.7, 0.5, 0.95)]]:
		var x: float = flower[0]
		var top: float = flower[1]
		decor_pipe_run(Vector3(x, top - 1.6, -0.6), Vector3(x, top, -0.6), 0.07,
			Color(0.3, 0.5, 0.28))
		decor_glow_box(Vector3(x, top + 0.25, -0.6), Vector3(0.55, 0.5, 0.5),
			flower[2], 0.7)
	# Fat leaves at the planter feet.
	decor_scatter(Vector3(12.0, 0.15, 0.7), Vector3(4.0, 0.05, 1.0), 16,
		Color(0.3, 0.5, 0.28), 0.16, "speckle", 91)
	decor_scatter(Vector3(41.0, 0.15, 0.7), Vector3(4.0, 0.05, 1.0), 14,
		Color(0.3, 0.5, 0.28), 0.16, "speckle", 92)


## The pond under the lily pads: emissive dawn-pink water, well below the
## hop line, with the death zone waiting under it.
func _build_pond() -> void:
	var water := decor_box(Vector3(27.5, -2.4, 0), Vector3(11, 0.5, 8), Color(0.2, 0.3, 0.45))
	var mat := (water.mesh as BoxMesh).material as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.4, 0.5)
	mat.emission_energy_multiplier = 0.5
	# Reeds at both banks.
	for reed in [[23.5, 0.0], [24.3, 0.2], [31.9, 0.1], [32.6, -0.1]]:
		decor_pipe_run(Vector3(reed[0], reed[1] - 1.2, -1.2),
			Vector3(reed[0] + 0.2, reed[1] + 1.6, -1.2), 0.06, Color(0.4, 0.55, 0.3))


## Glass over the arena: panes that glow with the dawn, and the trellis gate
## behind the Snail — the way up to the tree.
func _build_greenhouse() -> void:
	for pane in 4:
		decor_glow_box(Vector3(55.0 + pane * 4.4, 6.5, -2.6), Vector3(4.0, 5.0, 0.15),
			Color(0.85, 0.95, 1.0, 0.35), 0.35)
	decor_pipe_run(Vector3(53.0, 4.0, -2.6), Vector3(53.0, 9.2, -2.6), 0.12, Color(0.85, 0.87, 0.9))
	decor_pipe_run(Vector3(53.0, 9.2, -2.6), Vector3(71.0, 9.2, -2.6), 0.12, Color(0.85, 0.87, 0.9))
	# Lettuce rows the Snail has been living on.
	for lettuce in [56.0, 59.5, 66.5]:
		decor_glow_box(Vector3(lettuce, 0.5, -1.4), Vector3(1.4, 0.7, 1.0),
			Color(0.5, 0.8, 0.4), 0.4)
	# The trellis at the exit, with the tree's first leaves showing over it.
	for rung in 4:
		decor_pipe_run(Vector3(69.6, 0.6 + rung * 1.1, -1.0),
			Vector3(71.0, 0.6 + rung * 1.1, -1.0), 0.07, Color(0.5, 0.38, 0.26))
	decor_glow_box(Vector3(70.8, 5.4, -1.2), Vector3(1.8, 1.4, 0.8), Color(0.4, 0.7, 0.35), 0.6)
	decor_light(Vector3(69, 1.5, 1.0), Color(0.6, 0.95, 0.6), 1.1, 6.0)


## In FRONT: pot rims and stems sweeping past, and one hose looping across
## the top of frame, short of the greenhouse.
func _build_foreground() -> void:
	const FORE := Color(0.05, 0.055, 0.045)
	decor_box(Vector3(32, -1.7, 3.2), Vector3(76, 2.2, 1.0), FORE)
	decor_cylinder(Vector3(4.0, 0.8, 3.1), 0.8, 2.8, FORE)
	decor_cylinder(Vector3(21.0, 0.5, 3.05), 0.55, 2.2, FORE)
	decor_cylinder(Vector3(46.0, 0.9, 3.1), 0.7, 3.0, FORE)
	for x in [11.0, 35.0]:
		decor_pipe_run(Vector3(x, -1.4, 3.15), Vector3(x + 0.6, 2.4, 3.15), 0.1,
			FORE, true, false)
	decor_pipe_run(Vector3(0.0, 9.6, 3.4), Vector3(50.0, 8.6, 3.4), 0.16,
		FORE, true, false)
	decor_scatter(Vector3(26.0, -0.4, 3.2), Vector3(15.0, 0.2, 0.3), 12, FORE, 0.2, "concrete", 93)
