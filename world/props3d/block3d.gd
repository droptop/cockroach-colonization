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
@export_enum("speckle", "grain", "checker", "none") var texture_style := "speckle":
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
	if _tex_cache.has(style):
		return _tex_cache[style]
	var img: Image
	if style == "checker":
		img = Image.create(2, 2, false, Image.FORMAT_RGB8)
		img.fill(Color(0.98, 0.98, 0.98))
		img.set_pixel(1, 0, Color(0.8, 0.8, 0.8))
		img.set_pixel(0, 1, Color(0.8, 0.8, 0.8))
	else:
		var noise := FastNoiseLite.new()
		noise.seed = 1337
		noise.fractal_octaves = 3
		var src := noise.get_seamless_image(96, 96)
		img = Image.create(96, 96, false, Image.FORMAT_RGB8)
		for y in 96:
			for x in 96:
				# Remap full-range noise to a subtle 0.78..1.0 band.
				var v := 0.78 + src.get_pixel(x, y).r * 0.22
				img.set_pixel(x, y, Color(v, v, v))
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[style] = tex
	return tex


## flat_material + a repeating triplanar surface texture.
static func textured_material(color: Color, style: String, density := 0.5) -> StandardMaterial3D:
	var mat := flat_material(color)
	if style == "none":
		return mat
	mat.albedo_texture = surface_texture(style)
	mat.uv1_triplanar = true
	match style:
		"speckle":
			mat.uv1_scale = Vector3.ONE * density
		"grain":
			# Anisotropic stretch turns the noise into streaky wood grain.
			mat.uv1_scale = Vector3(density * 0.3, density * 2.4, density * 0.3)
		"checker":
			mat.uv1_scale = Vector3.ONE * density * 0.7
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
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
