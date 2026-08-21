extends Level3D

## Level 3 — The Kitchen. Warm interior, furniture climb, fridge-cabinet
## wall-jump, pantry crack finale.


func _build_decor() -> void:
	# Kitchen wall — rough plaster.
	decor_box(Vector3(24, 6, -5.6), Vector3(58, 18, 1.2), Color(0.36, 0.31, 0.27), "speckle", 0.7)
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
	# Before the rat's patch of floor.
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
