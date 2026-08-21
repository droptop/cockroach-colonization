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
@export var anchor_height := 3.4
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

var state := State.SUSPENDED

var _timer := 0.0
var _spit_timer := 0.0
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
	immune_to_damage = true # until the webs are cut
	# ON THE ENEMY LAYER, or no attack in the game can ever find her. The scene
	# had her on layer 0: an Area3D reports only what is on a layer it masks,
	# so every swing passed straight through and she could not be interacted
	# with at all once she was down. `immune_to_damage` is what protects her
	# while she hangs; being invisible to attacks was never the mechanism.
	# Same bug that shipped on the web anchors and the cat's paw.
	collision_layer = 4
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
	# Scuttling: a fast bob with a lean into the direction of travel.
	_visual.position.y = absf(sin(_hunt_time * 9.0)) * 0.12
	_visual.position.x = sin(_hunt_time * 4.5) * 0.05
	_visual.rotation.z = sin(_hunt_time * 9.0) * 0.06 - signf(to_him) * 0.12


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
	var eye_mat := Block3D.flat_material(Color(0.98, 0.86, 0.3))
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.98, 0.8, 0.25)
	eye_mat.emission_energy_multiplier = 1.6
	var pupil_mat := Block3D.flat_material(Color(0.06, 0.03, 0.05))
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
		var pupil := MeshInstance3D.new()
		var pupil_mesh := SphereMesh.new()
		pupil_mesh.radius = r * 0.45
		pupil_mesh.height = r * 0.8
		pupil_mesh.radial_segments = 6
		pupil_mesh.rings = 3
		pupil_mesh.material = pupil_mat
		pupil.mesh = pupil_mesh
		pupil.position = pos + Vector3(r * 0.7, 0, 0)
		root.add_child(pupil)
	# Long legs with a knee, so she towers over the ledge rather than sitting on
	# it like a beetle. Femur out and up, tibia down to a point.
	for i in 8:
		var side := -1.0 if i < 4 else 1.0
		var along := (i % 4) - 1.5
		var hip := Node3D.new()
		hip.position = Vector3(along * 0.42, 0.15, side * 0.55)
		hip.rotation = Vector3(side * 0.95, 0.0, along * 0.3)
		root.add_child(hip)

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
