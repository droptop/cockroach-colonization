@tool
class_name LightShaft3D
extends Node3D

## A shiny, grainy shaft of street light falling in through a sewer cap or
## storm drain overhead. The node's origin sits AT the opening; the cover is
## built there and the beam hangs downward from it.
##
## Deliberately fake volumetrics: the Compatibility renderer the web build
## ships on has no volumetric fog, so this is one additive unshaded cone with a
## grainy gradient baked into its texture, a handful of drifting motes for the
## dust in the light, and one cheap shadowless omni so the beam actually lands
## on the geometry instead of floating over it.

@export var shaft_height := 13.0:
	set(value):
		shaft_height = value
		_refresh()
@export var top_radius := 0.85:
	set(value):
		top_radius = value
		_refresh()
@export var bottom_radius := 2.6:
	set(value):
		bottom_radius = value
		_refresh()
@export var beam_color := Color(0.66, 0.86, 1.0):
	set(value):
		beam_color = value
		_refresh()
## Beam OPACITY, not brightness. At 1.0 these read as solid cream cones rather
## than light, and the one over the Queen's right-hand web anchor hid the thing
## the whole fight asks you to see. Cut to a fifth; the point lights they cast
## are untouched, so the levels are lit the same.
@export var beam_energy := 0.2:
	set(value):
		beam_energy = value
		_refresh()
## Lean the beam off vertical (degrees) — light rarely drops dead straight.
@export var tilt_degrees := 0.0:
	set(value):
		tilt_degrees = value
		_refresh()
@export_enum("manhole", "grate", "none") var cap_style := "manhole":
	set(value):
		cap_style = value
		_refresh()
## Dust drifting down inside the beam. 0 disables it.
@export var grain_amount := 16:
	set(value):
		grain_amount = value
		_refresh()
## Degrees per second the cone spins about its own axis, sweeping the baked
## streaks around so the beam shimmers instead of sitting there like a decal.
@export var shimmer_speed := 7.0

static var _beam_tex: Texture2D

var _pivot: Node3D
var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _time := 0.0


func _ready() -> void:
	_refresh()


func _process(delta: float) -> void:
	if _beam == null or Engine.is_editor_hint():
		return
	_time += delta
	_beam.rotation.y += deg_to_rad(shimmer_speed) * delta
	# Slow breathe on top of the spin: dust shifting somewhere up on the street.
	_beam_mat.albedo_color.a = beam_energy * (0.88 + sin(_time * 0.7) * 0.12)


func _refresh() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		child.queue_free()
	_pivot = Node3D.new()
	_pivot.rotation.z = deg_to_rad(tilt_degrees)
	add_child(_pivot)
	_build_beam()
	_build_grain()
	_build_landing_light()
	_build_cap()


func _build_beam() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = shaft_height
	mesh.radial_segments = 12
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.albedo_color = Color(beam_color.r, beam_color.g, beam_color.b, beam_energy)
	_beam_mat.albedo_texture = beam_texture()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# Open cone: without back faces you lose the far wall of the beam, and
	# without depth-write the front and back stop fighting over who draws.
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if "disable_fog" in _beam_mat:
		_beam_mat.disable_fog = true # the murk must not eat the light
	mesh.material = _beam_mat
	_beam = MeshInstance3D.new()
	_beam.mesh = mesh
	_beam.position = Vector3(0, -shaft_height / 2.0, 0)
	_pivot.add_child(_beam)


## Vertical gradient (bright at the opening, gone by the floor) multiplied by
## stretched noise for the ray banding and fine noise for the sparkle. Cached:
## every shaft in every level shares the one texture and just tints it.
static func beam_texture() -> Texture2D:
	if _beam_tex != null:
		return _beam_tex
	const W := 64
	const H := 192
	# Broad bands running down the beam...
	var rays := FastNoiseLite.new()
	rays.seed = 909
	rays.frequency = 0.05
	rays.fractal_octaves = 3
	# ...and finer grain riding on top of them.
	var grit := FastNoiseLite.new()
	grit.seed = 4321
	grit.frequency = 0.05
	grit.fractal_octaves = 2
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		var t := float(y) / float(H - 1) # 0 at the cap, 1 at the floor
		var fade := pow(1.0 - t, 0.8)
		for x in W:
			var band := _ring_noise(rays, x, y, W, 19.0, 0.35)
			# Grain in clumps of a few pixels. Any finer and it aliases into
			# crawling static once the web build scales the canvas down.
			var speck := _ring_noise(grit, x, y, W, 70.0, 3.0)
			var a := fade * (0.35 + band * 0.62) * (0.8 + speck * 0.4)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	_beam_tex = ImageTexture.create_from_image(img)
	return _beam_tex


## Noise that wraps around the cone with no seam AND no loss of contrast: walk
## a circle through the noise field as u goes 0→1, so the last column genuinely
## neighbours the first. Cross-fading two samples instead would wrap just as
## cleanly but average the contrast away. `ring_radius` sets how many bands fit
## around the circumference; height is the third axis.
static func _ring_noise(noise: FastNoiseLite, x: int, y: int, w: int,
		ring_radius: float, sy: float) -> float:
	var ang := TAU * float(x) / float(w)
	return noise.get_noise_3d(cos(ang) * ring_radius, sin(ang) * ring_radius,
		float(y) * sy) * 0.5 + 0.5


func _build_grain() -> void:
	if grain_amount <= 0:
		return
	var motes := CPUParticles3D.new()
	motes.amount = grain_amount
	motes.lifetime = 6.5
	motes.preprocess = 6.5
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(bottom_radius * 0.5, shaft_height * 0.45, 0.5)
	motes.direction = Vector3(0, -1, 0)
	motes.spread = 22.0
	motes.initial_velocity_min = 0.05
	motes.initial_velocity_max = 0.28
	motes.gravity = Vector3(0.05, -0.14, 0.0)
	motes.scale_amount_min = 0.4
	motes.scale_amount_max = 1.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(beam_color.r, beam_color.g, beam_color.b, 0.16)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = beam_color
	mat.emission_energy_multiplier = 1.1
	mesh.material = mat
	motes.mesh = mesh
	motes.position = Vector3(0, -shaft_height * 0.5, 0)
	_pivot.add_child(motes)


func _build_landing_light() -> void:
	var light := OmniLight3D.new()
	light.light_color = beam_color
	light.light_energy = 1.1 # independent of beam opacity
	light.omni_range = bottom_radius * 4.0
	light.shadow_enabled = false
	light.position = Vector3(0, -shaft_height + 1.2, 0)
	_pivot.add_child(light)


## The opening itself. Sewer covers and drains stay visually prominent — they
## are the level's landmarks, and they explain where the light comes from.
func _build_cap() -> void:
	match cap_style:
		"manhole":
			var lid := MeshInstance3D.new()
			var lid_mesh := CylinderMesh.new()
			lid_mesh.top_radius = top_radius * 1.7
			lid_mesh.bottom_radius = top_radius * 1.7
			lid_mesh.height = 0.3
			lid_mesh.radial_segments = 14
			lid_mesh.material = Block3D.textured_material(
				Color(0.11, 0.13, 0.16), "asphalt", 1.6)
			lid.mesh = lid_mesh
			add_child(lid)
			# Light leaking through the lifting slots in the underside.
			for i in 3:
				_glow_bar(Vector3(-top_radius * 0.7 + i * top_radius * 0.7, -0.18, 0.0),
					Vector3(top_radius * 0.34, 0.06, top_radius * 1.9))
		"grate":
			var frame := MeshInstance3D.new()
			var frame_mesh := BoxMesh.new()
			frame_mesh.size = Vector3(top_radius * 3.4, 0.28, top_radius * 2.6)
			frame_mesh.material = Block3D.textured_material(
				Color(0.1, 0.12, 0.15), "concrete", 1.4)
			frame.mesh = frame_mesh
			add_child(frame)
			# Kerbside storm drain: light comes down between the bars.
			for i in 4:
				_glow_bar(Vector3(-top_radius * 1.2 + i * top_radius * 0.8, -0.16, 0.0),
					Vector3(top_radius * 0.36, 0.06, top_radius * 2.4))


func _glow_bar(pos: Vector3, size: Vector3) -> void:
	var bar := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := Block3D.flat_material(beam_color)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = beam_color
	mat.emission_energy_multiplier = 2.0
	mesh.material = mat
	bar.mesh = mesh
	bar.position = pos
	add_child(bar)
