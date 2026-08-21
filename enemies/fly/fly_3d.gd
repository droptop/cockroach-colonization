extends CharacterBody3D

## Aerial enemy: hovers around its anchor point bobbing lazily, then dive-bombs
## Harry when he wanders underneath. Returns to its perch after each swoop.

enum State { HOVER, DIVE, RETURN, DEAD }

@export var detect_range := 4.5
@export var dive_speed := 6.5
@export var return_speed := 3.0
@export var dive_cooldown := 2.2
@export var contact_damage := 1
@export var max_health := 2
## What it leaves behind. Flies are the reliable health drop in a game where
## nothing else heals you mid-level.
@export_enum("heart", "energy", "none") var drop_kind := "heart"
@export var drop_amount := 1.0

@export_group("Spit")
## A fly that shoots. Off by default, so existing placements are unchanged and
## a level designer opts in where a ranged threat is wanted.
@export var spits := false
@export var spit_interval := 2.6
@export var spit_damage := 1
@export var spit_speed := 9.0
## Deliberately longer than `detect_range`. Reusing _acquire_target() gated the
## spit on being close enough to DIVE at, which makes a ranged attack pointless
## — it only fired when the fly would rather have rammed him.
##
## `Encounter.ON_SCREEN_X` is the real upper bound: 13 is wider than the visible
## world, so this used to fire from off-camera at something the player could not
## see. Values below the cap still bind, for a fly meant to spit only up close.
@export var spit_range := 13.0

var state := State.HOVER
## Frozen by the antennae pulse while this is above zero.
var _stagger_timer := 0.0
var health := 2

var _anchor := Vector3.ZERO
var _time := 0.0
var _cooldown := 0.0
var _dive_target := Vector3.ZERO
var _spit_timer := 0.0
var _target: Node3D

@onready var _visual: Node3D = $Visual
@onready var _hitbox: Area3D = $Hitbox


var _hp_bar: EnemyHealthBar


func _ready() -> void:
	health = max_health
	_anchor = global_position
	_hp_bar = EnemyHealthBar.new()
	_hp_bar.position = Vector3(0, 0.7, 0)
	_hp_bar.scale = Vector3.ONE * 0.7
	add_child(_hp_bar)
	_time = randf() * TAU


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _stagger_timer > 0.0:
		_stagger_timer -= delta
		velocity = velocity.move_toward(Vector3.ZERO, 14.0 * delta)
		move_and_slide()
		return
	_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	if spits and state == State.HOVER:
		_spit_timer -= delta
		if _spit_timer <= 0.0:
			var mark := _nearest_player()
			if mark and global_position.distance_to(mark.global_position) <= spit_range \
					and Encounter.on_screen(self, mark):
				_spit_timer = spit_interval
				_spit_at(mark)
	match state:
		State.HOVER:
			var bob := _anchor + Vector3(sin(_time * 1.3) * 0.5, sin(_time * 2.1) * 0.3, 0)
			velocity = (bob - global_position) * 4.0
			velocity.z = 0.0
			if _cooldown <= 0.0 and _acquire_target() and Encounter.may_commit(self, _target):
				Encounter.commit(self)
				_dive_target = _target.global_position + Vector3(0, 0.2, 0)
				state = State.DIVE
		State.DIVE:
			var to_target := _dive_target - global_position
			to_target.z = 0.0
			if to_target.length() < 0.3:
				state = State.RETURN
				_cooldown = dive_cooldown
			else:
				velocity = to_target.normalized() * dive_speed
		State.RETURN:
			Encounter.release(self)
			var back := _anchor - global_position
			back.z = 0.0
			if back.length() < 0.3:
				state = State.HOVER
			else:
				velocity = back.normalized() * return_speed
	move_and_slide()
	if state == State.DIVE and is_on_floor():
		# Smacked the ground — head home.
		state = State.RETURN
		_cooldown = dive_cooldown
	if absf(velocity.x) > 0.1:
		_visual.scale.x = signf(velocity.x)
	for body in _hitbox.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(contact_damage, global_position, "fly")


func _acquire_target() -> bool:
	if not is_instance_valid(_target):
		_target = null
		for node in get_tree().get_nodes_in_group("player"):
			_target = node
			break
	return _target != null \
		and global_position.distance_to(_target.global_position) <= detect_range


## `cause` is accepted and ignored here — it only decides the PLAYER's
## death message. Taking it keeps one duck-typed signature across
## everything that can be hurt, so a caller never has to ask what it is
## hitting before it hits it.
func take_damage(amount: int, from_position: Vector3, _cause := "") -> void:
	if state == State.DEAD:
		return
	health -= amount
	_hp_bar.set_ratio(float(health) / max_health)
	Fx.hit_flash(_visual)
	velocity += Vector3(signf(global_position.x - from_position.x) * 2.0, 1.5, 0)
	if health <= 0:
		_die()


## A glob of something, lobbed down at him. It is a real Projectile3D, which
## means the spoon can bat it back.
## The player, regardless of range — `_acquire_target()` answers a different
## question (is he close enough to dive at?).
func _nearest_player() -> Node3D:
	for node in get_tree().get_nodes_in_group("player"):
		return node
	return null


func _spit_at(mark: Node3D) -> void:
	var glob := Projectile3D.new()
	glob.damage = spit_damage
	glob.speed = spit_speed
	glob.fall_rate = 5.0
	glob.lifetime = 3.0
	glob.damage_cause = "spit"
	glob.hits = 1 | 2 # world and the PLAYER, until somebody turns it around
	var blob := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.3
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := Block3D.flat_material(Color(0.6, 0.85, 0.35))
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.85, 0.3)
	mat.emission_energy_multiplier = 0.8
	mesh.material = mat
	blob.mesh = mesh
	glob.set_visual(blob)
	get_parent().add_child(glob)
	var toward := (mark.global_position - global_position).normalized()
	glob.launch(global_position + toward * 0.5, toward, 1.0)
	Snd.sfx("sizzle", -8.0, 0.3)


func _die() -> void:
	state = State.DEAD
	set_physics_process(false)
	($CollisionShape3D as CollisionShape3D).set_deferred("disabled", true)
	_hitbox.set_deferred("monitoring", false)
	Fx.ghost(get_parent(), global_position, 0.7, 6)
	Snd.sfx("splat", -6.0)
	FoodBurst.spawn(get_parent(), global_position, 2)
	_drop_reward()
	# Wings cut out: it stalls, tips over and drops. A flier's death should be
	# the fall itself, not a shrink-and-fade.
	var tween := create_tween()
	tween.tween_property(_visual, "rotation:z", 2.4, 0.5)
	tween.parallel().tween_property(self, "position:y", position.y - 2.6, 0.5
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(self, "position:x",
		position.x + randf_range(-0.7, 0.7), 0.5)
	tween.tween_property(self, "scale", Vector3(1.3, 0.25, 1.3), 0.12)
	tween.tween_callback(queue_free)


func _drop_reward() -> void:
	if drop_kind == "none":
		return
	var reward := RewardPickup3D.new()
	reward.kind = drop_kind
	reward.amount = drop_amount
	get_parent().add_child(reward)
	reward.global_position = global_position


## Interrupted by Harry's antennae pulse. NO damage on purpose: the pulse has a
## 9 unit radius and no aiming, so anything that hurt would out-range all nine
## weapons and become the only attack worth pressing. What it buys is a moment,
## which is what makes it worth having when something is already on top of you.
func stagger(duration: float) -> void:
	if state == State.DEAD:
		return
	_stagger_timer = maxf(_stagger_timer, duration)
	Fx.hit_flash(_visual, Color(0.75, 1.0, 0.9), 0.18)
