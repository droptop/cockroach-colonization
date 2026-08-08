extends Level3D

## Level 2 — The Street. Night-time pavement, climbable bins, gutter dash gap.


func _build_decor() -> void:
	# House facades along the back.
	decor_box(Vector3(8, 4.5, -5.6), Vector3(17, 13, 1.2), Color(0.13, 0.14, 0.2))
	decor_box(Vector3(28, 3.5, -5.8), Vector3(15, 11, 1.2), Color(0.1, 0.11, 0.17))
	decor_box(Vector3(49, 5, -5.6), Vector3(20, 14, 1.2), Color(0.14, 0.13, 0.19))
	# A few lit windows.
	for pos in [Vector3(5, 6, -4.9), Vector3(11, 7.5, -4.9), Vector3(27, 5, -5.1), Vector3(46, 7, -4.9), Vector3(52, 4.5, -4.9)]:
		decor_glow_box(pos, Vector3(1.6, 2.0, 0.3), Color(0.95, 0.75, 0.45), 1.2)
	# Street lamp over the road.
	decor_cylinder(Vector3(22, 2.4, -1.4), 0.12, 6.4, Color(0.16, 0.17, 0.2))
	decor_glow_box(Vector3(22, 5.8, -1.1), Vector3(1.3, 0.5, 0.8), Color(1.0, 0.85, 0.55), 2.0)
	decor_light(Vector3(22, 5.2, 0.5), Color(1.0, 0.85, 0.55), 1.6, 12.0)
	# Cold moonlight fill from the left.
	decor_light(Vector3(2, 6, 3), Color(0.6, 0.7, 1.0), 0.5, 16.0)
	# Glowing gap under the house door at the exit.
	decor_glow_box(Vector3(58.4, 0.5, -0.4), Vector3(0.5, 1.2, 1.6), Color(1.0, 0.8, 0.5), 2.2)
	decor_light(Vector3(57.5, 1.0, 1.0), Color(1.0, 0.8, 0.5), 1.2, 5.0)
	# Storm-drain grate hint below the gutter gap.
	decor_box(Vector3(37.9, -1.7, 0), Vector3(5.4, 0.3, 4.4), Color(0.08, 0.09, 0.1))
