@tool
class_name Block3D
extends StaticBody3D

## Chunky low-poly platform block: base box + slightly oversized top slab
## (the "lip" that gives the toy-diorama look from the art reference).
## Meshes and collision are built in code so levels stay tiny.

@export var size := Vector3(4.0, 2.0, 3.0):
	set(value):
		size = value
		_refresh()
@export var top_color := Color(0.45, 0.62, 0.4):
	set(value):
		top_color = value
		_refresh()
@export var base_color := Color(0.42, 0.34, 0.28):
	set(value):
		base_color = value
		_refresh()
@export var top_thickness := 0.4:
	set(value):
		top_thickness = value
		_refresh()
@export_enum("speckle", "grain", "checker", "brick", "asphalt", "concrete", "none") var texture_style := "speckle":
	set(value):
		texture_style = value
		_refresh()
@export var texture_density := 0.5:
	set(value):
		texture_density = value
		_refresh()

static var _tex_cache := {}

var _base: MeshInstance3D
var _top: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	_refresh()


static func flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	if color.a < 0.999: # ghostly things pass translucent colors
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


## Grayscale tileable texture, generated once and cached. The albedo color
## tints it, so one texture serves every surface color.
static func surface_texture(style: String) -> Texture2D:
	if not _tex_cache.has(style):
		_tex_cache[style] = _mipped(_style_image(style))
	return _tex_cache[style]


## These textures are generated at load, so nothing has built mipmaps for them
## the way the importer would. Tiled triplanar surfaces run to the back of the
## level, and without mips the far end shimmers — worst on the web build, which
## renders at 0.75 scale.
static func _mipped(img: Image) -> ImageTexture:
	if img.get_width() > 2: # the checker tile is meant to stay crisp
		img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Normal map derived from the same grayscale, so bumps match the pattern and
## surfaces catch the light with real relief.
static func normal_texture(style: String) -> Texture2D:
	var key := style + "::normal"
	if not _tex_cache.has(key):
		var img := _style_image(style)
		img.bump_map_to_normal_map(4.0)
		_tex_cache[key] = _mipped(img)
	return _tex_cache[key]


## Baked occlusion (cavity) map, derived from the same grayscale: the dark
## parts of a pattern ARE its recesses, so cracks, mortar lines and pits
## self-shadow for free instead of needing a light each. The Compatibility
## renderer applies AO to ambient, which is most of the light in these levels.
static func ao_texture(style: String) -> Texture2D:
	var key := style + "::ao"
	if not _tex_cache.has(key):
		var img := _style_image(style)
		var w := img.get_width()
		var h := img.get_height()
		for y in h:
			for x in w:
				# Lift the midtones so only genuine recesses darken — an AO map
				# that tracks albedo 1:1 just prints the pattern twice.
				var occ := clampf(0.42 + img.get_pixel(x, y).r * 0.72, 0.0, 1.0)
				img.set_pixel(x, y, Color(occ, occ, occ))
		_tex_cache[key] = _mipped(img)
	return _tex_cache[key]


static func _style_image(style: String) -> Image:
	match style:
		"asphalt":
			return _asphalt_image()
		"concrete":
			return _concrete_image()
		"checker":
			var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
			img.fill(Color(0.97, 0.97, 0.97))
			img.set_pixel(1, 0, Color(0.74, 0.74, 0.74))
			img.set_pixel(0, 1, Color(0.74, 0.74, 0.74))
			return img
		"brick":
			return _brick_image()
		_:
			return _speckle_image()


static func _speckle_image() -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = 1337
	noise.fractal_octaves = 4
	var src := noise.get_seamless_image(128, 128)
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var n := src.get_pixel(x, y).r
			# Bold two-tone blotches: dark patches in a 0.6..1.05 band.
			var v := 0.62 + n * 0.43
			if n < 0.35:
				v -= 0.14
			v = clampf(v, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	return img


## Rough road asphalt: a dark binder full of bright stone chips, cut by
## hairline cracks. The cracks come from the zero-crossing band of a
## low-frequency field, which meanders like real cracking instead of looking
## drawn on.
static func _asphalt_image() -> Image:
	var grit := FastNoiseLite.new()
	grit.seed = 4242
	grit.frequency = 0.34 # tight enough to read as aggregate, not blotches
	grit.fractal_octaves = 2
	var grit_src := grit.get_seamless_image(128, 128)
	var crack := FastNoiseLite.new()
	crack.seed = 51
	crack.frequency = 0.012
	crack.fractal_octaves = 2
	var crack_src := crack.get_seamless_image(128, 128)
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var g := grit_src.get_pixel(x, y).r
			var v := 0.58 + g * 0.28
			if g > 0.74:
				v += 0.17 # exposed chips of stone catching the light
			elif g < 0.3:
				v -= 0.1
			var c := absf(crack_src.get_pixel(x, y).r - 0.5)
			if c < 0.017:
				v -= 0.36 * (1.0 - c / 0.017)
			v = clampf(v, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	return img


## Worn concrete: broad damp/dry mottling, fine pitting, and the same
## meandering hairline cracks as asphalt but sparser and shallower.
static func _concrete_image() -> Image:
	var mottle := FastNoiseLite.new()
	mottle.seed = 808
	mottle.fractal_octaves = 3
	var mottle_src := mottle.get_seamless_image(128, 128)
	var pit := FastNoiseLite.new()
	pit.seed = 909
	pit.frequency = 0.42
	var pit_src := pit.get_seamless_image(128, 128)
	var crack := FastNoiseLite.new()
	crack.seed = 313
	crack.frequency = 0.019
	crack.fractal_octaves = 2
	var crack_src := crack.get_seamless_image(128, 128)
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var v := 0.72 + (mottle_src.get_pixel(x, y).r - 0.5) * 0.32
			var p := pit_src.get_pixel(x, y).r
			if p < 0.3:
				v -= 0.13 # blown air pockets in the pour
			var c := absf(crack_src.get_pixel(x, y).r - 0.5)
			if c < 0.011:
				v -= 0.28 * (1.0 - c / 0.011)
			v = clampf(v, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	return img


static func _brick_image() -> Image:
	const BRICK_H := 32
	const BRICK_W := 64
	const MORTAR := 4
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.fractal_octaves = 3
	var src := noise.get_seamless_image(128, 128)
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		var row := y / BRICK_H
		var offset := (row % 2) * (BRICK_W / 2)
		for x in 128:
			var bx := (x + offset) % BRICK_W
			var v: float
			if (y % BRICK_H) < MORTAR or bx < MORTAR:
				v = 0.52 + src.get_pixel(x, y).r * 0.06 # recessed mortar line
			else:
				var brick_id := row * 7 + (x + offset) / BRICK_W
				var tint := 0.78 + fposmod(brick_id * 0.37, 1.0) * 0.16
				v = tint + src.get_pixel(x, y).r * 0.14 - 0.07
			v = clampf(v, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	return img


## flat_material + a repeating triplanar surface texture with matching bumps.
static func textured_material(color: Color, style: String, density := 0.5) -> StandardMaterial3D:
	var mat := flat_material(color)
	if style == "none":
		return mat
	mat.albedo_texture = surface_texture(style)
	mat.uv1_triplanar = true
	match style:
		"speckle":
			mat.uv1_scale = Vector3.ONE * density
			mat.normal_scale = 0.5
		"grain":
			# Anisotropic stretch turns the noise into streaky wood grain.
			mat.uv1_scale = Vector3(density * 0.3, density * 2.4, density * 0.3)
			mat.normal_scale = 0.35
		"checker":
			# Ten times bigger tiles. At 0.7 the floor was a fine grid that read
			# as noise from the play camera and shimmered as it scrolled; real
			# kitchen tiles are big enough to count.
			mat.uv1_scale = Vector3.ONE * density * 0.07
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		"brick":
			mat.uv1_scale = Vector3.ONE * density
			mat.normal_scale = 1.1
		"asphalt":
			mat.uv1_scale = Vector3.ONE * density
			mat.normal_scale = 0.85
			mat.roughness = 0.86 # never bone-dry down a drain
		"concrete":
			mat.uv1_scale = Vector3.ONE * density
			mat.normal_scale = 0.6
			mat.roughness = 0.8
	if style != "checker":
		mat.normal_enabled = true
		mat.normal_texture = normal_texture(style)
		# Baked cavity shading, so cracks and pits stay readable in the flat
		# ambient light these levels run on (no shadow maps — see CLAUDE.md).
		mat.ao_enabled = true
		mat.ao_texture = ao_texture(style)
		mat.ao_light_affect = 0.3
	return mat


func _refresh() -> void:
	if not is_inside_tree():
		return
	if _base == null:
		_base = MeshInstance3D.new()
		_base.mesh = BoxMesh.new()
		add_child(_base)
		_top = MeshInstance3D.new()
		_top.mesh = BoxMesh.new()
		add_child(_top)
		_shape = CollisionShape3D.new()
		_shape.shape = BoxShape3D.new()
		add_child(_shape)
	var t := minf(top_thickness, size.y * 0.5)
	(_base.mesh as BoxMesh).size = Vector3(size.x, size.y - t, size.z)
	_base.position = Vector3(0, -t / 2.0, 0)
	(_base.mesh as BoxMesh).material = textured_material(base_color, texture_style, texture_density)
	(_top.mesh as BoxMesh).size = Vector3(size.x + 0.12, t, size.z + 0.12)
	_top.position = Vector3(0, (size.y - t) / 2.0, 0)
	(_top.mesh as BoxMesh).material = textured_material(top_color, texture_style, texture_density)
	(_shape.shape as BoxShape3D).size = size
