extends Level3D

## Level 2 — The Street. Night-time pavement, climbable bins, gutter dash gap.


func _build_decor() -> void:
	# House facades along the back — brick, so the night street has depth.
	decor_box(Vector3(8, 4.5, -5.6), Vector3(17, 13, 1.2), Color(0.16, 0.17, 0.24), "brick", 0.6)
	decor_box(Vector3(28, 3.5, -5.8), Vector3(15, 11, 1.2), Color(0.13, 0.14, 0.2), "brick", 0.6)
	decor_box(Vector3(49, 5, -5.6), Vector3(20, 14, 1.2), Color(0.17, 0.16, 0.23), "brick", 0.6)
	# A few lit windows.
	for pos in [Vector3(5, 6, -4.75), Vector3(11, 7.5, -4.75), Vector3(27, 5, -4.95), Vector3(46, 7, -4.75), Vector3(52, 4.5, -4.75)]:
		decor_glow_box(pos, Vector3(1.6, 2.0, 0.3), Color(0.95, 0.75, 0.45), 1.2)
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
	# Street lamp over the road.
	decor_cylinder(Vector3(22, 2.4, -1.4), 0.12, 6.4, Color(0.16, 0.17, 0.2))
	decor_glow_box(Vector3(22, 5.8, -1.1), Vector3(1.3, 0.5, 0.8), Color(1.0, 0.85, 0.55), 2.0)
	decor_light(Vector3(22, 5.2, 0.5), Color(1.0, 0.85, 0.55), 1.6, 12.0)
	# Fireflies and night dust.
	decor_motes(Vector3(28, 3.5, 0), Vector3(30, 4, 2), Color(1.0, 0.85, 0.5, 0.3), 22)
	# A pale moon hanging over the rooftops.
	var moon := decor_box(Vector3(38, 15, -30), Vector3(0.1, 0.1, 0.1), Color(1, 1, 1))
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = 2.6
	moon_mesh.height = 5.2
	var moon_mat := StandardMaterial3D.new()
	moon_mat.albedo_color = Color(0.92, 0.93, 0.85)
	moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_mat.emission_enabled = true
	moon_mat.emission = Color(0.9, 0.9, 0.8)
	moon_mat.emission_energy_multiplier = 1.1
	moon_mesh.material = moon_mat
	moon.mesh = moon_mesh
	# Cold moonlight fill from the left.
	decor_light(Vector3(2, 6, 3), Color(0.6, 0.7, 1.0), 0.5, 16.0)
	# Halfway along the gutter run.
	decor_checkpoint(Vector3(28.0, 0.5, 1.4))
	# Glowing gap under the house door at the exit.
	decor_glow_box(Vector3(58.4, 0.5, -0.4), Vector3(0.5, 1.2, 1.6), Color(1.0, 0.8, 0.5), 2.2)
	decor_light(Vector3(57.5, 1.0, 1.0), Color(1.0, 0.8, 0.5), 1.2, 5.0)
	# Storm-drain grate hint below the gutter gap.
	decor_box(Vector3(37.9, -1.7, 0), Vector3(5.4, 0.3, 4.4), Color(0.08, 0.09, 0.1))
	# Filthy gutter water dripping off the rooflines.
	hazard_drip(Vector3(24.0, 7.5, 0), Color(0.55, 0.7, 0.35), 2.6)
	hazard_drip(Vector3(30.0, 7.2, 0), Color(0.55, 0.7, 0.35), 3.1)
	hazard_drip(Vector3(52.0, 7.0, 0), Color(0.55, 0.7, 0.35), 2.8)
