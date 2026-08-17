class_name HintBubble3D

## Turns the bare Label3D hints into readable bubbles.
##
## The hints were plain Label3D nodes sitting at z=0.4, a few centimetres off
## the wall, with no backing and no wrapping. Two things went wrong with that:
##
##   1. Unwrapped, they ran the width of the level. "Fly up and cut the webs -
##      you can't reach HER until she falls!" is 61 characters at font size 60,
##      so it stretched right across the screen and past both edges.
##   2. With nothing behind them, the text sat directly on the wall texture and
##      read as part of the masonry rather than as a message to the player.
##
## This is a static styler rather than a scene: the 18 hints are already placed
## by hand across six levels, with positions and wording someone chose, and
## rewriting all six .tscn files to swap a node type would throw that away for
## no gain. `Level3D` calls `apply_to()` on each one at load instead.

## Label-space pixels before the text wraps. With font_size 44 this puts long
## hints onto two or three short lines instead of one enormous one.
const WRAP_PX := 460.0

## One size for every hint. They were 44-60 across the six levels, which made
## some shout and others whisper for no reason anyone had decided.
const FONT_SIZE := 44
const PIXEL_SIZE := 0.006

## Padding around the text, in world units.
const PAD_X := 0.34
const PAD_Y := 0.22

static var _panel_texture: ImageTexture


## Give one hint label a wrapped line length and a bubble behind it.
static func apply_to(label: Label3D) -> void:
	if label.get_node_or_null("Bubble") != null:
		return # already styled

	label.font_size = FONT_SIZE
	label.pixel_size = PIXEL_SIZE
	label.width = WRAP_PX
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	# Draw over the wall rather than fighting it for depth, and keep the text
	# crisp against whatever is behind the bubble.
	label.outline_size = 10
	label.outline_modulate = Color(0.03, 0.03, 0.05, 0.95)
	label.render_priority = 2
	label.outline_render_priority = 1

	var size := _bubble_size(label)
	var panel := MeshInstance3D.new()
	panel.name = "Bubble"
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = _panel_material()
	panel.mesh = quad
	# Just behind the glyphs, and centred on them: Label3D draws around its
	# own origin, so the bubble needs no offset beyond the depth nudge.
	panel.position = Vector3(0, 0, -0.012)
	label.add_child(panel)


## Rough, and deliberately so. Label3D will not report its laid-out size until
## it has drawn, and a hint that is slightly too roomy reads fine while one
## that clips its own text does not — so this errs large.
static func _bubble_size(label: Label3D) -> Vector2:
	var per_char := float(label.font_size) * label.pixel_size * 0.5
	var chars := float(label.text.length())
	var max_line := label.width * label.pixel_size
	var line_chars: float = maxf(1.0, max_line / maxf(per_char, 0.001))
	var lines: float = maxf(1.0, ceilf(chars / line_chars))
	var widest: float = minf(chars, line_chars) * per_char
	var line_height := float(label.font_size) * label.pixel_size * 1.35
	return Vector2(widest + PAD_X * 2.0, lines * line_height + PAD_Y * 2.0)


static func _panel_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _rounded_texture()
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 0
	return mat


## A rounded rectangle with a soft edge, generated once and shared. Same
## approach as every other texture in the project: built at load from code,
## so there is no image asset to ship or keep in sync.
static func _rounded_texture() -> ImageTexture:
	if _panel_texture != null:
		return _panel_texture
	var size := 64
	var radius := 14.0
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			# Distance outside the rounded-rect core, in pixels.
			var dx: float = maxf(0.0, absf(x + 0.5 - size * 0.5) - (size * 0.5 - radius))
			var dy: float = maxf(0.0, absf(y + 0.5 - size * 0.5) - (size * 0.5 - radius))
			var dist := sqrt(dx * dx + dy * dy)
			var alpha: float = clampf((radius - dist) / 2.0, 0.0, 1.0) * 0.84
			# A slight vertical lift so it reads as a bubble and not a slab.
			var lift := 0.055 * (1.0 - float(y) / float(size))
			img.set_pixel(x, y, Color(0.05 + lift, 0.055 + lift, 0.08 + lift, alpha))
	_panel_texture = ImageTexture.create_from_image(img)
	return _panel_texture
