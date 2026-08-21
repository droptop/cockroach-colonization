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
	var water := decor_box(Vector3(7, -4.2, 0), Vector3(100, 0.4, 10), Color(0.05, 0.15, 0.19))
	var mat := (water.mesh as BoxMesh).material as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = Color(0.07, 0.28, 0.34)
	mat.emission_energy_multiplier = 0.6
	_build_depth()
	_build_walkways()
	_build_secrets()
	_build_light_shafts()
	_build_grime()
	# Sickly green at the pipe mouths — the only warm-hued thing down here, so
	# the toxic drips stay legible against all that blue-grey.
	decor_light(Vector3(-24.0, 2.0, -1.0), Color(0.35, 0.7, 0.85), 1.0, 12.0)
	decor_light(Vector3(-0.5, 1.6, -1.0), Color(0.4, 0.9, 0.6), 1.2, 8.0)
	decor_light(Vector3(43, 9.8, -1.5), Color(0.4, 0.9, 0.6), 0.9, 7.0)
	# Cold bounce off the water.
	decor_light(Vector3(24, -2.5, 2.0), Color(0.25, 0.6, 0.85), 0.8, 14.0)
	# Toxic drips: one straight down the climbing shaft, one off the outflow
	# pipe onto the upper ledge, one over the mid ledge.
	hazard_drip(Vector3(-23.0, 5.2, 0), Color(0.5, 0.95, 0.4), 3.2)
	hazard_drip(Vector3(34.0, 12.5, 0), Color(0.5, 0.95, 0.4), 2.6)
	hazard_drip(Vector3(43.0, 9.4, 0), Color(0.5, 0.95, 0.4), 3.0)
	hazard_drip(Vector3(26.0, 9.0, 0), Color(0.5, 0.95, 0.4), 3.4)
	# Drifting spores in the murk.
	decor_motes(Vector3(23, 4, 0), Vector3(26, 5, 2), Color(0.55, 0.9, 0.55, 0.32), 30)
	# Mid-climb, and again before the Queen's webs.
	decor_checkpoint(Vector3(-8.0, 1.1, 1.2))
	decor_checkpoint(Vector3(24.0, 1.1, 1.2))
	# The run-up to the Queen. The mid ledge is twelve metres of open floor over
	# standing water and nothing ever came out of it; now the colony does, in
	# three rising waves, before he starts the climb to her.
	decor_climber_wave(Vector3(24.0, 0.9, 0), 3, 2, 9.0)
	decor_checkpoint(Vector3(38.0, 7.7, 1.2))
	_build_exit_grate()


## Depth layers. Everything used to sit on one plane in front of a painted
## backdrop, which is why the chamber read flat no matter how it was lit — the
## art was doing all the depth work and the geometry none. These are the layers
## behind and in front of the play plane. Perspective handles the parallax for
## free: nearer things sweep past faster as the camera tracks Harry, so none of
## this needs a scrolling script. All non-collidable — gameplay is untouched.
func _build_depth() -> void:
	_build_midground()
	_build_foreground()
	_build_rubble()


## Between Harry and the painting: piers and pipework that give the chamber
## structure. Fog thins these out on its own, so they sit back without needing
## to be painted darker.
func _build_midground() -> void:
	for x in [8.0, 21.0, 39.0]:
		decor_box(Vector3(x, 5.0, -3.0), Vector3(1.7, 22.0, 1.0),
			Color(0.17, 0.21, 0.27), "brick", 0.5)
	# Trunk main down the length of the chamber, with two drops off it.
	decor_pipe_run(Vector3(-2, 11.8, -2.7), Vector3(50, 11.0, -2.7), 0.5,
		Color(0.19, 0.23, 0.28))
	decor_pipe_run(Vector3(13, 11.6, -2.6), Vector3(13, 2.5, -2.6), 0.3,
		Color(0.19, 0.23, 0.28))
	decor_pipe_run(Vector3(30, 11.3, -2.6), Vector3(30, 4.0, -2.6), 0.26,
		Color(0.19, 0.23, 0.28))


## In FRONT of the play plane — the layer the level never had. Near-black
## silhouettes that sweep past the camera as Harry runs, which is most of what
## sells depth in a 2.5D frame. Kept narrow and sparse: they cross the view for
## a moment, they never sit on top of a fight.
func _build_foreground() -> void:
	const FORE := Color(0.045, 0.06, 0.08)
	# Hung from the roof, stopping well above Harry's head. A full-height bar
	# would eventually park itself over a jump or a fight; these frame the shot
	# without ever crossing the thing the player needs to read.
	decor_pipe_run(Vector3(7.5, 15.0, 3.2), Vector3(7.5, 4.2, 3.2), 0.55, FORE, true, false)
	decor_pipe_run(Vector3(28.5, 15.0, 3.5), Vector3(28.5, 5.0, 3.5), 0.42, FORE, true, false)
	# Rising out of the water, below the platforms — under the jump arcs, not
	# across them.
	decor_pipe_run(Vector3(16.5, -5.0, 3.2), Vector3(16.5, -1.4, 3.2), 0.45, FORE, true, false)
	decor_pipe_run(Vector3(35.0, -5.0, 3.3), Vector3(35.0, -1.6, 3.3), 0.4, FORE, true, false)
	# Overhead main crossing the top of frame on a slight fall. It STOPS short of
	# the Queen's arena (x 37-47). The note above only held for ground-level
	# play: her fight happens up at y 7.4-13, which is exactly where a foreground
	# pipe at y 11.5 sits, and it was drawn in FORE, near black. It covered the
	# web anchors at y 10.8 - the things the whole fight asks you to see and hit.
	decor_pipe_run(Vector3(12, 12.4, 3.4), Vector3(35.5, 11.7, 3.4), 0.7, FORE, true, false)
	decor_chain(Vector3(21.5, 11.9, 3.2), 14, FORE)


## Rubble is what stops a ledge reading as a box: it breaks the straight top
## edge and the hard corners. Batched into MultiMesh draw calls, not one per
## chunk — see decor_scatter.
func _build_rubble() -> void:
	# Grit and broken concrete along the walkable tops, heaviest at the corners
	# where the silhouette is most obviously a rectangle.
	for top in [
		[Vector3(-37.0, 0.06, 0.7), Vector3(4.0, 0.04, 0.8), 16, 41],
		[Vector3(-23.0, 1.66, 0.7), Vector3(1.6, 0.04, 0.8), 8, 43],
		[Vector3(-8.0, 0.06, 0.7), Vector3(3.5, 0.04, 0.8), 14, 45],
		[Vector3(2.0, 0.06, 0.7), Vector3(3.5, 0.04, 0.8), 16, 11],
		[Vector3(14.3, 1.26, 0.7), Vector3(1.2, 0.04, 0.8), 8, 12],
		[Vector3(23.0, 0.86, 0.7), Vector3(5.4, 0.04, 0.8), 20, 13],
		[Vector3(33.5, 0.86, 0.7), Vector3(2.2, 0.04, 0.8), 10, 14],
		[Vector3(42.0, 7.46, 0.7), Vector3(4.4, 0.04, 0.8), 16, 15],
	]:
		decor_scatter(top[0], top[1], top[2], Color(0.3, 0.35, 0.41), 0.14, "asphalt", top[3])
	# Heavier piles jammed into the corners where ledge meets wall.
	for pile in [
		[Vector3(18.6, 0.92, 0.5), 10, 21], [Vector3(29.4, 0.92, 0.5), 8, 22],
		[Vector3(31.5, 0.94, 0.5), 9, 23], [Vector3(37.6, 7.52, 0.5), 10, 24],
	]:
		decor_scatter(pile[0], Vector3(0.7, 0.12, 0.7), pile[1],
			Color(0.26, 0.31, 0.37), 0.22, "concrete", pile[2])
	# Debris silted up in the standing water at the bottom of the chamber.
	decor_scatter(Vector3(20.0, -3.85, 1.4), Vector3(12.0, 0.12, 2.2), 26,
		Color(0.2, 0.26, 0.29), 0.3, "concrete", 31)
	# Broken slabs, tipped over. Individual meshes — three big shapes earn their
	# draw calls where thirty small ones would not.
	for slab in [[Vector3(31.7, 1.05, 0.6), 0.52], [Vector3(18.5, 1.0, 0.6), -0.44],
			[Vector3(37.7, 7.65, 0.6), 0.4]]:
		var chunk := decor_box(slab[0], Vector3(1.5, 0.22, 1.2),
			Color(0.28, 0.33, 0.39), "concrete", 1.1)
		chunk.rotation = Vector3(0.0, 0.22, slab[1])


## Things worth breaking. Both are optional — nothing on the critical path is
## behind a wall, because gating progress on a build the player may not have is
## how a game gets stuck.
func _build_secrets() -> void:
	# BEHIND the spawn, walling off a nook at the left end of the start ledge.
	# It was on the mid ledge first, straight across the route — "low enough to
	# jump over" is not the same as optional, and the traversal smoke test
	# walked into it and stopped dead. Nothing on the critical path is behind a
	# wall, because gating progress on a build the player may not have is how a
	# game gets stuck.
	var slab := decor_breakable(Vector3(-0.6, 1.05, 0), Vector3(1.0, 2.1, 3.0), 2, 2, "asphalt")
	slab.too_weak_hint = "NEEDS A HEAVIER HIT!"
	# The nook it hides, between it and the left wall.
	decor_glow_box(Vector3(-1.5, 0.15, 0), Vector3(0.8, 0.06, 2.2),
		Color(0.7, 0.95, 1.0), 0.8)


## Pipes you can actually stand on, at the play plane. The chamber was tall and
## almost entirely unused above head height — these make the top of the room a
## route rather than a backdrop, and they are reachable by flight or by wall
## climbing rather than by jump alone.
func _build_walkways() -> void:
	var pipe_col := Color(0.31, 0.37, 0.43)
	# A long low run over the water, giving an alternative to the first gaps.
	decor_pipe_run(Vector3(6.0, 3.4, 0), Vector3(17.5, 3.4, 0), 0.42, pipe_col,
		false, true, true)
	# A stub off the mid ledge, and a higher one bridging toward the shaft.
	decor_pipe_run(Vector3(20.0, 5.2, 0), Vector3(27.5, 5.2, 0), 0.4, pipe_col,
		false, true, true)
	decor_pipe_run(Vector3(29.0, 8.0, 0), Vector3(37.0, 8.0, 0), 0.45, pipe_col,
		false, true, true)
	# And one over the Queen's arena, so the fight has an upper tier from which
	# to reach her webs.
	decor_pipe_run(Vector3(38.5, 10.6, 0), Vector3(46.5, 10.6, 0), 0.4, pipe_col,
		false, true, true)


## The level's whole supply of daylight, in three drops.
func _build_light_shafts() -> void:
	# Over the start ledge: the cap Harry came in through, leaning back the way
	# he fell.
	# Over the outfall he starts in, at the far end of the chamber.
	decor_light_shaft(Vector3(-22.0, 13.6, -0.5), 13.0, RAY_COLD, "grate", 2.6, -4.0)
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
