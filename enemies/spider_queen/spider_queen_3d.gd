class_name SpiderQueen3D
extends BaseBoss3D

## THE SPIDER QUEEN, hanging over the way out of the drain.
##
## Her verb is the environment. She cannot be touched while she is up in her
## webs — you have to cut the anchors holding her, and when the last one snaps
## she comes down and is briefly yours. Then she climbs back up and re-spins
## them, and you do it again.
##
## Four bosses, four questions:
##   rat     — WHEN to hit (punish the recovery)
##   Granny  — don't be hit at all (patience, not health)
##   cat     — WHAT to hit (the paw, not the cat)
##   queen   — hit something ELSE first (the webs, not her)
##
## The anchors sit high enough to need the wing bar, so the drain's own flight
## lesson is what the fight asks you to use.

enum State { SUSPENDED, DROPPING, EXPOSED, CLIMBING, RETREATING, GONE }

@export_group("Encounter")
@export var notice_range := 11.0
## Where she hangs, relative to her spawn.
@export var perch_height := 0.0
## How far she drops to land on the ledge.
@export var drop_distance := 4.6
## Seconds on the ground and vulnerable. The whole fight is spent earning these.
@export var exposed_time := 4.0
@export var climb_time := 1.1

@export_group("Webs")
@export var anchor_count := 3
@export var anchor_spacing := 3.4
## Height above the ledge she lands on — comfortably past a standing jump, so
## reaching them means flying.
@export var anchor_height := 3.4
@export var anchor_health := 2

@export_group("Attacks")
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


func _ready() -> void:
	super()
	immune_to_damage = true # until the webs are cut
	_ground_y = global_position.y - drop_distance
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
			_visual.position.y = sin(Time.get_ticks_msec() * 0.0016) * 0.16
			if not _engaged_check():
				return
			_spit_timer -= delta
			if _spit_timer <= 0.0:
				_spit_timer = spit_interval
				_spit()
		State.EXPOSED:
			if _timer <= 0.0:
				_climb()
		State.CLIMBING:
			if _timer <= 0.0:
				state = State.SUSPENDED
				immune_to_damage = true
				_spit_timer = spit_interval * 0.6
				_spin_webs()
		State.RETREATING:
			if _timer <= 0.0:
				state = State.GONE


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
	Snd.sfx("squeak", -2.0)
	var tween := create_tween()
	tween.tween_property(self, "global_position:y", _ground_y, 0.42
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func() -> void:
		if state == State.GONE or is_defeated:
			return
		state = State.EXPOSED
		# THIS is the window. Everything else is spent getting here.
		immune_to_damage = false
		_timer = exposed_time
		Snd.sfx("thud", 2.0)
		Fx.spark_burst(get_parent(), global_position, Color(0.9, 0.9, 1.0))
		Fx.impact_text(get_parent(), global_position + Vector3(0, 1.2, 0),
			Color(1.0, 0.85, 0.4), "SHE'S DOWN!", 0.85)
		_shake(0.5))


func _climb() -> void:
	if is_defeated:
		return
	state = State.CLIMBING
	immune_to_damage = true
	_timer = climb_time
	Snd.sfx("whoosh", -4.0)
	var tween := create_tween()
	tween.tween_property(self, "global_position:y", _ground_y + drop_distance, climb_time
		).set_ease(Tween.EASE_OUT)


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
	Snd.sfx("squeak", -3.0)


func _on_defeated() -> void:
	state = State.RETREATING
	_timer = 1.6
	immune_to_damage = true
	for anchor in _anchors:
		if is_instance_valid(anchor):
			anchor.queue_free()
	_anchors.clear()
	Snd.sfx("squeak", 5.0)
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
	for i in 4:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.13
		eye_mesh.height = 0.24
		var eye_mat := Block3D.flat_material(Color(0.95, 0.85, 0.3))
		eye_mat.emission_enabled = true
		eye_mat.emission = Color(0.95, 0.8, 0.25)
		eye_mat.emission_energy_multiplier = 1.4
		eye_mesh.material = eye_mat
		eye.mesh = eye_mesh
		eye.position = Vector3(1.15, 0.12 - (i % 2) * 0.28, -0.22 + float(i / 2) * 0.44)
		root.add_child(eye)
	for i in 8:
		var leg := MeshInstance3D.new()
		var leg_mesh := CylinderMesh.new()
		leg_mesh.top_radius = 0.05
		leg_mesh.bottom_radius = 0.09
		leg_mesh.height = 1.9
		leg_mesh.radial_segments = 5
		leg_mesh.material = chitin
		leg.mesh = leg_mesh
		var side := -1.0 if i < 4 else 1.0
		var along := (i % 4) - 1.5
		leg.position = Vector3(along * 0.42, 0.15, side * 0.55)
		leg.rotation = Vector3(side * 1.0, 0.0, along * 0.35)
		root.add_child(leg)
	return root
