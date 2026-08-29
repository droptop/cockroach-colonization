extends Level3D

## Level 11 — The Abduction. Off the crown of the tree into the night field,
## and the sky is WRONG: a saucer sweeps overhead, its tractor beam roaming
## the grass. Touch the light and it HOLDS you (the web-wrap muscle, learned
## on the Queen) while everything closes in. You dodge that beam the whole
## level — and then the exit is a beam that is not moving. You board the
## thing you feared. That is how the moon happens.
##
## THE PROBE guards the boarding light: eleventh verb, REFLECT — its shimmer
## field shrugs everything except its own fire spooned back.

## The roaming beam's sweep, in x, relative to the level.
const BEAM_MIN_X := 8.0
const BEAM_MAX_X := 38.0
## Cycles per second of the full sweep. 0.09 = one pass every ~5.5 s: readable,
## outrunnable, and still a wall of light you plan around.
const BEAM_SPEED := 0.09

var _beam: Node3D
var _beam_t := 0.0


func _build_decor() -> void:
	_build_night_field()
	_build_saucer()
	_build_boarding_light()
	decor_light(Vector3(20, 7, 2), Color(0.5, 0.65, 0.95), 0.8, 26.0)
	decor_light(Vector3(52, 6, 2), Color(0.45, 0.95, 0.6), 0.7, 18.0)
	decor_motes(Vector3(30, 4, 0), Vector3(32, 4, 2), Color(0.7, 0.9, 1.0, 0.25), 24)
	decor_checkpoint(Vector3(41.0, 0.5, 1.4))
	_build_foreground()


func _process(delta: float) -> void:
	super(delta)
	_sweep_beam(delta)


## The hunting light: a glow column roaming the open stretch on a readable
## sine. Standing in it means being HELD (web_wrap) — wiggle out and run.
func _sweep_beam(delta: float) -> void:
	if _beam == null:
		return
	_beam_t += delta * BEAM_SPEED
	var x := lerpf(BEAM_MIN_X, BEAM_MAX_X, (sin(_beam_t * TAU) + 1.0) * 0.5)
	_beam.position.x = x
	if _player and not _player.is_dead and _player.has_method("web_wrap") \
			and absf(_player.global_position.x - x) < 1.1 \
			and _player.global_position.y < 8.0:
		# web_wrap pops its own WIGGLE FREE text; a second banner is noise.
		if _player.web_wrap(1.3):
			Snd.sfx("sizzle", -6.0, 0.3)


func _build_night_field() -> void:
	# Grass tufts, a tin can, a garden gnome watching it all happen.
	for tuft in [[4.0, 0.9], [15.0, 1.1], [27.0, 0.8], [44.0, 1.0], [58.0, 0.9]]:
		decor_scatter(Vector3(tuft[0], 0.3, -0.6), Vector3(1.6, 0.5, 0.8), 12,
			Color(0.2, 0.38, 0.2), 0.14, "speckle", int(tuft[0]))
	decor_cylinder(Vector3(24.0, 0.9, -2.6), 0.7, 1.8, Color(0.6, 0.62, 0.66))
	# The gnome: cone hat, round body, permanently unbothered.
	decor_cylinder(Vector3(49.0, 1.0, -2.8), 0.6, 1.6, Color(0.4, 0.5, 0.7))
	var hat := decor_box(Vector3(49.0, 2.2, -2.8), Vector3(0.1, 0.1, 0.1), Color(1, 1, 1))
	var hat_mesh := CylinderMesh.new()
	hat_mesh.top_radius = 0.02
	hat_mesh.bottom_radius = 0.5
	hat_mesh.height = 1.0
	hat_mesh.material = Block3D.flat_material(Color(0.8, 0.25, 0.2))
	hat.mesh = hat_mesh
	# The hills and stars beyond.
	decor_box(Vector3(30, 2.0, -12.0), Vector3(90, 8, 1.5), Color(0.06, 0.09, 0.1), "speckle", 0.4)
	decor_scatter(Vector3(30, 20, -26), Vector3(44, 6, 2), 44,
		Color(0.9, 0.92, 1.0), 0.08, "none", 96)


## The saucer: a wide dark lens with a rim of running lights, hanging over
## the sweep. It never lands; its LIGHT does the visiting.
func _build_saucer() -> void:
	var hull := decor_box(Vector3(23, 14.0, -4.0), Vector3(0.1, 0.1, 0.1), Color(1, 1, 1))
	var hull_mesh := SphereMesh.new()
	hull_mesh.radius = 7.0
	hull_mesh.height = 2.8
	hull_mesh.material = Block3D.flat_material(Color(0.16, 0.17, 0.22))
	hull.mesh = hull_mesh
	var dome := decor_box(Vector3(23, 15.4, -4.0), Vector3(0.1, 0.1, 0.1), Color(1, 1, 1))
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 2.4
	dome_mesh.height = 2.6
	var dome_mat := Block3D.flat_material(Color(0.5, 0.9, 0.7, 0.5))
	dome_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dome_mat.emission_enabled = true
	dome_mat.emission = Color(0.4, 0.9, 0.6)
	dome_mat.emission_energy_multiplier = 0.8
	dome_mesh.material = dome_mat
	dome.mesh = dome_mesh
	for i in 8:
		var a := TAU * float(i) / 8.0
		decor_glow_box(Vector3(23 + cos(a) * 6.2, 13.9, -4.0 + sin(a) * 1.2),
			Vector3(0.5, 0.3, 0.4), Color(0.4, 1.0, 0.6), 1.6)
	# THE ROAMING BEAM: the hunting light itself.
	_beam = Node3D.new()
	add_child(_beam)
	var column := MeshInstance3D.new()
	var col_mesh := CylinderMesh.new()
	col_mesh.top_radius = 0.9
	col_mesh.bottom_radius = 1.5
	col_mesh.height = 13.0
	col_mesh.radial_segments = 10
	var col_mat := Block3D.flat_material(Color(0.5, 1.0, 0.7, 0.22))
	col_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	col_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	col_mat.emission_enabled = true
	col_mat.emission = Color(0.45, 1.0, 0.65)
	col_mat.emission_energy_multiplier = 0.7
	col_mesh.material = col_mat
	column.mesh = col_mesh
	column.position = Vector3(0, 6.8, 0)
	_beam.add_child(column)
	_beam.position = Vector3(BEAM_MIN_X, 0, 0)


## The parked beam at the exit: the same light, standing still, and the way
## out stands inside it. What hunted you all level is the door.
func _build_boarding_light() -> void:
	var column := decor_box(Vector3(70.0, 6.5, -0.3), Vector3(0.1, 0.1, 0.1), Color(1, 1, 1))
	var col_mesh := CylinderMesh.new()
	col_mesh.top_radius = 1.0
	col_mesh.bottom_radius = 1.7
	col_mesh.height = 13.0
	col_mesh.radial_segments = 10
	var mat := Block3D.flat_material(Color(0.6, 1.0, 0.75, 0.3))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.55, 1.0, 0.7)
	mat.emission_energy_multiplier = 1.1
	col_mesh.material = mat
	column.mesh = col_mesh
	decor_light(Vector3(70, 2.0, 1.0), Color(0.55, 1.0, 0.7), 1.4, 8.0)


func _build_foreground() -> void:
	const FORE := Color(0.03, 0.05, 0.04)
	decor_box(Vector3(31, -1.8, 3.2), Vector3(78, 2.2, 1.0), FORE)
	for blade in [[3.0, 1.8], [19.0, 2.2], [36.0, 1.9], [55.0, 2.1]]:
		decor_pipe_run(Vector3(blade[0], -1.0, 3.15),
			Vector3(blade[0] + 0.5, blade[1], 3.15), 0.09, FORE, true, false)
	decor_scatter(Vector3(28.0, -0.5, 3.2), Vector3(20.0, 0.2, 0.3), 14, FORE, 0.2, "concrete", 97)
