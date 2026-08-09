extends Level3D

## Level 1 — The Drain. Murky pipes, mossy stone, climb up and out.


func _build_decor() -> void:
	# Painted sewer backdrop with gentle parallax (designer's artwork).
	var backdrop := ParallaxBackdrop.new()
	backdrop.texture_path = "res://art/backgrounds/drain_bg.jpeg"
	add_child(backdrop)
	# Pipe mouth behind the spawn, plus a high outflow pipe near the exit.
	var pipe := Pipe3D.new()
	pipe.position = Vector3(-0.5, 1.4, -2.6)
	add_child(pipe)
	var pipe2 := Pipe3D.new()
	pipe2.radius = 1.5
	pipe2.position = Vector3(43, 10.2, -3.2)
	add_child(pipe2)
	# Murky water surface at the bottom of the chamber.
	var water := decor_box(Vector3(23, -4.2, 0), Vector3(64, 0.4, 10), Color(0.05, 0.16, 0.15))
	var mat := (water.mesh as BoxMesh).material as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = Color(0.05, 0.2, 0.18)
	mat.emission_energy_multiplier = 0.6
	# Sickly green glow from the pipes, cool fill light over the water.
	decor_light(Vector3(-0.5, 1.6, -1.0), Color(0.4, 0.9, 0.6), 1.4, 8.0)
	decor_light(Vector3(43, 9.8, -1.5), Color(0.4, 0.9, 0.6), 1.0, 7.0)
	decor_light(Vector3(24, -2.5, 2.0), Color(0.2, 0.6, 0.6), 0.8, 14.0)
	# Toxic drips: one straight down the climbing shaft, one off the outflow
	# pipe onto the upper ledge, one over the mid ledge.
	hazard_drip(Vector3(34.0, 12.5, 0), Color(0.5, 0.95, 0.4), 2.6)
	hazard_drip(Vector3(43.0, 9.4, 0), Color(0.5, 0.95, 0.4), 3.0)
	hazard_drip(Vector3(26.0, 9.0, 0), Color(0.5, 0.95, 0.4), 3.4)
	# Drifting spores in the murk.
	decor_motes(Vector3(23, 4, 0), Vector3(26, 5, 2), Color(0.55, 0.9, 0.55, 0.32), 30)
	# Glowing grate at the exit.
	decor_glow_box(Vector3(46.6, 8.6, -0.4), Vector3(0.5, 2.4, 1.8), Color(0.85, 0.95, 0.7), 2.2)
	decor_light(Vector3(46, 8.8, 1.0), Color(0.85, 0.95, 0.7), 1.4, 6.0)
