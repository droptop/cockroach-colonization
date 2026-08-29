class_name DustWormBoss3D
extends BaseBoss3D

## THE DUST WORM, swimming under the moon's grey powder. Twelfth boss,
## twelfth verb: UNBURY.
##
## Below the dust it cannot be hurt — all you see is a mound gliding toward
## you, and all you can do about the worm itself is nothing. But the mound
## CAN be smacked: a hit on the hump throws the worm out onto the surface,
## where it flops, stunned and mortal, until it gathers itself and dives.
## Let the mound reach you instead and it erupts under your feet.
##
## Twelve bosses, twelve questions: rat = when · Granny = don't be hit ·
## cat = what · Queen = something else first · mantis = from where · wasp =
## stand where · toad = feed · magpie = gloat · snail = flip · owl = freeze ·
## probe = reflect · worm = UNBURY.

enum State { BURROWED, ERUPTING, EXPOSED, DIVING, GONE }

@export_group("Encounter")
@export var notice_range := 12.0
## How fast the mound swims toward him.
@export var burrow_speed := 2.4
## How long it flops in the open once thrown out.
@export var exposed_seconds := 4.0
## Close enough for the eruption attack to start.
@export var erupt_range := 1.5
@export var erupt_damage := 1
## Breather between eruptions, so it cannot chain-pop under his feet.
@export var erupt_cooldown := 2.8

var state := State.BURROWED

var _timer := 0.0
var _expose_hits := 0
var _hide_grace := 0.0
var _erupt_rest := 1.5
var _erupt_hit := false
var _target: Node3D
var _worm: Node3D
var _mound: Node3D
var _time := 0.0


func _ready() -> void:
	super()
	boss_rule = "It hunts FOOTSTEPS. Stand STILL - smack the MOUND to fling it out!"
	immune_to_damage = false # the dust does the guarding, in take_damage
	summon_count = 0
	_worm = _build_worm()
	add_child(_worm)
	_mound = _build_mound()
	add_child(_mound)
	_sink()


func _physics_process(delta: float) -> void:
	if state == State.GONE:
		return
	_time += delta
	_timer -= delta
	_erupt_rest -= delta
	_hide_grace -= delta
	match state:
		State.BURROWED:
			if not _acquire_target():
				return
			var dx := _target.global_position.x - global_position.x
			if absf(dx) <= notice_range:
				engage()
			if not engaged:
				return
			# It hunts by THUMPING, like the big ones on the desert planet: feet
			# on the dust call it in, stillness loses it. Walk without rhythm.
			var thumping: bool = _target.get("velocity") != null \
				and absf((_target.get("velocity") as Vector3).x) > 0.5
			if thumping:
				global_position.x = move_toward(global_position.x,
					_target.global_position.x, burrow_speed * delta)
			else:
				# Blind: the mound circles where it last felt footsteps.
				global_position.x += sin(_time * 1.3) * burrow_speed * 0.35 * delta
			global_position.x = clampf(global_position.x,
				arena_bounds().x + 1.0, arena_bounds().y - 1.0)
			if is_instance_valid(_mound):
				_mound.position.y = 0.15 + sin(_time * 6.0) * 0.06
			if absf(dx) <= erupt_range and _erupt_rest <= 0.0:
				_start_erupt()
		State.ERUPTING:
			# Half a sine of lunge: up through the dust, snap, back under.
			var t := 1.0 - (_timer / 0.9)
			_worm.position.y = sin(clampf(t, 0.0, 1.0) * PI) * 2.0
			if not _erupt_hit and t > 0.25 and t < 0.6 \
					and is_instance_valid(_target) \
					and absf(_target.global_position.x - global_position.x) < 1.5 \
					and _target.has_method("take_damage"):
				_erupt_hit = true
				_target.take_damage(erupt_damage, global_position, "the dust worm")
			if _timer <= 0.0:
				_sink()
		State.EXPOSED:
			# Flopping in the open: the only time it can be hurt.
			_worm.rotation.z = sin(_time * 9.0) * 0.28
			_worm.position.y = 0.5 + absf(sin(_time * 4.5)) * 0.12
			if _timer <= 0.0:
				state = State.DIVING
				_timer = 0.6
				Snd.sfx("whoosh", -4.0, 0.2)
		State.DIVING:
			_worm.position.y = maxf(_worm.position.y - 3.0 * delta, -0.6)
			if _timer <= 0.0:
				_sink()


## The dust does the guarding: buried, a hit lands on the MOUND and throws
## the worm into the open instead of hurting it. Only the flop is mortal.
func take_damage(amount: int, from_position: Vector3, _cause := "") -> void:
	engage()
	match state:
		State.BURROWED:
			# Freshly dived, the dust is still churning - it slips a beat
			# deeper and the smack finds nothing. Rhythm, not a mash-through.
			if _hide_grace > 0.0:
				_on_damage_shrugged(amount, from_position)
			else:
				_expose(from_position)
		State.EXPOSED:
			lose_health(amount, from_position)
			# It LEARNS: two bites per flop and it wrenches itself back under,
			# or a fast mash empties its whole health bar in one window.
			_expose_hits += 1
			if _expose_hits >= 2 and health > 0 and state == State.EXPOSED:
				state = State.DIVING
				_timer = 0.6
				Snd.sfx("whoosh", -4.0, 0.2)
		_:
			_on_damage_shrugged(amount, from_position)


func _expose(from_position: Vector3) -> void:
	state = State.EXPOSED
	_expose_hits = 0
	_timer = exposed_seconds
	_erupt_rest = maxf(_erupt_rest, exposed_seconds + 1.0)
	if is_instance_valid(_mound):
		_mound.visible = false
	_worm.visible = true
	_worm.position.y = 0.5
	Fx.spark_burst(get_parent(), global_position + Vector3(0, 0.6, 0),
		Color(0.72, 0.7, 0.66))
	Fx.impact_text(get_parent(), global_position + Vector3(0, 1.6, 0),
		Color(0.95, 0.9, 0.7), "THROWN OUT!", 0.9)
	Snd.sfx("splat", 0.0, 0.15)
	var _dir := signf(global_position.x - from_position.x)
	if _dir != 0.0:
		global_position.x = clampf(global_position.x + _dir * 0.4,
			arena_bounds().x + 1.0, arena_bounds().y - 1.0)


func _start_erupt() -> void:
	state = State.ERUPTING
	_timer = 0.9
	_erupt_hit = false
	_erupt_rest = erupt_cooldown
	if is_instance_valid(_mound):
		_mound.visible = false
	_worm.visible = true
	Fx.spark_burst(get_parent(), global_position + Vector3(0, 0.3, 0),
		Color(0.72, 0.7, 0.66))
	Snd.sfx("whoosh", 0.0, 0.1)


## Back under the powder: worm hidden low, mound gliding again.
func _sink() -> void:
	state = State.BURROWED
	_hide_grace = 1.0
	_worm.visible = false
	_worm.position.y = -0.6
	_worm.rotation.z = 0.0
	if is_instance_valid(_mound):
		_mound.visible = true


func _acquire_target() -> bool:
	if not is_instance_valid(_target):
		_target = null
		for node in get_tree().get_nodes_in_group("player"):
			_target = node
			break
	return _target != null


func _on_damaged(_amount: int, _from_position: Vector3) -> void:
	Fx.hit_flash(_worm, Color(1.0, 0.85, 0.8))
	Snd.sfx("impact_light", -3.0, 0.2)


func _on_defeated() -> void:
	state = State.GONE
	_worm.visible = true
	_worm.position.y = 0.5
	if is_instance_valid(_mound):
		_mound.visible = false
	Snd.sfx("impact_heavy", 2.0)
	Fx.ghost(get_parent(), global_position, 1.2, 6)
	Fx.shatter(get_parent(), _worm, 7.0)


## A segmented pink-grey worm: five beads shrinking to a tail, a blunt face
## with a ring of teeth. Built lying along x, the way it flops.
func _build_worm() -> Node3D:
	var root := Node3D.new()
	var hide := Block3D.flat_material(Color(0.78, 0.62, 0.6))
	var segments := 5
	for i in segments:
		var bead := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		var r := 0.52 - float(i) * 0.07
		mesh.radius = r
		mesh.height = r * 2.0
		mesh.radial_segments = 8
		mesh.rings = 4
		mesh.material = hide
		bead.mesh = mesh
		bead.position = Vector3(-float(i) * 0.55, float(i % 2) * 0.06, 0.0)
		root.add_child(bead)
	var maw := MeshInstance3D.new()
	var maw_mesh := CylinderMesh.new()
	maw_mesh.top_radius = 0.34
	maw_mesh.bottom_radius = 0.1
	maw_mesh.height = 0.3
	maw_mesh.radial_segments = 8
	var maw_mat := Block3D.flat_material(Color(0.4, 0.16, 0.2))
	maw_mesh.material = maw_mat
	maw.mesh = maw_mesh
	maw.rotation.z = -PI / 2.0
	maw.position = Vector3(0.5, 0.0, 0.0)
	root.add_child(maw)
	root.visible = false
	return root


## The hump of moving dust: all anyone sees of it while it swims.
func _build_mound() -> Node3D:
	var root := Node3D.new()
	var hump := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.9
	mesh.height = 0.7
	mesh.radial_segments = 10
	mesh.rings = 4
	mesh.material = Block3D.flat_material(Color(0.66, 0.65, 0.62))
	hump.mesh = mesh
	hump.position.y = 0.1
	root.add_child(hump)
	var puff := CPUParticles3D.new()
	puff.amount = 10
	puff.lifetime = 0.7
	puff.mesh = BoxMesh.new()
	(puff.mesh as BoxMesh).size = Vector3.ONE * 0.08
	puff.direction = Vector3.UP
	puff.initial_velocity_min = 0.4
	puff.initial_velocity_max = 1.0
	puff.spread = 40.0
	puff.gravity = Vector3(0, -1.5, 0)
	puff.position.y = 0.4
	root.add_child(puff)
	return root
