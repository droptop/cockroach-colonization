extends Level3D

## Level 13 — The Ship. Inside the saucer at last: artificial gravity (his
## weight is back and so are honest jumps), checkered chrome floors, portholes
## with the moon falling away behind, and specimen jars glowing green along
## the walls - some of them have ROACHES in them. This is where everyone the
## saucer took ended up. He is not a stowaway, he is an escapee.
##
## THE JANITOR-BOT patrols the far hold: thirteenth verb, CLOG. Its suction
## never stops; slow junk gets eaten, smacked junk jams the fan.


func _build_decor() -> void:
	_build_hull()
	_build_portholes()
	_build_specimen_jars()
	decor_light(Vector3(12, 5, 2), Color(0.6, 0.8, 0.9), 0.9, 22.0)
	decor_light(Vector3(38, 5, 2), Color(0.5, 0.9, 0.7), 0.7, 20.0)
	decor_light(Vector3(58, 5, 2), Color(0.9, 0.7, 0.5), 0.7, 18.0)
	decor_checkpoint(Vector3(42.0, 0.6, 1.4))
	_build_foreground()


func _build_hull() -> void:
	# Ribs along the ceiling line and humming wall panels.
	for rib_x in [4.0, 14.0, 24.0, 34.0, 44.0, 54.0, 64.0]:
		decor_pipe_run(Vector3(rib_x, 0.2, -2.2), Vector3(rib_x, 7.5, -2.2), 0.14,
			Color(0.5, 0.53, 0.6), true, false)
	for panel in [[9.0, 0.9], [29.0, 1.4], [49.0, 1.1]]:
		decor_glow_box(Vector3(panel[0], 4.2, -2.1), Vector3(2.2, 0.8, 0.15),
			Color(0.35, 0.8, 0.65), panel[1])
	# Ducting overhead - the janitor's territory markers.
	decor_pipe_run(Vector3(2.0, 6.8, -1.8), Vector3(66.0, 6.8, -1.8), 0.22,
		Color(0.45, 0.48, 0.55), true, true)


## Round windows on the black: the moon shrinking, stars, one smear of Earth.
func _build_portholes() -> void:
	for hole in [[8.0, "moon"], [26.0, "stars"], [46.0, "earth"]]:
		var x: float = hole[0]
		var ring := decor_box(Vector3(x, 4.6, -2.25), Vector3(0.1, 0.1, 0.1), Color(1, 1, 1))
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.85
		ring_mesh.outer_radius = 1.05
		ring_mesh.rings = 12
		ring_mesh.ring_segments = 6
		ring_mesh.material = Block3D.flat_material(Color(0.6, 0.62, 0.68))
		ring.mesh = ring_mesh
		var glass := decor_box(Vector3(x, 4.6, -2.3), Vector3(0.1, 0.1, 0.1), Color(1, 1, 1))
		var glass_mesh := CylinderMesh.new()
		glass_mesh.top_radius = 0.85
		glass_mesh.bottom_radius = 0.85
		glass_mesh.height = 0.08
		glass_mesh.radial_segments = 12
		var void_mat := Block3D.flat_material(Color(0.01, 0.01, 0.03))
		glass_mesh.material = void_mat
		glass.mesh = glass_mesh
		glass.rotation.x = PI / 2.0
		match hole[1]:
			"moon":
				decor_glow_box(Vector3(x + 0.2, 4.7, -2.2), Vector3(0.5, 0.5, 0.05),
					Color(0.85, 0.85, 0.8), 0.8)
			"earth":
				decor_glow_box(Vector3(x - 0.15, 4.5, -2.2), Vector3(0.35, 0.35, 0.05),
					Color(0.3, 0.5, 0.9), 0.9)
			_:
				decor_scatter(Vector3(x, 4.6, -2.2), Vector3(0.7, 0.7, 0.05), 8,
					Color(0.9, 0.9, 1.0), 0.05, "none", int(x))


## The jars: green tubes along the back wall, and small dark shapes inside.
## Nobody says the word "specimen" out loud on the HUD; the shapes say it.
func _build_specimen_jars() -> void:
	for jar in [[18.0, true], [20.2, false], [56.0, true], [58.2, true]]:
		var x: float = jar[0]
		var tube := decor_box(Vector3(x, 1.6, -2.0), Vector3(0.1, 0.1, 0.1), Color(1, 1, 1))
		var tube_mesh := CylinderMesh.new()
		tube_mesh.top_radius = 0.55
		tube_mesh.bottom_radius = 0.55
		tube_mesh.height = 2.2
		tube_mesh.radial_segments = 10
		var brine := Block3D.flat_material(Color(0.35, 0.9, 0.6, 0.35))
		brine.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		brine.emission_enabled = true
		brine.emission = Color(0.3, 0.85, 0.55)
		brine.emission_energy_multiplier = 0.6
		tube_mesh.material = brine
		tube.mesh = tube_mesh
		decor_box(Vector3(x, 0.35, -2.0), Vector3(1.3, 0.5, 1.3), Color(0.4, 0.42, 0.48))
		decor_box(Vector3(x, 2.85, -2.0), Vector3(1.3, 0.3, 1.3), Color(0.4, 0.42, 0.48))
		if jar[1]:
			# The occupant: a dark roach-sized lump, floating.
			decor_box(Vector3(x, 1.5, -2.0), Vector3(0.5, 0.25, 0.3),
				Color(0.2, 0.12, 0.08))


func _build_foreground() -> void:
	const FORE := Color(0.04, 0.05, 0.07)
	decor_box(Vector3(31, -1.9, 3.2), Vector3(78, 2.0, 1.0), FORE)
	for crate_x in [10.0, 36.0, 60.0]:
		decor_box(Vector3(crate_x, -0.4, 3.1), Vector3(1.6, 1.2, 0.6), FORE)
