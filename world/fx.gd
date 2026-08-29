class_name Fx
extends Object

## Shared one-shot combat/juice effects: comic impact text, spark bursts,
## floating death ghosts. All spawn, animate, and free themselves.

const IMPACT_WORDS := ["POW!", "CRACK!", "BONK!", "SPLAT!", "WHAM!"]

## How hard a hit landed. The player has to be able to tell these apart at a
## glance — that is the whole point of the tiers, so each one gets its own word
## list, colour and size rather than a shared word in a different tint.
enum Tier { BLOCKED, WEAK, NORMAL, HEAVY }

const TIER_STYLE := {
	Tier.BLOCKED: {
		"words": ["CLANG!", "TING!", "BLOCKED!"],
		"color": Color(0.65, 0.85, 1.0), "scale": 0.8, "sparks": Color(0.7, 0.9, 1.0),
	},
	Tier.WEAK: {
		"words": ["tap!", "nip!", "bonk"],
		"color": Color(0.85, 0.85, 0.8), "scale": 0.62, "sparks": Color(0.9, 0.9, 0.7),
	},
	Tier.NORMAL: {
		"words": IMPACT_WORDS,
		"color": Color(1.0, 0.9, 0.3), "scale": 1.0, "sparks": Color(1.0, 0.95, 0.6),
	},
	Tier.HEAVY: {
		"words": ["CRUNCH!", "WHAM!", "SMASH!"],
		"color": Color(1.0, 0.55, 0.2), "scale": 1.35, "sparks": Color(1.0, 0.7, 0.35),
	},
}


## Pick a tier from raw damage. Blocked always wins — the player needs to know
## their shield did something more than they need to know the number.
static func tier_for(amount: int, blocked := false) -> Tier:
	if blocked:
		return Tier.BLOCKED
	if amount <= 1:
		return Tier.WEAK
	return Tier.NORMAL if amount == 2 else Tier.HEAVY


## What Harry says when it happens to HIM (blue-on-yellow, comic-panel
## style), and what a BOSS hit sounds like (the big red WHAMs).
const OUCH_WORDS := ["OUCH!", "OOF!", "YEOW!", "ACK!"]
const WHAM_WORDS := ["WHAM!", "POW!", "BAM!", "KRAK!"]


## The full hit confirmation: word, sparks, and (for real damage) a flash over
## the thing that got hit. One call so no site can do half of it. Real hits
## get the comic STARBURST behind the word; weak taps and blocks stay plain —
## a starburst on "tap!" is noise.
static func impact(parent: Node, pos: Vector3, amount: int, blocked := false,
		visual: Node3D = null) -> void:
	var tier := tier_for(amount, blocked)
	var style: Dictionary = TIER_STYLE[tier]
	var words: Array = style.words
	if tier == Tier.NORMAL or tier == Tier.HEAVY:
		comic_burst(parent, pos, words[randi() % words.size()], style.color,
			Color(1.0, 0.85, 0.25), style.scale)
	else:
		impact_text(parent, pos, style.color, words[randi() % words.size()], style.scale)
	spark_burst(parent, pos + Vector3(0, 0.4, 0), style.sparks)
	if visual:
		hit_flash(visual, Color(0.75, 0.9, 1.0) if blocked else Color(1.0, 0.8, 0.75))


## Harry took one: his own comic panel, at his own position.
static func ouch(parent: Node, pos: Vector3) -> void:
	comic_burst(parent, pos + Vector3(0, 0.4, 0),
		OUCH_WORDS[randi() % OUCH_WORDS.size()],
		Color(0.35, 0.75, 1.0), Color(1.0, 0.85, 0.25), 1.0)


## A boss took one: the big WHAM, scaled by how hard the blow was.
static func wham(parent: Node, pos: Vector3, amount: int) -> void:
	comic_burst(parent, pos + Vector3(0, 0.9, 0),
		WHAM_WORDS[randi() % WHAM_WORDS.size()],
		Color(1.0, 0.9, 0.25), Color(0.95, 0.25, 0.15), 1.5 + float(amount) * 0.18)


## The comic-book splat: a two-layer STARBURST (dark rim star behind a hot
## fill star) with the word popped over it. All procedural — a triangle fan
## with alternating radii on a billboard material, no textures anywhere, same
## as everything else this game draws.
static func comic_burst(parent: Node, pos: Vector3, word: String,
		text_color: Color, fill_color: Color, size_scale := 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos + Vector3(randf_range(-0.15, 0.15), 0.55, 0.55)

	# 30% see-through (user's call): the moment matters, but so does whatever
	# is swinging at you behind it.
	var rim := fill_color.darkened(0.65)
	rim.a = 0.7
	var fill := fill_color
	fill.a = 0.7
	root.add_child(_star_mesh(1.16 * size_scale, 11, rim, -0.02))
	root.add_child(_star_mesh(1.0 * size_scale, 11, fill, 0.0))

	var label := Label3D.new()
	label.text = word
	label.font = load("res://ui/fonts/IronDiceGrit-Black.ttf")
	label.font_size = int(110 * size_scale)
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(text_color.r, text_color.g, text_color.b, 0.75)
	label.outline_size = 26
	label.no_depth_test = true
	label.position = Vector3(0, 0, 0.03)
	root.add_child(label)

	root.scale = Vector3.ONE * 0.2
	root.rotation.z = randf_range(-0.14, 0.14)
	var tween := root.create_tween()
	tween.tween_property(root, "scale", Vector3.ONE * 1.2, 0.1
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "scale", Vector3.ONE, 0.07)
	tween.tween_interval(0.24)
	tween.tween_property(root, "scale", Vector3.ONE * 0.05, 0.16
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(root, "position:y", root.position.y + 0.5, 0.16)
	tween.tween_callback(root.queue_free)


## One star layer: a fan of triangles alternating between two radii, on an
## unshaded billboard material so it always faces the camera flat, like ink.
static func _star_mesh(radius: float, points: int, color: Color,
		z_offset: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := radius * 0.52
	for i in points:
		var a0 := TAU * float(i) / float(points)
		var a1 := TAU * (float(i) + 0.5) / float(points)
		var a2 := TAU * (float(i) + 1.0) / float(points)
		# Ragged, like a hand-drawn splat: every spike its own length.
		var spike := radius * (0.85 + 0.3 * absf(sin(float(i) * 2.7)))
		st.add_vertex(Vector3(cos(a0) * inner, sin(a0) * inner, 0))
		st.add_vertex(Vector3(cos(a1) * spike, sin(a1) * spike, 0))
		st.add_vertex(Vector3(cos(a2) * inner, sin(a2) * inner, 0))
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a0) * inner, sin(a0) * inner, 0))
		st.add_vertex(Vector3(cos(a2) * inner, sin(a2) * inner, 0))
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position.z = z_offset
	return inst


## White-hot overlay laid over every mesh in a creature's visual for a beat.
## Uses material_overlay rather than poking albedo, so it cannot corrupt
## whatever the creature's real materials are — and one overlay material serves
## every mesh in the burst.
static func hit_flash(visual: Node3D, color := Color(1.0, 0.8, 0.75), hold := 0.13) -> void:
	if visual == null or not visual.is_inside_tree():
		return
	var overlay := StandardMaterial3D.new()
	overlay.albedo_color = color
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(visual, meshes)
	if meshes.is_empty():
		return
	for m in meshes:
		m.material_overlay = overlay
	var tween := visual.create_tween()
	tween.tween_property(overlay, "albedo_color:a", 0.0, hold)
	tween.tween_callback(func() -> void:
		for m in meshes:
			if is_instance_valid(m):
				m.material_overlay = null)


## Hit-stop: freeze everything for a few frames on a confirmed hit. The whole
## trick is that it must be SHORT — long enough to read as impact, short enough
## that it never feels like a stutter.
##
## The timer ignores time_scale, so the unfreeze fires even though the world is
## stopped; without that flag setting time_scale to 0 would lock the game.
static var _stopping := false

static func hit_stop(tree: SceneTree, duration := 0.05) -> void:
	if tree == null or _stopping:
		return
	_stopping = true
	Engine.time_scale = 0.0
	await tree.create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_stopping = false


static func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	# A MeshInstance3D with no mesh has nothing to show and nothing to throw.
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, out)


static func impact_text(parent: Node, pos: Vector3, color := Color(1.0, 0.9, 0.3),
		word := "", size_scale := 1.0) -> void:
	var label := Label3D.new()
	label.text = word if word != "" else IMPACT_WORDS[randi() % IMPACT_WORDS.size()]
	label.font_size = int(96 * size_scale)
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.outline_size = 22
	label.no_depth_test = true
	parent.add_child(label)
	label.global_position = pos + Vector3(randf_range(-0.2, 0.2), 0.5, 0.5)
	label.scale = Vector3.ONE * 0.2
	label.rotation.z = randf_range(-0.18, 0.18)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE * 1.25, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3.ONE, 0.06)
	tween.tween_interval(0.18)
	tween.tween_property(label, "modulate:a", 0.0, 0.22)
	tween.parallel().tween_property(label, "position:y", label.position.y + 0.7, 0.22)
	tween.tween_callback(label.queue_free)


static func spark_burst(parent: Node, pos: Vector3, color := Color(1.0, 0.95, 0.6)) -> void:
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 10
	sparks.lifetime = 0.35
	sparks.spread = 180.0
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 4.5
	sparks.gravity = Vector3(0, -8, 0)
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.045
	mesh.height = 0.09
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mesh.material = mat
	sparks.mesh = mesh
	parent.add_child(sparks)
	sparks.global_position = pos
	sparks.emitting = true
	var tween := sparks.create_tween()
	tween.tween_interval(0.8)
	tween.tween_callback(sparks.queue_free)


## Little white spirit that twirls up out of a defeated creature and fades.
## `legs` adds drooping wisps, so a spider's ghost reads as a spider's rather
## than as the same blob every creature leaves behind.
## Break a thing into its own pieces and throw them.
##
## Death was a squash-and-skew of the whole body, which reads as the model being
## stepped on rather than as the creature coming apart. This takes the actual
## meshes it was built from, hands each one to the level as a free object, and
## scatters them: what falls is recognisably the legs and the abdomen of the
## thing you just hit.
##
## Copies rather than reparenting, because the corpse is about to free itself
## and would take the pieces with it.
static func shatter(parent: Node, source: Node3D, force := 5.0) -> void:
	if parent == null or source == null or not parent.is_inside_tree():
		return
	var pieces: Array[MeshInstance3D] = []
	_collect_meshes(source, pieces)
	# The original goes as its pieces leave, or the corpse and its own parts
	# are on screen at the same time and it reads as a duplication glitch.
	source.visible = false
	var n := 0
	for original in pieces:
		# A cap, because a boss is built from dozens of parts and every one of
		# them is a draw call while it is in the air.
		if n >= 14:
			break
		n += 1
		var piece := MeshInstance3D.new()
		piece.mesh = original.mesh
		piece.material_override = original.material_override
		parent.add_child(piece)
		piece.global_transform = original.global_transform
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.4, 1.0),
			randf_range(-0.3, 0.3)).normalized()
		var land := piece.global_position + dir * force * randf_range(0.4, 1.0) \
			- Vector3(0, force * 0.55, 0)
		var spin := Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0),
			randf_range(-6.0, 6.0))
		var tween := piece.create_tween()
		tween.set_parallel(true)
		tween.tween_property(piece, "global_position", land, 0.75
			).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(piece, "rotation",
			piece.rotation + spin, 0.75)
		tween.tween_property(piece, "scale", Vector3.ONE * 0.05, 0.75
			).set_delay(0.35)
		tween.chain().tween_callback(piece.queue_free)



static func ghost(parent: Node, pos: Vector3, size := 1.0, legs := 0) -> void:
	var spirit := Node3D.new()
	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.28 * size
	body_mesh.height = 0.62 * size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.95, 1.0)
	mat.emission_energy_multiplier = 0.6
	body_mesh.material = mat
	body.mesh = body_mesh
	spirit.add_child(body)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.05, 0.05, 0.1, 0.85)
	eye_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.05 * size
		eye_mesh.height = 0.12 * size
		eye_mesh.material = eye_mat
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.09 * size, 0.08 * size, 0.22 * size)
		spirit.add_child(eye)
	for i in legs:
		var leg := MeshInstance3D.new()
		var leg_mesh := CylinderMesh.new()
		leg_mesh.top_radius = 0.02 * size
		leg_mesh.bottom_radius = 0.035 * size
		leg_mesh.height = 0.42 * size
		leg_mesh.radial_segments = 4
		leg_mesh.material = mat
		leg.mesh = leg_mesh
		var angle := TAU * i / float(legs)
		leg.position = Vector3(cos(angle) * 0.22 * size, -0.16 * size, sin(angle) * 0.22 * size)
		leg.rotation = Vector3(cos(angle) * 0.7, 0.0, -sin(angle) * 0.7)
		spirit.add_child(leg)
	parent.add_child(spirit)
	spirit.global_position = pos + Vector3(0, 0.2, 0)
	var tween := spirit.create_tween()
	tween.tween_property(spirit, "position:y", spirit.position.y + 2.4, 1.3).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(spirit, "rotation:y", TAU * 1.5, 1.3)
	tween.parallel().tween_property(spirit, "scale", Vector3.ONE * 0.1, 1.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(spirit.queue_free)
