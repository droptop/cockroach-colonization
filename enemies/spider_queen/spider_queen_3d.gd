class_name SpiderQueen3D
extends BaseBoss3D

## THE SPIDER QUEEN, hanging over the way out of the drain.
##
## Her verb is the environment. She cannot be touched while she is up in her
## webs — you have to cut the anchors holding her, and when the last one snaps
## she comes down for good and the fight proper begins. She keeps spitting from
## the floor, so being down is not the same as being beaten.
##
## Four bosses, four questions:
##   rat     — WHEN to hit (punish the recovery)
##   Granny  — don't be hit at all (patience, not health)
##   cat     — WHAT to hit (the paw, not the cat)
##   queen   — hit something ELSE first (the webs, not her)
##
## The anchors sit high enough to need the wing bar, so the drain's own flight
## lesson is what the fight asks you to use.

enum State { SUSPENDED, DROPPING, EXPOSED, RETREATING, GONE }

@export_group("Encounter")
@export var notice_range := 11.0
## Where she hangs, relative to her spawn.
@export var perch_height := 0.0
## How far she drops to land on the ledge.
@export var drop_distance := 4.6
## Once she is down she STAYS down. She used to climb back after a few seconds
## and re-spin the lot, so cutting three webs bought a four second window and
## then took it away again: the fight read as being undone rather than won.
## Cutting the webs is now the way IN to the fight, not the whole of it.

@export_group("Webs")
@export var anchor_count := 3
@export var anchor_spacing := 3.4
## Height above the ledge she lands on — comfortably past a standing jump, so
## reaching them means flying.
## How high above the arena floor the webs hang.
##
## Was 3.4, which put the anchors at y 10.8 over a ledge at 7.4 and a cut window
## of y 9.5 to 10.4: a 0.9 m band you had to HOVER in, since a jump tops out at
## 1.49 m (8.8^2 / 2g) and gets nowhere near. Six successful hits up there, three
## anchors at two health each, on the FIRST boss in the game, and the report was
## simply "can't cut spider queen webs".
##
## At 2.8 the window starts around 8.9, which is the top of an ordinary jump, so
## a jump plus a moment of flight reaches it and sustained hovering is a way to
## do it rather than the only way.
@export var anchor_height := 2.8
@export var anchor_health := 2

@export_group("Attacks")
## How fast she stalks him once she is down.
## Half her body height: how far her origin rides above the ledge.
@export var ground_clearance := 1.0
@export var ground_speed := 2.2
@export var spit_interval := 2.8
@export var telegraph_time := 1.05
@export var spit_radius := 1.5
@export var spit_damage := 1
@export var spit_duration := 3.5
## The GRAB (BACKLOG item 18): a web glob shot straight at him. On a hit he
## is wrapped on the spot — can't move, can't fly, can't swing — until it
## runs out or he wiggles free, and her brood closes in while he is held.
@export var web_shot_interval := 6.5
@export var web_wrap_seconds := 1.6
@export var web_shot_speed := 10.0

var state := State.SUSPENDED

var _timer := 0.0
var _spit_timer := 0.0
var _web_shot_timer := 3.0
var _leg_hips: Array[Node3D] = []
var _leg_base: Array[Vector3] = []
var _anchors: Array[WebAnchor3D] = []
var _target: Node3D
var _visual: Node3D
var _ground_y := 0.0
var _struggle_time := 0.0
var _hunt_time := 0.0
var _rest_y := 0.0
var _kick_timer := 2.0


func _ready() -> void:
	super()
	# The rule now teaches the FUEL as well as the target. The webs were
	# reported "not possible" from the live build a second time (2026-08-28),
	# and the web-build harness showed why: cutting one anchor costs ~23 wing
	# energy, venom hits cost 18, and nothing in the arena refilled the bar —
	# so the fight ran dry and an empty-winged player genuinely cannot reach
	# the webs. Crumbs respawn on the ledge now, and the rule says to eat.
	boss_rule = "Nothing touches her till the WEBS are cut. Eat crumbs to refly!"
	immune_to_damage = true # until the webs are cut
	# ON THE ENEMY LAYER, or no attack in the game can ever find her. The scene
	# had her on layer 0: an Area3D reports only what is on a layer it masks,
	# so every swing passed straight through and she could not be interacted
	# with at all once she was down. `immune_to_damage` is what protects her
	# while she hangs; being invisible to attacks was never the mechanism.
	# Same bug that shipped on the web anchors and the cat's paw.
	collision_layer = 4
	# Her adds are HER OWN: baby spiders, small and one-bite fragile, two per
	# wave rather than the default three - this is a positional fight and a
	# crowd would drown the thing it teaches.
	summon_scene = "res://enemies/spider/spider_3d.tscn"
	summon_visual_scale = 0.55
	summon_count = 2
	_ground_y = global_position.y - drop_distance
	# Where her ORIGIN sits when she is down. _ground_y is the FLOOR, and her
	# body is two metres tall around its origin, so pinning the origin to the
	# floor buried her to the waist in the ledge.
	_rest_y = _ground_y + ground_clearance
	_visual = _build_queen()
	add_child(_visual)
	# Deferred: a child's _ready runs BEFORE its parent's, so the level is still
	# setting itself up and will refuse siblings added right now.
	_spin_webs.call_deferred()


func _physics_process(delta: float) -> void:
	if state == State.GONE:
		return
	_timer -= delta
	match state:
		State.SUSPENDED:
			_struggle(delta)
			if not _engaged_check():
				return
			_spit_timer -= delta
			if _spit_timer <= 0.0:
				_spit_timer = spit_interval
				_spit()
			_web_shot_timer -= delta
			if _web_shot_timer <= 0.0:
				_web_shot_timer = web_shot_interval
				_shoot_web()
		State.EXPOSED:
			# Down, vulnerable, and still fighting. She was a statue here:
			# no movement and no animation, so the moment you earned read as
			# the fight breaking rather than starting.
			if not _acquire_target():
				return
			_ground_hunt(delta)
			_spit_timer -= delta
			if _spit_timer <= 0.0:
				_spit_timer = spit_interval
				_spit()
			_web_shot_timer -= delta
			if _web_shot_timer <= 0.0:
				_web_shot_timer = web_shot_interval
				_shoot_web()
		State.RETREATING:
			if _timer <= 0.0:
				state = State.GONE


## Hanging is not the same as resting. She works against the silk the whole
## time she is up there, and works HARDER as it goes: with every anchor cut the
## sway widens and the twitching quickens, so how close you are to bringing her
## down is legible from her body rather than only from a number.
func _struggle(delta: float) -> void:
	_struggle_time += delta
	var cut := float(anchor_count - _anchors.size())
	var strain: float = 1.0 + cut * 0.9
	var t: float = _struggle_time * (1.5 + cut * 0.85)
	_visual.position.y = sin(t) * 0.16 * strain
	_visual.position.x = sin(t * 0.63) * 0.1 * strain
	_visual.rotation.z = sin(t * 0.81) * 0.09 * strain
	# The legs work the air, each on its own beat, harder as the silk fails.
	_animate_legs(t * 2.4, 0.22 * strain, 0.12)
	# Sharp kicks on top of the sway, more often the fewer threads are left.
	_kick_timer -= delta
	if _kick_timer <= 0.0:
		_kick_timer = randf_range(1.6, 3.2) / strain
		var kick := create_tween()
		kick.tween_property(_visual, "rotation:z",
			randf_range(-0.22, 0.22) * strain, 0.08)
		kick.tween_property(_visual, "rotation:z", 0.0, 0.22)


func _engaged_check() -> bool:
	if not _acquire_target():
		return false
	if absf(_target.global_position.x - global_position.x) > notice_range:
		return false
	engage()
	return true


## Re-spins whatever she lost. Cutting them is the entire way in, so they have
## to come back or the fight ends after one exposure.
func _spin_webs() -> void:
	_anchors.clear()
	var first := -(anchor_count - 1) * 0.5
	for i in anchor_count:
		var anchor := WebAnchor3D.new()
		anchor.max_health = anchor_health
		anchor.ceiling_y = global_position.y + 1.5
		get_parent().add_child(anchor)
		anchor.global_position = Vector3(
			global_position.x + (first + i) * anchor_spacing,
			_ground_y + anchor_height, 0.0)
		anchor.destroyed.connect(_on_anchor_destroyed.bind(anchor))
		_anchors.append(anchor)


func _on_anchor_destroyed(anchor: WebAnchor3D) -> void:
	_anchors.erase(anchor)
	engage()
	if _anchors.is_empty() and state == State.SUSPENDED:
		_drop()
	elif is_instance_valid(_visual):
		# Lurches as her rigging goes, so progress is legible before she falls.
		var tween := create_tween()
		tween.tween_property(_visual, "rotation:z", randf_range(-0.3, 0.3), 0.15)
		tween.tween_property(_visual, "rotation:z", 0.0, 0.3)


func _drop() -> void:
	state = State.DROPPING
	Snd.sfx("queen_drop", -2.0)
	var tween := create_tween()
	tween.tween_property(self, "global_position:y", _rest_y, 0.42
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func() -> void:
		if state == State.GONE or is_defeated:
			return
		state = State.EXPOSED
		# The fight proper starts here, and does not close again.
		immune_to_damage = false
		Snd.sfx("impact_heavy", 2.0)
		Fx.spark_burst(get_parent(), global_position, Color(0.9, 0.9, 1.0))
		Fx.impact_text(get_parent(), global_position + Vector3(0, 1.2, 0),
			Color(1.0, 0.85, 0.4), "SHE'S DOWN! GET HER!", 0.9)
		_shake(0.5))


## Stalking him along the ledge. She has no collision mask, so gravity and
## move_and_slide would do nothing: her Y is pinned to the ledge she landed on
## and only X is driven. Kept inside the arena so she cannot walk out of her
## own fight.
func _ground_hunt(delta: float) -> void:
	var bounds := arena_bounds()
	var to_him := _target.global_position.x - global_position.x
	var step := signf(to_him) * ground_speed * delta
	# Stops just short, so she crowds him instead of standing inside him.
	if absf(to_him) > 1.1:
		global_position.x = clampf(global_position.x + step,
			bounds.x + 0.6, bounds.y - 0.6)
	global_position.y = _rest_y
	_hunt_time += delta
	if not is_instance_valid(_visual):
		return
	# Scuttling: a fast bob with a lean into the direction of travel, and the
	# legs actually carrying her — alternate sets swing out of phase, the way
	# a real spider's gait pairs them.
	_visual.position.y = absf(sin(_hunt_time * 9.0)) * 0.12
	_visual.position.x = sin(_hunt_time * 4.5) * 0.05
	_visual.rotation.z = sin(_hunt_time * 9.0) * 0.06 - signf(to_him) * 0.12
	_animate_legs(_hunt_time * 9.0, 0.16, 0.3)


## One driver for both moods. `swing` moves the hip fore-and-aft (the gait),
## `lift` kicks it up and down (the struggle); neighbouring legs run half a
## cycle apart so it never reads as an oar stroke.
func _animate_legs(t: float, lift: float, swing: float) -> void:
	for i in _leg_hips.size():
		var hip := _leg_hips[i]
		if not is_instance_valid(hip):
			continue
		var phase: float = t + i * (PI * 0.5) + (PI if i % 2 == 0 else 0.0)
		hip.rotation.x = _leg_base[i].x + sin(phase) * lift
		hip.rotation.z = _leg_base[i].z + cos(phase) * swing


## Venom, spat down at wherever he is. Marked first, and the mark is the same
## radius as the pool that lands in it.
func _spit() -> void:
	if not is_instance_valid(_target):
		return
	var aim := Vector3(_target.global_position.x, _ground_y, 0.0)
	var marker := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = spit_radius
	disc.bottom_radius = spit_radius
	disc.height = 0.03
	disc.radial_segments = 18
	var mat := Block3D.flat_material(Color(0.6, 0.95, 0.4, 0.3))
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.95, 0.4)
	mat.emission_energy_multiplier = 0.9
	disc.material = mat
	marker.mesh = disc
	get_parent().add_child(marker)
	marker.global_position = aim + Vector3(0, 0.05, 0)
	marker.scale = Vector3(0.15, 1.0, 0.15)
	var grow := marker.create_tween()
	grow.tween_property(marker, "scale", Vector3.ONE, telegraph_time)
	await get_tree().create_timer(telegraph_time).timeout
	if not is_instance_valid(marker):
		return
	marker.queue_free()
	if state == State.GONE or is_defeated:
		return
	var venom := HazardPool3D.new()
	venom.damage = spit_damage
	venom.tick_interval = 0.6
	venom.lifetime = spit_duration
	venom.start_radius = spit_radius
	venom.max_radius = spit_radius
	venom.growth_per_feed = 0.0
	venom.pool_height = 0.22
	venom.color = Color(0.55, 0.95, 0.4)
	venom.damage_cause = "poison"
	get_parent().add_child(venom)
	venom.global_position = aim
	Snd.sfx("sizzle", -4.0)


## The grab. A silk glob straight at where he IS — no telegraph mark like the
## venom, but it is slow enough to dodge on reflex, and reflect-verb weapons
## can bat it back into her brood. On a hit, `Projectile3D` calls his
## `web_wrap` and he is held for her babies to reach.
func _shoot_web() -> void:
	if not is_instance_valid(_target):
		return
	if _target.has_method("is_wrapped") and _target.is_wrapped():
		return # one wrap at a time; stacking them is a stun-lock, not a fight
	var glob := Projectile3D.new()
	glob.damage = 0
	glob.wrap_seconds = web_wrap_seconds
	glob.speed = web_shot_speed
	glob.fall_rate = 1.5
	glob.lifetime = 1.4
	glob.spin = 6.0
	glob.damage_cause = "web"
	# The PLAYER only, not the world: the arena walkway pipe hangs between her
	# mouth and the entire ledge, and with world collision every glob died on
	# it as "scenery" — she could not land a single grab. Silk drifting past a
	# pipe reads fine; the short lifetime keeps a miss from sailing through
	# floors forever.
	glob.hits = 2
	var ball := Node3D.new()
	var silk := Block3D.flat_material(Color(0.9, 0.92, 0.96, 0.9))
	silk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	silk.emission_enabled = true
	silk.emission = Color(0.8, 0.85, 0.95)
	silk.emission_energy_multiplier = 0.5
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.22
	core_mesh.height = 0.4
	core_mesh.radial_segments = 7
	core_mesh.rings = 4
	core_mesh.material = silk
	core.mesh = core_mesh
	ball.add_child(core)
	# Loose trailing strands, so it reads as silk and not as a snowball.
	for i in 3:
		var strand := MeshInstance3D.new()
		var strand_mesh := CylinderMesh.new()
		strand_mesh.top_radius = 0.02
		strand_mesh.bottom_radius = 0.005
		strand_mesh.height = 0.5
		strand_mesh.radial_segments = 4
		strand_mesh.material = silk
		strand.mesh = strand_mesh
		strand.position = Vector3(-0.25, 0.1 - i * 0.1, 0)
		strand.rotation.z = 1.2 + i * 0.3
		ball.add_child(strand)
	glob.set_visual(ball)
	get_parent().add_child(glob)
	var mouth := global_position + Vector3(0.9, -0.2, 0)
	var toward := (_target.global_position + Vector3(0, 0.4, 0) - mouth).normalized()
	glob.launch(mouth, toward)
	Snd.sfx("whoosh", -4.0, 0.2)


func _shake(strength: float) -> void:
	if not is_instance_valid(_target):
		return
	var cam := _target.get_node_or_null("Camera3D")
	if cam and cam.has_method("shake"):
		cam.shake(strength)


func _acquire_target() -> bool:
	if not is_instance_valid(_target):
		_target = null
		for node in get_tree().get_nodes_in_group("player"):
			_target = node
			break
	return _target != null


func _on_damage_shrugged(_amount: int, _from_position: Vector3) -> void:
	Fx.impact_text(get_parent(), global_position + Vector3(0, 1.0, 0),
		Color(0.85, 0.9, 1.0), "CUT THE WEBS!", 0.7)


func _on_damaged(_amount: int, _from_position: Vector3) -> void:
	Fx.hit_flash(_visual, Color(1.0, 0.8, 0.85))
	Snd.sfx("queen_hurt", -3.0)


func _on_defeated() -> void:
	state = State.RETREATING
	_timer = 1.6
	immune_to_damage = true
	for anchor in _anchors:
		if is_instance_valid(anchor):
			anchor.queue_free()
	_anchors.clear()
	Snd.sfx("queen_death", 5.0)
	Fx.ghost(get_parent(), global_position, 1.6, 8)
	var tween := create_tween()
	tween.tween_property(_visual, "rotation:z", PI, 0.5)
	tween.tween_property(self, "global_position:y", _ground_y - 6.0, 1.1
		).set_ease(Tween.EASE_IN)


## Bulbous abdomen, small head, eight legs and too many eyes.
func _build_queen() -> Node3D:
	var root := Node3D.new()
	var chitin := Block3D.textured_material(Color(0.22, 0.18, 0.26), "speckle", 2.0)
	var abdomen := MeshInstance3D.new()
	var abdomen_mesh := SphereMesh.new()
	abdomen_mesh.radius = 1.25
	abdomen_mesh.height = 2.2
	abdomen_mesh.material = chitin
	abdomen.mesh = abdomen_mesh
	abdomen.position = Vector3(-0.55, 0.1, 0)
	root.add_child(abdomen)
	# Hourglass marking, so she reads as venomous at a glance.
	var mark := MeshInstance3D.new()
	var mark_mesh := SphereMesh.new()
	mark_mesh.radius = 0.32
	mark_mesh.height = 0.7
	var mark_mat := Block3D.flat_material(Color(0.85, 0.2, 0.25))
	mark_mat.emission_enabled = true
	mark_mat.emission = Color(0.85, 0.2, 0.25)
	mark_mat.emission_energy_multiplier = 0.7
	mark_mesh.material = mark_mat
	mark.mesh = mark_mesh
	mark.scale = Vector3(0.5, 1.0, 0.4)
	mark.position = Vector3(-0.55, 0.1, 1.05)
	root.add_child(mark)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.62
	head_mesh.height = 1.05
	head_mesh.material = chitin
	head.mesh = head_mesh
	head.position = Vector3(0.85, -0.1, 0)
	root.add_child(head)
	# Eight eyes in two rows, big enough to catch the light and read as a face
	# from across the arena. Four small ones did not survive the distance.
	# Dark, wet and glossy with a bright catchlight, rather than glowing yellow
	# marbles. Emissive spheres with black dots on the front read as buttons
	# stuck on her face: eyes are dark, and what sells them is the highlight.
	var eye_mat := Block3D.flat_material(Color(0.07, 0.05, 0.09))
	eye_mat.roughness = 0.15
	eye_mat.metallic = 0.25
	var pupil_mat := Block3D.flat_material(Color(1.0, 0.95, 0.85))
	pupil_mat.emission_enabled = true
	pupil_mat.emission = Color(1.0, 0.9, 0.7)
	pupil_mat.emission_energy_multiplier = 1.3
	# A red rim behind the cluster, so the face still reads at arena distance.
	var rim_mat := Block3D.flat_material(Color(0.7, 0.12, 0.16))
	rim_mat.emission_enabled = true
	rim_mat.emission = Color(0.8, 0.15, 0.18)
	rim_mat.emission_energy_multiplier = 0.9
	const EYES := [
		[Vector3(1.2, 0.26, -0.3), 0.2], [Vector3(1.2, 0.26, 0.3), 0.2],
		[Vector3(1.26, 0.2, -0.03), 0.16], [Vector3(1.26, 0.2, 0.03), 0.16],
		[Vector3(1.1, -0.12, -0.4), 0.13], [Vector3(1.1, -0.12, 0.4), 0.13],
		[Vector3(1.18, -0.16, -0.16), 0.11], [Vector3(1.18, -0.16, 0.16), 0.11],
	]
	for spec in EYES:
		var pos: Vector3 = spec[0]
		var r: float = spec[1]
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = r
		eye_mesh.height = r * 1.8
		eye_mesh.radial_segments = 8
		eye_mesh.rings = 4
		eye_mesh.material = eye_mat
		eye.mesh = eye_mesh
		eye.position = pos
		root.add_child(eye)
		# The catchlight: small, offset up and forward, which is the whole
		# trick for making a dark sphere look like a wet eye.
		var glint := MeshInstance3D.new()
		var glint_mesh := SphereMesh.new()
		glint_mesh.radius = r * 0.3
		glint_mesh.height = r * 0.55
		glint_mesh.radial_segments = 5
		glint_mesh.rings = 3
		glint_mesh.material = pupil_mat
		glint.mesh = glint_mesh
		glint.position = pos + Vector3(r * 0.72, r * 0.34, -r * 0.2)
		root.add_child(glint)
		# A thin red ring around the two big ones only.
		if r > 0.18:
			var rim := MeshInstance3D.new()
			var rim_mesh := TorusMesh.new()
			rim_mesh.inner_radius = r * 1.05
			rim_mesh.outer_radius = r * 1.35
			rim_mesh.rings = 10
			rim_mesh.ring_segments = 5
			rim_mesh.material = rim_mat
			rim.mesh = rim_mesh
			rim.rotation.z = PI / 2.0
			rim.position = pos + Vector3(-r * 0.15, 0, 0)
			root.add_child(rim)
	# THE CROWN. Taken off the rat: she is the one called a Queen, and he was
	# only wearing it because he was the first boss built.
	var gold := Block3D.flat_material(Color(0.95, 0.78, 0.25))
	gold.metallic = 0.6
	gold.roughness = 0.35
	gold.emission_enabled = true
	gold.emission = Color(0.9, 0.7, 0.2)
	gold.emission_energy_multiplier = 0.4
	var band := MeshInstance3D.new()
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.42
	band_mesh.bottom_radius = 0.46
	band_mesh.height = 0.22
	band_mesh.radial_segments = 10
	band_mesh.material = gold
	band.mesh = band_mesh
	band.position = Vector3(0.72, 0.62, 0)
	band.rotation.z = -0.16
	root.add_child(band)
	for k in 5:
		var spike := MeshInstance3D.new()
		var spike_mesh := CylinderMesh.new()
		spike_mesh.top_radius = 0.0
		spike_mesh.bottom_radius = 0.09
		spike_mesh.height = 0.26
		spike_mesh.radial_segments = 5
		spike_mesh.material = gold
		spike.mesh = spike_mesh
		var a: float = TAU * k / 5.0
		spike.position = Vector3(0.72 + cos(a) * 0.34, 0.82, sin(a) * 0.34)
		spike.rotation.z = -0.16
		root.add_child(spike)
	var jewel_mat := Block3D.flat_material(Color(0.85, 0.15, 0.2))
	jewel_mat.emission_enabled = true
	jewel_mat.emission = Color(0.85, 0.15, 0.2)
	jewel_mat.emission_energy_multiplier = 0.9
	var jewel := MeshInstance3D.new()
	var jewel_mesh := SphereMesh.new()
	jewel_mesh.radius = 0.11
	jewel_mesh.height = 0.2
	jewel_mesh.radial_segments = 7
	jewel_mesh.rings = 4
	jewel_mesh.material = jewel_mat
	jewel.mesh = jewel_mesh
	jewel.position = Vector3(1.02, 0.66, 0)
	root.add_child(jewel)

	# Long legs with a knee, so she towers over the ledge rather than sitting on
	# it like a beetle. Femur out and up, tibia down to a point. The hips are
	# PIVOTS and they are kept: the legs kick against the silk while she hangs
	# and scuttle while she hunts, instead of hanging stiff as antlers.
	for i in 8:
		var side := -1.0 if i < 4 else 1.0
		var along := (i % 4) - 1.5
		var hip := Node3D.new()
		hip.position = Vector3(along * 0.42, 0.15, side * 0.55)
		hip.rotation = Vector3(side * 0.95, 0.0, along * 0.3)
		root.add_child(hip)
		_leg_hips.append(hip)
		_leg_base.append(hip.rotation)

		var femur := MeshInstance3D.new()
		var femur_mesh := CylinderMesh.new()
		femur_mesh.top_radius = 0.07
		femur_mesh.bottom_radius = 0.11
		femur_mesh.height = 1.5
		femur_mesh.radial_segments = 5
		femur_mesh.material = chitin
		femur.mesh = femur_mesh
		femur.position = Vector3(0, -0.75, 0)
		hip.add_child(femur)

		var knee := Node3D.new()
		knee.position = Vector3(0, -1.5, 0)
		knee.rotation.z = -0.85
		hip.add_child(knee)

		var tibia := MeshInstance3D.new()
		var tibia_mesh := CylinderMesh.new()
		tibia_mesh.top_radius = 0.065
		tibia_mesh.bottom_radius = 0.012
		tibia_mesh.height = 1.75
		tibia_mesh.radial_segments = 5
		tibia_mesh.material = chitin
		tibia.mesh = tibia_mesh
		tibia.position = Vector3(0, -0.875, 0)
		knee.add_child(tibia)
	return root
