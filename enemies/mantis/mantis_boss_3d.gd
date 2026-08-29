class_name MantisBoss3D
extends BaseBoss3D

## THE PRAYING MANTIS, waiting at the end of the alley.
##
## Its verb is the ANGLE. Those raised forearms are a wall: anything that comes
## at its face is caught and turned aside, and it pivots to keep facing you. It
## can be hurt — just not from the front.
##
## There are two answers, and both use the movement kit rather than the weapon:
##   - get ABOVE it — a down-attack comes in at an angle the guard cannot cover,
##     so the pogo lands every time;
##   - get BEHIND it — which means baiting a strike, because while it is
##     committed to one it cannot turn, and its guard is down through the
##     recovery besides.
##
## Five bosses, five questions:
##   rat = when to hit · Granny = don't be hit · cat = what to hit ·
##   Spider Queen = hit something else first · mantis = hit from WHERE.

enum State { WAITING, TRACKING, WINDUP, STRIKE, RECOVER, LUNGE, BLADE, WARP, RETREATING, GONE }

@export_group("Encounter")
@export var notice_range := 12.0
@export var attack_interval := 2.2
## How long the opening roar holds the fight before the first attack.
@export var roar_time := 1.5
@export var turn_speed := 6.0

@export_group("Guard")
## Total width of the blocked cone, in degrees, centred on its facing. Anything
## inside this is turned aside.
@export var guard_arc := 150.0
## A hit steeper than this (vertically) is not a frontal hit at all — this is
## what makes the pogo a reliable answer.
@export_range(0.0, 1.0) var guard_max_steepness := 0.5

@export_group("Attacks")
@export var telegraph_time := 0.75
@export var scythe_damage := 2
@export var scythe_reach := 2.6
## Committed and wide open. The whole "get behind it" plan lives in here.
@export var recover_time := 1.5
@export var lunge_speed := 9.0
@export var lunge_damage := 2
@export var gravity := 26.0
## The SPINNING-BLADE CHARGE (BACKLOG item 19): every fourth attack it tucks,
## spins up, and sweeps the arena as a moving saw. Jump or fly OVER it, and
## the spin-out at the far wall leaves it dizzy for the fight's longest
## punish window.
@export var blade_speed := 7.5
@export var blade_damage := 2
## Seconds between contact ticks while it saws through him.
@export var blade_tick := 0.7
## The WARP: hit twice in quick succession while it still has its footing and
## it blinks to your far side - camping one flank stops working. Never from
## RECOVER (warping out of the earned punish would be theft), and never twice
## inside this cooldown.
@export var warp_cooldown := 6.0

var state := State.WAITING
var facing := -1

var _timer := 0.0
var _attack_index := 0
var _target: Node3D
var _visual: Node3D
var _wings: Node3D
var _wing_pivots: Array[Node3D] = []
var _wing_beat := 0.0
var _arms: Node3D
var _blade_hit_timer := 0.0
var _recent_hits := 0
var _hit_window := 0.0
var _warp_cooldown_left := 0.0


func _ready() -> void:
	super()
	boss_rule = "It blocks everything to its front. Get ABOVE it and stomp down."
	_visual = _build_mantis()
	add_child(_visual)


func _physics_process(delta: float) -> void:
	if state == State.GONE:
		return
	if not is_on_floor():
		velocity.y = maxf(velocity.y - gravity * delta, -20.0)
	_timer -= delta
	_hit_window = maxf(_hit_window - delta, 0.0)
	if _hit_window <= 0.0:
		_recent_hits = 0
	_warp_cooldown_left = maxf(_warp_cooldown_left - delta, 0.0)
	_blade_hit_timer = maxf(_blade_hit_timer - delta, 0.0)

	match state:
		State.WAITING:
			velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
			if _acquire_target() \
					and absf(_target.global_position.x - global_position.x) < notice_range:
				engage()
				state = State.TRACKING
				_timer = attack_interval
		State.TRACKING:
			velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
			_face_target(delta)
			if _timer <= 0.0:
				_begin_attack()
		State.WINDUP, State.STRIKE, State.RECOVER:
			# Committed: it cannot turn. This is the opening.
			velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
		State.LUNGE:
			velocity.x = facing * lunge_speed
			# It is FLYING at him, not running: the wings beat while it closes.
			_wing_beat += delta * 34.0
			for pivot in _wing_pivots:
				pivot.rotation.y = signf(pivot.position.z) * (0.55 + sin(_wing_beat) * 0.5)
			if _timer <= 0.0 or is_on_wall() \
					or absf(global_position.x - arena_origin.x) > arena_half_width:
				_recover()
		State.BLADE:
			velocity.x = facing * blade_speed
			# The saw: forearms whirling faster than a guard could ever hold.
			_arms.rotation.z += delta * 26.0
			if is_instance_valid(_target) and not _target.is_dead \
					and _blade_hit_timer <= 0.0 \
					and absf(_target.global_position.x - global_position.x) < 1.4 \
					and absf(_target.global_position.y - global_position.y) < 1.6:
				_blade_hit_timer = blade_tick
				_target.take_damage(blade_damage, global_position, "mantis")
			if _timer <= 0.0 or is_on_wall() \
					or absf(global_position.x - arena_origin.x) > arena_half_width - 0.4:
				_blade_dizzy()
		State.WARP:
			velocity.x = 0.0
			if _timer <= 0.0:
				_warp_arrive()
		State.RETREATING:
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
			if _timer <= 0.0:
				state = State.GONE
	move_and_slide()
	_visual.rotation.y = lerp_angle(_visual.rotation.y, 0.0 if facing > 0 else PI,
		minf(turn_speed * delta, 1.0))


func _face_target(_delta: float) -> void:
	if not is_instance_valid(_target):
		return
	var dx := _target.global_position.x - global_position.x
	if absf(dx) > 0.15:
		facing = int(signf(dx))


func _begin_attack() -> void:
	_attack_index += 1
	if _attack_index % 4 == 0:
		_blade_charge()
	elif _attack_index % 2 == 0:
		_lunge()
	else:
		_scythe()


## Tucks, spins up, and SWEEPS. Committed the whole way across: no guard, no
## turning — the answer is to be above it when it passes, and the spin-out at
## the far side is the longest punish window the fight offers.
func _blade_charge() -> void:
	state = State.WINDUP
	_timer = telegraph_time * 1.5
	Snd.sfx("mantis_cry", -2.0, 0.2)
	Fx.impact_text(get_parent(), global_position + Vector3(0, 2.4, 0),
		Color(0.75, 1.0, 0.6), "IT'S SPINNING UP!", 0.85)
	var tuck := create_tween()
	tuck.tween_property(_arms, "rotation:z", -1.4, telegraph_time * 1.2)
	tuck.parallel().tween_property(_visual, "scale",
		Vector3(0.9, 1.05, 0.9), telegraph_time * 1.2)
	await get_tree().create_timer(telegraph_time * 1.5).timeout
	if state != State.WINDUP:
		return
	state = State.BLADE
	# Long enough to cross the whole arena at blade speed; walls end it early.
	_timer = arena_half_width * 2.0 / blade_speed + 0.4
	_blade_hit_timer = 0.0
	Snd.sfx("whoosh", 2.0, 0.1)
	var spring := create_tween()
	spring.tween_property(_visual, "scale", Vector3.ONE, 0.15)


func _blade_dizzy() -> void:
	if state != State.BLADE:
		return
	Snd.sfx("impact_light", -2.0, 0.2)
	Fx.impact_text(get_parent(), global_position + Vector3(0, 2.2, 0),
		Color(0.9, 0.95, 0.7), "DIZZY!", 0.9)
	Fx.spark_burst(get_parent(), global_position + Vector3(facing * 1.0, 1.0, 0),
		Color(0.8, 1.0, 0.6))
	var wobble := create_tween()
	wobble.tween_property(_visual, "rotation:z", 0.28, 0.18)
	wobble.tween_property(_visual, "rotation:z", -0.22, 0.3)
	wobble.tween_property(_visual, "rotation:z", 0.0, 0.4)
	# Its own long recover, not _recover(): that one's exit rides its own
	# tween, so the spin-out's extra opening has to be baked into the tween.
	state = State.RECOVER
	var drop := create_tween()
	drop.tween_property(_arms, "rotation:z", 0.55, 0.15)
	drop.tween_interval(recover_time * 1.8 - 0.4)
	drop.tween_property(_arms, "rotation:z", 0.0, 0.25)
	drop.tween_callback(func() -> void:
		if state == State.RECOVER:
			state = State.TRACKING
			_timer = attack_interval)


## Raises the forearms, holds, then slashes. The raise IS the telegraph, and it
## is also the moment the guard becomes irrelevant — it is about to commit.
func _scythe() -> void:
	state = State.WINDUP
	_timer = telegraph_time
	Snd.sfx("whoosh", -6.0, 0.2)
	var lift := create_tween()
	lift.tween_property(_arms, "rotation:z", -1.0, telegraph_time * 0.8)
	await get_tree().create_timer(telegraph_time).timeout
	if state != State.WINDUP:
		return
	state = State.STRIKE
	Snd.sfx("bite", 2.0)
	var swing := create_tween()
	swing.tween_property(_arms, "rotation:z", 0.9, 0.09)
	swing.tween_callback(func() -> void:
		if is_instance_valid(_target) and not _target.is_dead:
			var dx: float = _target.global_position.x - global_position.x
			var in_front := signf(dx) == float(facing)
			if in_front and absf(dx) < scythe_reach \
					and absf(_target.global_position.y - global_position.y) < 1.6:
				_target.take_damage(scythe_damage, global_position, "mantis")
		Fx.spark_burst(get_parent(),
			global_position + Vector3(facing * 1.4, 0.5, 0), Color(0.7, 1.0, 0.6)))
	swing.tween_interval(0.06)
	swing.tween_property(_arms, "rotation:z", 0.0, 0.2)
	_recover()


func _lunge() -> void:
	state = State.WINDUP
	_timer = telegraph_time * 1.2
	Snd.sfx("mantis_cry", -6.0, 0.3)
	var crouch := create_tween()
	crouch.tween_property(_visual, "scale", Vector3(1.15, 0.82, 1.15), telegraph_time)
	await get_tree().create_timer(telegraph_time * 1.2).timeout
	if state != State.WINDUP:
		return
	state = State.LUNGE
	_timer = 0.55
	var spring := create_tween()
	spring.tween_property(_visual, "scale", Vector3(0.9, 1.15, 0.9), 0.08)
	spring.tween_property(_visual, "scale", Vector3.ONE, 0.2)
	Snd.sfx("whoosh", 0.0)


func _recover() -> void:
	state = State.RECOVER
	_timer = recover_time
	# Guard visibly drops, so the window is something you can see and not just
	# something you learn from the manual.
	var drop := create_tween()
	drop.tween_property(_arms, "rotation:z", 0.55, 0.15)
	drop.tween_interval(recover_time - 0.4)
	drop.tween_property(_arms, "rotation:z", 0.0, 0.25)
	drop.tween_callback(func() -> void:
		if state == State.RECOVER:
			state = State.TRACKING
			_timer = attack_interval)


## The guard. A hit is turned aside only if it comes at the FRONT, roughly
## level — from above or behind, those forearms are nowhere near it.
func _absorbs(_amount: int, from_position: Vector3) -> bool:
	if state == State.RECOVER or state == State.LUNGE or state == State.BLADE:
		return false # committed, arms down (or whirling - a saw is not a shield)
	var offset := from_position - global_position
	if offset.length() < 0.01:
		return false
	var direction := offset.normalized()
	# Steep enough and it is coming down on top of it — the pogo's answer.
	if absf(direction.y) > guard_max_steepness:
		return false
	var frontal := direction.dot(Vector3(facing, 0, 0))
	return frontal > cos(deg_to_rad(guard_arc * 0.5))


func _on_damage_shrugged(_amount: int, _from_position: Vector3) -> void:
	Fx.impact_text(get_parent(), global_position + Vector3(0, 1.2, 0),
		Color(0.75, 1.0, 0.75), "GUARDED!", 0.7)
	Snd.sfx("guard", -6.0, 0.2)
	var parry := create_tween()
	parry.tween_property(_arms, "rotation:z", -0.35, 0.06)
	parry.tween_property(_arms, "rotation:z", 0.0, 0.16)


func _on_damaged(_amount: int, _from_position: Vector3) -> void:
	Fx.hit_flash(_visual, Color(1.0, 0.85, 0.8))
	Snd.sfx("mantis_hurt", -4.0)
	velocity.x += -facing * 1.2
	# Two clean hits in one breath and it WARPS to your far side: camping the
	# one spot its guard cannot cover stops being the whole fight. Only while
	# it has its footing - warping out of an earned punish would be theft.
	_recent_hits += 1
	_hit_window = 3.0
	if _recent_hits >= 2 and _warp_cooldown_left <= 0.0 \
			and (state == State.TRACKING or state == State.WINDUP) \
			and is_instance_valid(_target):
		_warp_out()


func _warp_out() -> void:
	_recent_hits = 0
	_warp_cooldown_left = warp_cooldown
	state = State.WARP
	_timer = 0.4
	Snd.sfx("whoosh", -2.0, 0.3)
	Fx.ghost(get_parent(), global_position + Vector3(0, 0.8, 0), 0.5, 5)
	var shrink := create_tween()
	shrink.tween_property(_visual, "scale", Vector3(0.2, 1.4, 0.2), 0.3)


func _warp_arrive() -> void:
	var bounds := arena_bounds()
	var landing := arena_origin.x
	if is_instance_valid(_target):
		var px: float = _target.global_position.x
		# Prefer the player's far side, but take whichever side has ROOM:
		# near an arena wall the far side can be a wall's width of nothing,
		# and a warp the clamp cancels is a fizzle, not a reposition.
		var side := signf(px - global_position.x)
		if side == 0.0:
			side = 1.0
		var room_right := bounds.y - 0.8 - px
		var room_left := px - (bounds.x + 0.8)
		var room := room_right if side > 0.0 else room_left
		if room < 2.5:
			side = -side
			room = room_right if side > 0.0 else room_left
		landing = px + side * minf(4.2, maxf(room, 0.8))
	global_position = Vector3(landing, global_position.y, 0.0)
	Fx.spark_burst(get_parent(), global_position + Vector3(0, 1.0, 0),
		Color(0.7, 1.0, 0.6))
	Fx.impact_text(get_parent(), global_position + Vector3(0, 2.2, 0),
		Color(0.75, 1.0, 0.75), "BEHIND YOU!", 0.7)
	var grow := create_tween()
	grow.tween_property(_visual, "scale", Vector3.ONE, 0.2)
	_face_target(0.0)
	state = State.TRACKING
	_timer = attack_interval * 0.7


func _on_defeated() -> void:
	state = State.RETREATING
	_timer = 1.5
	Snd.sfx("mantis_death", 3.0)
	Fx.ghost(get_parent(), global_position + Vector3(0, 0.8, 0), 1.3, 6)
	for spoil in [["heart", 2.0, -1.6], ["energy", 45.0, 1.4]]:
		var reward := RewardPickup3D.new()
		reward.kind = spoil[0]
		reward.amount = spoil[1]
		reward.lifetime = 0.0
		get_parent().add_child(reward)
		reward.global_position = global_position + Vector3(spoil[2], 0.6, 0)
	Fx.shatter(get_parent(), _visual, 7.0)
	var tween := create_tween()
	tween.tween_interval(0.7)
	# THE BROOD GUARDS THE GATE (BACKLOG item 19): the big one falls and two
	# nymphs drop in by the door it was defending. The exit still opens - they
	# are ordinary two-bite enemies, an escort out, not a second lock.
	tween.tween_callback(func() -> void:
		var zone := get_parent().get_node_or_null("ExitZone")
		if zone == null:
			return
		var door_x: float = (zone as Node3D).global_position.x
		Fx.impact_text(get_parent(), Vector3(door_x - 2.5, 2.4, 0),
			Color(0.75, 1.0, 0.6), "THE BROOD GUARDS THE GATE!", 0.9)
		for offset in [-3.4, -1.8]:
			_spawn_nymph(Vector3(door_x + offset, global_position.y + 4.0, 0.0)))


func _acquire_target() -> bool:
	if not is_instance_valid(_target):
		_target = null
		for node in get_tree().get_nodes_in_group("player"):
			_target = node
			break
	return _target != null


## Long green body, triangular head, and the forearms folded in prayer — which
## is also, conveniently, a guard.
## It rears up and ROARS before a blow is struck. The fight used to simply
## begin, and the mantis is the one boss whose whole answer is positional, so a
## beat where you are made to look at its guard before it can hurt you is worth
## the second it costs.
##
## Time-scale-independent timers throughout: this holds the FSM still, and a
## sequence that paused with the game would never finish if it were paused.
func _on_engaged() -> void:
	state = State.WAITING
	_timer = roar_time
	Snd.sfx("mantis_cry", 4.0, 0.02)
	_roar()


func _roar() -> void:
	if not is_instance_valid(_visual):
		return
	# Rears back, throws its wings open, and holds.
	var rear := create_tween()
	rear.set_parallel(true)
	rear.tween_property(_visual, "rotation:z", -0.34, 0.22).set_ease(Tween.EASE_OUT)
	rear.tween_property(_visual, "scale", Vector3(1.08, 1.22, 1.08), 0.22)
	for pivot in _wing_pivots:
		if is_instance_valid(pivot):
			rear.tween_property(pivot, "rotation:y", signf(pivot.position.z) * 1.15, 0.2)
	var settle := create_tween()
	settle.tween_interval(roar_time * 0.75)
	settle.set_parallel(true)
	settle.tween_property(_visual, "rotation:z", 0.0, 0.3)
	settle.tween_property(_visual, "scale", Vector3.ONE, 0.3)
	for pivot in _wing_pivots:
		if is_instance_valid(pivot):
			settle.tween_property(pivot, "rotation:y", 0.0, 0.3)

	# The vibrations coming off it: rings that swell and fade, staggered so it
	# reads as a sustained sound rather than one pop.
	for i in 4:
		var delay := 0.12 + float(i) * 0.16
		var timer := get_tree().create_timer(delay)
		timer.timeout.connect(_ring)
	_shake_camera(0.55)
	Fx.impact_text(get_parent(), global_position + Vector3(0, 2.6, 0),
		Color(0.8, 1.0, 0.6), "SKREEEE!", 0.9)


## The camera rides on the player, so the shake is asked of it through him.
## `_shake` on Granny is her own private helper, not something on BaseBoss3D:
## calling it here compiled clean and then failed at runtime, because GDScript
## does not resolve a missing method until the body actually runs.
func _shake_camera(strength: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var cam := (player as Node).get_node_or_null("Camera3D")
	if cam and cam.has_method("shake"):
		cam.shake(strength)


## One expanding ring of sound.
func _ring() -> void:
	if not is_inside_tree():
		return
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.5
	mesh.outer_radius = 0.62
	mesh.rings = 14
	mesh.ring_segments = 6
	var mat := Block3D.flat_material(Color(0.85, 1.0, 0.7, 0.5))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.7, 1.0, 0.55)
	mat.emission_energy_multiplier = 1.1
	mesh.material = mat
	ring.mesh = mesh
	ring.rotation.y = PI / 2.0
	get_parent().add_child(ring)
	ring.global_position = global_position + Vector3(facing * 0.9, 1.55, 0)
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 4.2, 0.55)
	tween.tween_method(func(a: float) -> void:
		mat.albedo_color.a = a, 0.5, 0.0, 0.55)
	tween.chain().tween_callback(ring.queue_free)


## It calls its own, not somebody else's. The shared summon drops ants, which
## is right for a rat in a drain and wrong for a mantis: what comes down should
## be small versions of the thing you are fighting.
func _summon_wave() -> void:
	var level := get_parent()
	if level == null or not level.is_inside_tree():
		return
	Snd.sfx("mantis_cry", 0.0, 0.2)
	Fx.impact_text(level, global_position + Vector3(0, 2.4, 0),
		Color(0.75, 1.0, 0.6), "IT'S CALLING ITS BROOD!", 0.9)
	for i in summon_count:
		var t: float = (float(i) + 0.5) / float(summon_count)
		_spawn_nymph(global_position + Vector3(
			lerpf(-summon_spread, summon_spread, t), summon_height, 0.0))


## A nymph, not a second boss: no arena of its own, no summons of its own,
## and little enough health that it dies to the ordinary bite. Without those
## three it would be six more boss fights at once. Shared by the mid-fight
## waves and the gate guard the death leaves behind.
##
## The mantis has no scene file: it is assembled in the level, so a bare
## .new() has no collision shape, no layer and no mask, and the nymph would
## fall through the street and never be hittable. Mirrors the placed boss
## exactly, at nymph size.
func _spawn_nymph(at: Vector3) -> void:
	var level := get_parent()
	if level == null or not level.is_inside_tree():
		return
	var young := MantisBoss3D.new()
	young.boss_name = "MANTIS NYMPH"
	young.boss_id = "" # empty id: a nymph is never persisted as beaten
	young.max_health = 2
	young.summon_count = 0 # or the brood breeds a brood
	young.arena_half_width = arena_half_width
	young.collision_layer = 4
	young.collision_mask = 1
	young.axis_lock_linear_z = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.9, 1.4) * 0.42
	shape.shape = box
	shape.position = Vector3(0, 0.95 * 0.42, 0)
	young.add_child(shape)
	level.add_child(young)
	young.scale = Vector3.ONE * 0.42
	young.global_position = at
	Fx.spark_burst(level, at, Color(0.6, 0.9, 0.45))


func _build_mantis() -> Node3D:
	var root := Node3D.new()
	var chitin := Block3D.textured_material(Color(0.36, 0.62, 0.28), "speckle", 2.2)
	var spine_mat := Block3D.flat_material(Color(0.88, 0.9, 0.72))
	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.55
	body_mesh.height = 1.1
	body_mesh.material = chitin
	body.mesh = body_mesh
	body.scale = Vector3(2.1, 0.85, 0.9)
	body.position = Vector3(-0.7, 0.75, 0)
	root.add_child(body)

	var thorax := MeshInstance3D.new()
	var thorax_mesh := CylinderMesh.new()
	thorax_mesh.top_radius = 0.22
	thorax_mesh.bottom_radius = 0.3
	thorax_mesh.height = 1.1
	thorax_mesh.radial_segments = 8
	thorax_mesh.material = chitin
	thorax.mesh = thorax_mesh
	thorax.position = Vector3(0.35, 1.05, 0)
	thorax.rotation.z = -0.5
	root.add_child(thorax)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.34
	head_mesh.height = 0.62
	head_mesh.material = chitin
	head.mesh = head_mesh
	head.scale = Vector3(1.0, 0.8, 0.75)
	head.position = Vector3(0.82, 1.5, 0)
	root.add_child(head)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.15
		eye_mesh.height = 0.28
		var eye_mat := Block3D.flat_material(Color(0.95, 0.95, 0.6))
		eye_mat.emission_enabled = true
		eye_mat.emission = Color(0.9, 0.95, 0.5)
		eye_mat.emission_energy_multiplier = 1.1
		eye_mesh.material = eye_mat
		eye.mesh = eye_mesh
		eye.position = Vector3(1.0, 1.6, side * 0.2)
		root.add_child(eye)

	# The forearms, on their own pivot so the guard can visibly rise and drop.
	_arms = Node3D.new()
	_arms.position = Vector3(0.55, 1.05, 0)
	root.add_child(_arms)
	for side in [-1.0, 1.0]:
		for part in [[0.0, 0.0, 0.9, -0.35], [0.5, -0.35, 0.85, 1.1]]:
			var seg := MeshInstance3D.new()
			var seg_mesh := CylinderMesh.new()
			seg_mesh.top_radius = 0.09
			seg_mesh.bottom_radius = 0.12
			seg_mesh.height = part[2]
			seg_mesh.radial_segments = 6
			seg_mesh.material = chitin
			seg.mesh = seg_mesh
			seg.position = Vector3(part[0], part[1], side * 0.22)
			seg.rotation.z = part[3]
			_arms.add_child(seg)
			# The tibial spines. A mantis's forelegs are saw blades, and
			# smooth cylinders read as sticks: this is the one detail that
			# says "that thing catches and holds you".
			var spikes := MultiMesh.new()
			spikes.transform_format = MultiMesh.TRANSFORM_3D
			var spike_mesh := CylinderMesh.new()
			spike_mesh.top_radius = 0.0
			spike_mesh.bottom_radius = 0.035
			spike_mesh.height = 0.16
			spike_mesh.radial_segments = 4
			spike_mesh.material = spine_mat
			spikes.mesh = spike_mesh
			spikes.instance_count = 5
			for k in 5:
				var t: float = -part[2] * 0.4 + float(k) * part[2] * 0.2
				spikes.set_instance_transform(k, Transform3D(
					Basis.from_euler(Vector3(0, 0, PI)), Vector3(0.06, t, 0)))
			var spike_node := MultiMeshInstance3D.new()
			spike_node.multimesh = spikes
			seg.add_child(spike_node)
	# Wings, folded along its back and thrown open when it rises. Mantises fly,
	# and one that could only ever walk at you had no answer to standing on a
	# ledge above it.
	_wings = Node3D.new()
	_wings.position = Vector3(-0.55, 1.15, 0)
	root.add_child(_wings)
	var wing_mat := Block3D.flat_material(Color(0.55, 0.78, 0.42, 0.72))
	wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wing_mat.emission_enabled = true
	wing_mat.emission = Color(0.4, 0.7, 0.35)
	wing_mat.emission_energy_multiplier = 0.25
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 0, side * 0.24)
		_wings.add_child(pivot)
		_wing_pivots.append(pivot)
		var wing := MeshInstance3D.new()
		var wing_mesh := BoxMesh.new()
		wing_mesh.size = Vector3(1.7, 0.05, 0.62)
		wing_mesh.material = wing_mat
		wing.mesh = wing_mesh
		wing.position = Vector3(-0.75, 0, side * 0.2)
		wing.rotation.x = side * 0.18
		pivot.add_child(wing)
		# A dark leading edge, so it does not vanish against the wall.
		var vein := MeshInstance3D.new()
		var vein_mesh := BoxMesh.new()
		vein_mesh.size = Vector3(1.7, 0.07, 0.07)
		vein_mesh.material = Block3D.flat_material(Color(0.27, 0.42, 0.2))
		vein.mesh = vein_mesh
		vein.position = Vector3(-0.75, 0.02, side * 0.48)
		vein.rotation.x = side * 0.18
		pivot.add_child(vein)

	for i in 6:
		var leg := MeshInstance3D.new()
		var leg_mesh := CylinderMesh.new()
		leg_mesh.top_radius = 0.05
		leg_mesh.bottom_radius = 0.08
		leg_mesh.height = 1.3
		leg_mesh.radial_segments = 5
		leg_mesh.material = chitin
		leg.mesh = leg_mesh
		var side := -1.0 if i < 3 else 1.0
		var along := (i % 3) - 1
		leg.position = Vector3(-0.9 + along * 0.5, 0.42, side * 0.4)
		leg.rotation = Vector3(side * 0.9, 0.0, along * 0.3)
		root.add_child(leg)
	return root
