class_name OwlBoss3D
extends BaseBoss3D

## THE OWL, in the crown of the great tree. Tenth boss, tenth verb: FREEZE.
##
## It strikes at MOVEMENT. Its watch is a readable cycle — head away (your
## window to cross the canopy and hit it), a "HOO?" as it turns, then the
## eyes burn forward: move so much as a leg while it watches and the swoop
## comes down like a door. It is the only boss with no immunity at all —
## always hittable, at either of its two perches — because REACHING it across
## open branches under that stare is the entire fight. Red-light-green-light,
## with talons.
##
## Ten bosses, ten questions:
##   rat = when · Granny = don't be hit · cat = what · Queen = something else
##   first · mantis = from where · wasp = stand where · toad = what you feed
##   it · magpie = punish the gloat · snail = flip it · owl = FREEZE

enum State { ROOST, AWAY, TURNING, WATCHING, SWOOP, RETURN, RETREATING, GONE }

@export_group("Encounter")
@export var notice_range := 13.0
## The watch cycle, in seconds.
@export var away_time := 4.5
@export var turning_time := 0.8
@export var watching_time := 2.6
## Player speed that counts as movement under the stare. Breathing is free;
## walking is not.
@export var movement_tolerance := 0.6
## A beat of mercy as the eyes arrive, so an honest reaction can stop in time.
@export var stare_grace := 0.2
@export var swoop_damage := 2
@export var swoop_speed := 16.0
## Its two perches, relative to spawn: it alternates when hurt enough.
@export var perch_a := Vector3(-5.0, 3.4, 0.0)
@export var perch_b := Vector3(5.0, 3.4, 0.0)
## Damage taken before it flutters to the other perch.
@export var hits_per_perch := 2

var state := State.ROOST

var _timer := 1.5
var _target: Node3D
var _visual: Node3D
var _eyes: Array[MeshInstance3D] = []
var _eye_mats: Array[StandardMaterial3D] = []
var _head: Node3D
var _on_perch_a := true
var _perch_damage := 0
var _swoop_from := Vector3.ZERO
var _swoop_aim := Vector3.ZERO
var _swoop_t := 0.0
var _grace_left := 0.0
var _bob := 0.0


func _ready() -> void:
	super()
	boss_rule = "It strikes at MOVEMENT. When the eyes burn - FREEZE."
	immune_to_damage = false # the only boss without armour: reaching it is the fight
	summon_count = 0 # an owl needs no help
	_visual = _build_owl()
	add_child(_visual)
	global_position = arena_origin + perch_a


func _physics_process(delta: float) -> void:
	if state == State.GONE:
		return
	_timer -= delta
	_bob += delta
	if is_instance_valid(_visual) and state != State.SWOOP:
		_visual.position.y = sin(_bob * 1.6) * 0.08
	match state:
		State.ROOST:
			if _acquire_target() \
					and absf(_target.global_position.x - global_position.x) <= notice_range:
				engage()
				_go_away()
		State.AWAY:
			if _timer <= 0.0:
				_start_turning()
		State.TURNING:
			if _timer <= 0.0:
				_start_watching()
		State.WATCHING:
			_grace_left = maxf(_grace_left - delta, 0.0)
			if _grace_left <= 0.0 and _acquire_target() and not _target.is_dead \
					and Vector2(_target.velocity.x, _target.velocity.y).length() > movement_tolerance \
					and absf(_target.global_position.x - global_position.x) <= notice_range:
				_begin_swoop()
			elif _timer <= 0.0:
				_go_away()
		State.SWOOP:
			_swoop_t = minf(_swoop_t + delta * swoop_speed / maxf(
				_swoop_from.distance_to(_swoop_aim), 0.1), 1.0)
			global_position = _swoop_from.lerp(_swoop_aim, _swoop_t)
			if _swoop_t >= 0.45 and _swoop_t <= 0.65 and is_instance_valid(_target) \
					and _target.global_position.distance_to(global_position) < 1.3 \
					and _target.has_method("take_damage"):
				_target.take_damage(swoop_damage, global_position, "owl")
			if _swoop_t >= 1.0:
				_go_away()
		State.RETURN:
			pass
		State.RETREATING:
			if _timer <= 0.0:
				state = State.GONE


func _perch() -> Vector3:
	return arena_origin + (perch_a if _on_perch_a else perch_b)


func _go_away() -> void:
	state = State.AWAY
	_timer = away_time
	global_position = _perch()
	global_position.z = 0.0
	_set_eyes(0.15, Color(0.9, 0.75, 0.4))
	if is_instance_valid(_head):
		var turn := create_tween()
		turn.tween_property(_head, "rotation:y", PI * 0.85, 0.4)


func _start_turning() -> void:
	state = State.TURNING
	_timer = turning_time
	Snd.sfx("whoosh", -10.0, 0.3)
	Fx.impact_text(get_parent(), global_position + Vector3(0, 1.6, 0),
		Color(0.9, 0.85, 0.6), "HOO?", 0.7)
	if is_instance_valid(_head):
		var turn := create_tween()
		turn.tween_property(_head, "rotation:y", 0.0, turning_time * 0.8)


func _start_watching() -> void:
	state = State.WATCHING
	_timer = watching_time
	_grace_left = stare_grace
	_set_eyes(2.6, Color(1.0, 0.55, 0.15))
	Snd.sfx("locked", -8.0, 0.2)


func _begin_swoop() -> void:
	state = State.SWOOP
	_swoop_t = 0.0
	_swoop_from = global_position
	_swoop_aim = Vector3(_target.global_position.x, _target.global_position.y + 0.3, 0.0)
	Snd.sfx("whoosh", 2.0, 0.1)
	Fx.impact_text(get_parent(), global_position + Vector3(0, 1.4, 0),
		Color(1.0, 0.7, 0.4), "IT SAW YOU MOVE!", 0.85)


func _set_eyes(energy: float, color: Color) -> void:
	for mat in _eye_mats:
		mat.emission_energy_multiplier = energy
		mat.emission = color


## Its spoils land on the CROWN FLOOR, not at the player's altitude: the owl
## dies at a perch 3.4 m up, and the base rule (the player's floor) is only
## right when the player is standing on one - a flying killer would strand
## the payout in the leaves.
func spoils_origin() -> Vector3:
	return Vector3(global_position.x, arena_origin.y + 0.3, 0.0)


func _acquire_target() -> bool:
	if not is_instance_valid(_target):
		_target = null
		for node in get_tree().get_nodes_in_group("player"):
			_target = node
			break
	return _target != null


func _on_damaged(_amount: int, _from_position: Vector3) -> void:
	Fx.hit_flash(_visual, Color(1.0, 0.9, 0.8))
	Snd.sfx("impact_light", -3.0, 0.2)
	# Swinging IS moving. A hit landed under the stare answers instantly,
	# or parking beside the perch and mashing would be the whole fight.
	if state == State.WATCHING and _acquire_target():
		_begin_swoop()
		return
	_perch_damage += _amount
	if _perch_damage >= hits_per_perch and not is_defeated:
		_perch_damage = 0
		_on_perch_a = not _on_perch_a
		Fx.ghost(get_parent(), global_position, 0.5, 4)
		Fx.impact_text(get_parent(), global_position + Vector3(0, 1.6, 0),
			Color(0.9, 0.9, 0.75), "IT FLUTTERED ACROSS!", 0.8)
		_go_away()


func _on_defeated() -> void:
	state = State.RETREATING
	_timer = 1.4
	Snd.sfx("impact_heavy", 2.0)
	Fx.ghost(get_parent(), global_position + Vector3(0, 0.8, 0), 1.3, 6)
	Fx.shatter(get_parent(), _visual, 7.0)


## Round and solemn: barrel body, flat face disc, two enormous eyes that do
## the whole fight's talking, tufts, and folded wings.
func _build_owl() -> Node3D:
	var root := Node3D.new()
	var feather := Block3D.textured_material(Color(0.45, 0.36, 0.28), "speckle", 1.6)
	var pale := Block3D.flat_material(Color(0.8, 0.72, 0.6))

	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.95
	body_mesh.height = 1.9
	body_mesh.material = feather
	body.mesh = body_mesh
	body.position = Vector3(0, 0.95, 0)
	body.scale = Vector3(0.95, 1.1, 0.9)
	root.add_child(body)

	var belly := MeshInstance3D.new()
	var belly_mesh := SphereMesh.new()
	belly_mesh.radius = 0.62
	belly_mesh.height = 1.2
	belly_mesh.material = pale
	belly.mesh = belly_mesh
	belly.position = Vector3(0.35, 0.8, 0)
	belly.scale = Vector3(0.9, 1.0, 0.8)
	root.add_child(belly)

	_head = Node3D.new()
	_head.position = Vector3(0, 2.0, 0)
	root.add_child(_head)

	var face := MeshInstance3D.new()
	var face_mesh := SphereMesh.new()
	face_mesh.radius = 0.62
	face_mesh.height = 1.1
	face_mesh.material = feather
	face.mesh = face_mesh
	face.scale = Vector3(0.95, 0.9, 0.9)
	_head.add_child(face)

	var disc := MeshInstance3D.new()
	var disc_mesh := SphereMesh.new()
	disc_mesh.radius = 0.5
	disc_mesh.height = 0.9
	disc_mesh.material = pale
	disc.mesh = disc_mesh
	disc.position = Vector3(0.28, 0.0, 0)
	disc.scale = Vector3(0.5, 0.85, 0.85)
	_head.add_child(disc)

	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.17
		eye_mesh.height = 0.3
		eye_mesh.radial_segments = 8
		eye_mesh.rings = 4
		var mat := Block3D.flat_material(Color(0.95, 0.85, 0.5))
		mat.emission_enabled = true
		mat.emission = Color(0.9, 0.75, 0.4)
		mat.emission_energy_multiplier = 0.15
		eye_mesh.material = mat
		eye.mesh = eye_mesh
		eye.position = Vector3(0.5, 0.08, side * 0.22)
		_head.add_child(eye)
		_eyes.append(eye)
		_eye_mats.append(mat)
		var pupil := MeshInstance3D.new()
		var pupil_mesh := SphereMesh.new()
		pupil_mesh.radius = 0.07
		pupil_mesh.height = 0.13
		pupil_mesh.radial_segments = 6
		pupil_mesh.rings = 3
		pupil_mesh.material = Block3D.flat_material(Color(0.06, 0.05, 0.05))
		pupil.mesh = pupil_mesh
		pupil.position = Vector3(0.62, 0.08, side * 0.22)
		_head.add_child(pupil)
		# Ear tufts.
		var tuft := MeshInstance3D.new()
		var tuft_mesh := CylinderMesh.new()
		tuft_mesh.top_radius = 0.02
		tuft_mesh.bottom_radius = 0.12
		tuft_mesh.height = 0.4
		tuft_mesh.radial_segments = 5
		tuft_mesh.material = feather
		tuft.mesh = tuft_mesh
		tuft.position = Vector3(-0.1, 0.55, side * 0.3)
		tuft.rotation.z = -0.2
		_head.add_child(tuft)

	# Folded wings and tail.
	for side in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var wing_mesh := SphereMesh.new()
		wing_mesh.radius = 0.55
		wing_mesh.height = 1.5
		wing_mesh.material = feather
		wing.mesh = wing_mesh
		wing.position = Vector3(-0.25, 1.0, side * 0.62)
		wing.scale = Vector3(0.8, 1.0, 0.35)
		root.add_child(wing)
	var tail := MeshInstance3D.new()
	var tail_mesh := BoxMesh.new()
	tail_mesh.size = Vector3(0.9, 0.12, 0.5)
	tail_mesh.material = feather
	tail.mesh = tail_mesh
	tail.position = Vector3(-0.85, 0.5, 0)
	tail.rotation.z = 0.5
	root.add_child(tail)
	# Talons around the branch.
	for side in [-0.2, 0.2]:
		var foot := MeshInstance3D.new()
		var foot_mesh := SphereMesh.new()
		foot_mesh.radius = 0.14
		foot_mesh.height = 0.22
		foot_mesh.material = Block3D.flat_material(Color(0.75, 0.6, 0.3))
		foot.mesh = foot_mesh
		foot.position = Vector3(0.1, 0.05, side)
		root.add_child(foot)
	return root
