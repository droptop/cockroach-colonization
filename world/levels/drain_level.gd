extends Level3D

## Level 1 — The Drain. Wet asphalt and worn concrete in cold blue-grey, lit
## from above: street light drops in through the sewer caps and the storm drain
## over the climbing shaft. Nothing down here has a window — the only outside
## is straight up.

## Street light, cooled by the depth it falls through.
const RAY_COLD := Color(0.64, 0.85, 1.0)
## Front faces of the blocks sit at z=1.76 (the top slab overhangs by 0.06), so
## anything painted onto them rides at 1.84 to clear both (z-fighting).
const FACE_Z := 1.84


func _build_decor() -> void:
	# Painted sewer backdrop with gentle parallax (designer's artwork).
	var backdrop := ParallaxBackdrop.new()
	backdrop.texture_path = "res://art/backgrounds/drain_bg.jpeg"
	add_child(backdrop)
	# Pipe mouth behind the spawn, plus a high outflow pipe near the exit.
	var pipe := Pipe3D.new()
	pipe.position = Vector3(-0.5, 1.4, -2.6)
	pipe.pipe_color = Color(0.26, 0.32, 0.38)
	add_child(pipe)
	var pipe2 := Pipe3D.new()
	pipe2.radius = 1.5
	pipe2.pipe_color = Color(0.26, 0.32, 0.38)
	pipe2.position = Vector3(43, 10.2, -3.2)
	add_child(pipe2)
	# Murky water at the bottom of the chamber, lit cyan like the painting.
	var water := decor_box(Vector3(23, -4.2, 0), Vector3(64, 0.4, 10), Color(0.05, 0.15, 0.19))
	var mat := (water.mesh as BoxMesh).material as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = Color(0.07, 0.28, 0.34)
	mat.emission_energy_multiplier = 0.6
	_build_light_shafts()
	_build_grime()
	# Sickly green at the pipe mouths — the only warm-hued thing down here, so
	# the toxic drips stay legible against all that blue-grey.
	decor_light(Vector3(-0.5, 1.6, -1.0), Color(0.4, 0.9, 0.6), 1.2, 8.0)
	decor_light(Vector3(43, 9.8, -1.5), Color(0.4, 0.9, 0.6), 0.9, 7.0)
	# Cold bounce off the water.
	decor_light(Vector3(24, -2.5, 2.0), Color(0.25, 0.6, 0.85), 0.8, 14.0)
	# Toxic drips: one straight down the climbing shaft, one off the outflow
	# pipe onto the upper ledge, one over the mid ledge.
	hazard_drip(Vector3(34.0, 12.5, 0), Color(0.5, 0.95, 0.4), 2.6)
	hazard_drip(Vector3(43.0, 9.4, 0), Color(0.5, 0.95, 0.4), 3.0)
	hazard_drip(Vector3(26.0, 9.0, 0), Color(0.5, 0.95, 0.4), 3.4)
	# Drifting spores in the murk.
	decor_motes(Vector3(23, 4, 0), Vector3(26, 5, 2), Color(0.55, 0.9, 0.55, 0.32), 30)
	_build_exit_grate()


## The level's whole supply of daylight, in three drops.
func _build_light_shafts() -> void:
	# Over the start ledge: the cap Harry came in through, leaning back the way
	# he fell.
	decor_light_shaft(Vector3(4.0, 13.6, -0.5), 13.4, RAY_COLD, "manhole", 3.0, -8.0)
	# Straight down the climbing shaft, so the route up is also the brightest
	# thing on screen — a kerbside storm drain right above it.
	decor_light_shaft(Vector3(34.0, 13.4, -0.5), 12.4, RAY_COLD, "grate", 2.2)
	# A short one over the upper ledge, hinting the street the exit leads to.
	decor_light_shaft(Vector3(45.0, 13.4, -0.5), 5.6, Color(0.7, 0.87, 1.0), "manhole", 1.8, 6.0)


## Restrained grime: damp bleeding down the block faces, a couple of broader
## wet patches, and pale lime where the pipes have been weeping for years.
func _build_grime() -> void:
	# Dark damp streaks (x, y, width, height, alpha).
	for s in [
		[0.6, -0.9, 0.45, 1.6, 0.5], [4.2, -1.1, 0.3, 1.3, 0.4],
		[8.4, -1.0, 0.35, 1.6, 0.45], [15.1, -0.6, 0.4, 2.2, 0.5],
		[19.5, -0.8, 0.5, 1.6, 0.45], [26.5, -0.6, 0.35, 1.8, 0.4],
		[32.4, -0.7, 0.4, 1.8, 0.45], [38.6, 6.0, 0.4, 1.6, 0.45],
		[44.5, 6.1, 0.3, 1.4, 0.4], [47.6, 8.0, 0.4, 6.0, 0.35],
		# Long bleeds down the climbing shaft — the wet walls you grab.
		[32.2, 3.4, 0.3, 4.2, 0.4], [35.7, 4.2, 0.35, 5.0, 0.4],
	]:
		decor_box(Vector3(s[0], s[1], FACE_Z), Vector3(s[2], s[3], 0.02),
			Color(0.06, 0.12, 0.15, s[4]))
	# Broader dampness, kept faint so it reads as a stain and not a decal.
	for p in [[22.5, -0.4, 3.0, 1.6], [12.0, -1.2, 2.4, 1.2], [41.0, 6.3, 2.6, 1.4]]:
		decor_box(Vector3(p[0], p[1], FACE_Z), Vector3(p[2], p[3], 0.02),
			Color(0.09, 0.17, 0.21, 0.24))
	# Pale lime scale under the outflow pipe and the shaft leak.
	for l in [[43.0, 6.6, 0.55, 1.5], [33.9, 0.1, 0.4, 1.3]]:
		decor_box(Vector3(l[0], l[1], FACE_Z), Vector3(l[2], l[3], 0.02),
			Color(0.62, 0.72, 0.7, 0.3))


## The way out: a barred access grate with the street glowing behind it, not a
## lit rectangle in a wall. Sewer covers, drains and access points stay the
## loudest things in the room.
func _build_exit_grate() -> void:
	decor_glow_box(Vector3(46.6, 8.6, -0.4), Vector3(0.5, 2.4, 1.8),
		Color(0.78, 0.9, 1.0), 2.2)
	# Dark bars in front of the glow, poking clear of it toward the camera.
	for i in 4:
		decor_box(Vector3(46.6, 7.75 + i * 0.55, -0.4), Vector3(0.56, 0.16, 2.0),
			Color(0.08, 0.1, 0.12), "concrete", 1.6)
	decor_light(Vector3(46, 8.8, 1.0), Color(0.78, 0.9, 1.0), 1.4, 6.0)
