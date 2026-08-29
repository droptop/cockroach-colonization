extends Level3D

## Level 8 — The Roof (BACKLOG item 40, the second half begins). Night air,
## a city of chimneys behind, and a real fall on every side. The WIND is the
## level's antagonist: gusts on a readable rhythm that own the air, with the
## chimneys as taught shelter. The Magpie holds the far gable.


func _build_decor() -> void:
	# The weather itself.
	var wind := Wind3D.new()
	wind.position = Vector3(33, 2, 0)
	add_child(wind)
	_build_skyline()
	_build_rooftop_dressing()
	# Moonlight pools and the skylight's glow from the rooms below.
	decor_light(Vector3(26, 3.5, 1.5), Color(1.0, 0.9, 0.7), 1.1, 8.0)
	decor_glow_box(Vector3(26, 0.55, 0), Vector3(3.2, 0.25, 2.6), Color(1.0, 0.85, 0.55), 1.4)
	decor_light(Vector3(10, 6, 2), Color(0.6, 0.7, 1.0), 0.6, 18.0)
	decor_light(Vector3(58, 5, 2), Color(0.6, 0.7, 1.0), 0.6, 16.0)
	# Leaves and grit riding the air even between gusts.
	decor_motes(Vector3(30, 4, 0), Vector3(32, 4, 2), Color(0.8, 0.7, 0.4, 0.3), 26)
	# In the lee of each chimney, where a run waits out a gust.
	decor_checkpoint(Vector3(9.2, 0.5, 1.4))
	decor_checkpoint(Vector3(36.2, 0.6, 1.4))
	_build_foreground()


## The city beyond the eaves: rooflines and lit windows a long way down and
## back, and the same moon the street hung.
func _build_skyline() -> void:
	decor_box(Vector3(30, -4.0, -14.0), Vector3(100, 12, 1.5), Color(0.07, 0.08, 0.14), "brick", 0.4)
	for roofline in [[0.0, 2.0, 14.0], [22.0, 0.5, 18.0], [48.0, 3.0, 12.0], [66.0, 1.0, 16.0]]:
		decor_box(Vector3(roofline[0], roofline[1], -12.5), Vector3(roofline[2], 1.2, 1.0),
			Color(0.1, 0.11, 0.17))
	for window in [Vector3(-2, -2, -13.2), Vector3(14, -4, -13.2), Vector3(30, -1.5, -13.2),
			Vector3(44, -3.5, -13.2), Vector3(60, -2.5, -13.2)]:
		decor_glow_box(window, Vector3(1.2, 1.5, 0.3), Color(1.0, 0.8, 0.5), 1.0)
	var moon := decor_box(Vector3(50, 17, -32), Vector3(0.1, 0.1, 0.1), Color(1, 1, 1))
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = 3.0
	moon_mesh.height = 6.0
	var moon_mat := StandardMaterial3D.new()
	moon_mat.albedo_color = Color(0.93, 0.94, 0.88)
	moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_mat.emission_enabled = true
	moon_mat.emission = Color(0.9, 0.9, 0.82)
	moon_mat.emission_energy_multiplier = 1.2
	moon_mesh.material = moon_mat
	moon.mesh = moon_mesh
	# Stars: one MultiMesh, not a draw call per pinprick.
	decor_scatter(Vector3(30, 22, -28), Vector3(45, 6, 2), 40,
		Color(0.9, 0.92, 1.0), 0.08, "none", 77)


## Tiles, pots, the aerial, and the gable's TV wire.
func _build_rooftop_dressing() -> void:
	# Ridge tiles: a lip along each run's back edge.
	for run in [[6.0, 16.0], [22.5, 13.0], [41.0, 20.0], [59.0, 16.0]]:
		decor_box(Vector3(run[0], 0.35, -1.85), Vector3(run[1], 0.5, 0.4),
			Color(0.32, 0.22, 0.2), "brick", 1.3)
	# Chimney pots on both stacks.
	for pot in [[10.2, 3.6], [11.8, 3.6], [33.2, 4.4], [34.8, 4.4]]:
		decor_cylinder(Vector3(pot[0], pot[1] + 0.5, -0.4), 0.42, 1.0, Color(0.55, 0.35, 0.28))
	# The TV aerial: mast off its foot, crossbars, and a wire down to the gable.
	decor_pipe_run(Vector3(47.0, 1.6, -0.6), Vector3(47.0, 8.6, -0.6), 0.09,
		Color(0.6, 0.62, 0.66))
	for bar in [7.8, 7.0, 6.2]:
		decor_pipe_run(Vector3(45.6, bar, -0.6), Vector3(48.4, bar, -0.6), 0.05,
			Color(0.6, 0.62, 0.66))
	decor_pipe_run(Vector3(47.0, 8.4, -0.6), Vector3(66.5, 3.0, -0.6), 0.05,
		Color(0.35, 0.36, 0.4))
	# Moss and grit drifted against the windward faces.
	decor_scatter(Vector3(12.6, 0.1, 0.6), Vector3(1.2, 0.05, 1.0), 10,
		Color(0.3, 0.4, 0.25), 0.12, "speckle", 78)
	decor_scatter(Vector3(35.8, 0.3, 0.6), Vector3(1.2, 0.05, 1.0), 10,
		Color(0.3, 0.4, 0.25), 0.12, "speckle", 79)
	# The way off: a glowing gap under the gable coping at the exit.
	decor_glow_box(Vector3(67.0, 1.0, -0.4), Vector3(0.5, 1.6, 1.6), Color(0.7, 1.0, 0.7), 2.0)
	decor_light(Vector3(66, 1.3, 1.0), Color(0.7, 1.0, 0.7), 1.2, 6.0)


## In FRONT: the eave's own guttering and the near roof pitch, sweeping past
## below the play line, plus one washing line crossing the top of frame short
## of the Magpie's arena.
func _build_foreground() -> void:
	const FORE := Color(0.04, 0.045, 0.07)
	decor_box(Vector3(30, -1.8, 3.2), Vector3(74, 2.2, 1.1), FORE)
	decor_pipe_run(Vector3(-4.0, -0.7, 3.1), Vector3(64.0, -0.7, 3.1), 0.22,
		FORE, true, false)
	for x in [2.0, 18.0, 38.0]:
		decor_pipe_run(Vector3(x, -2.6, 3.15), Vector3(x, -0.8, 3.15), 0.12,
			FORE, true, false)
	# The washing line, sagging, with two forgotten pegs.
	decor_pipe_run(Vector3(0.0, 9.8, 3.4), Vector3(44.0, 8.8, 3.4), 0.05,
		FORE, true, false)
	for peg in [[12.0, 9.5], [27.0, 9.1]]:
		decor_box(Vector3(peg[0], peg[1], 3.4), Vector3(0.1, 0.35, 0.08), FORE)
	decor_scatter(Vector3(24.0, -0.5, 3.2), Vector3(14.0, 0.2, 0.3), 12, FORE, 0.2, "concrete", 81)
