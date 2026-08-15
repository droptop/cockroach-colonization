extends BaseBoss3D

## THE RAT — a huge boss guarding the pantry. Paces its patch of floor; when
## Harry gets close it either rears up and CHARGES across the arena or leaps
## and body-slams. Tanky, hits hard, and very hard to just run past.
##
## Health, the arena and the engaged/defeated signals come from BaseBoss3D;
## everything below is the rat's own — its FSM is what makes it the rat.

enum State { PACE, WINDUP, CHARGE, LEAP_WINDUP, LEAP, RECOVER, DEAD }

@export var pace_speed := 1.3
@export var charge_speed := 7.5
@export var leap_velocity := Vector2(5.0, 7.5)
@export var detect_range := 6.5
@export var attack_cooldown := 1.6
@export var contact_damage := 2
@export var gravity := 26.0

var state := State.PACE

var _pace_dir := 1
var _attack_dir := 1.0
var _timer := 0.0
var _cooldown := 0.0
var _target: Node3D

@onready var _visual: Node3D = $Visual
@onready var _hitbox: Area3D = $Hitbox
@onready var _health_label: Label3D = $HealthLabel


var _hp_bar: EnemyHealthBar


func _ready() -> void:
	super()
	_hp_bar = EnemyHealthBar.new()
	_hp_bar.position = Vector3(0, 2.35, 0)
	_hp_bar.scale = Vector3.ONE * 2.2
	add_child(_hp_bar)
	_update_health_label()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_on_floor():
		velocity.y = maxf(velocity.y - gravity * delta, -20.0)
	if global_position.y < -4.0:
		# Never let the boss end up in the void — snap back to its arena.
		global_position = arena_origin
		velocity = Vector3.ZERO
		state = State.PACE
	_cooldown = maxf(_cooldown - delta, 0.0)
	_timer -= delta

	match state:
		State.PACE:
			velocity.x = _pace_dir * pace_speed
			var past := (_pace_dir > 0 and global_position.x >= arena_origin.x + arena_half_width) \
				or (_pace_dir < 0 and global_position.x <= arena_origin.x - arena_half_width)
			if past or is_on_wall():
				_pace_dir = -_pace_dir
			if _cooldown <= 0.0 and _acquire_target():
				engage() # spotting Harry starts the fight, not just being hit
				var dx: float = _target.global_position.x - global_position.x
				_attack_dir = signf(dx) if dx != 0.0 else 1.0
				_visual.scale.x = _attack_dir
				if absf(dx) > 3.0:
					state = State.WINDUP
				else:
					state = State.LEAP_WINDUP
				_timer = 0.55
				Snd.sfx("squeak")
				if _visual.has_method("set_rearing"):
					_visual.set_rearing(true)
		State.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			if _timer <= 0.0:
				state = State.CHARGE
				_timer = 1.4
				Snd.sfx("thud")
				if _visual.has_method("set_rearing"):
					_visual.set_rearing(false)
		State.CHARGE:
			velocity.x = _attack_dir * charge_speed
			var beyond := absf(global_position.x - arena_origin.x) > arena_half_width + 1.5
			if _timer <= 0.0 or is_on_wall() or beyond:
				_end_attack()
		State.LEAP_WINDUP:
			velocity.x = 0.0
			if _timer <= 0.0:
				state = State.LEAP
				velocity = Vector3(_attack_dir * leap_velocity.x, leap_velocity.y, 0)
				if _visual.has_method("set_rearing"):
					_visual.set_rearing(false)
		State.LEAP:
			if is_on_floor() and velocity.y <= 0.0:
				Snd.sfx("thud", 2.0)
				_end_attack()
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
			if _timer <= 0.0:
				state = State.PACE
	move_and_slide()
	if state == State.PACE and absf(velocity.x) > 0.05:
		_visual.scale.x = signf(velocity.x)
	for body in _hitbox.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(contact_damage, global_position)


func _end_attack() -> void:
	state = State.RECOVER
	_timer = 0.9
	_cooldown = attack_cooldown


func _acquire_target() -> bool:
	if not is_instance_valid(_target):
		_target = null
		for node in get_tree().get_nodes_in_group("player"):
			_target = node
			break
	return _target != null \
		and global_position.distance_to(_target.global_position) <= detect_range


## BaseBoss3D owns the health bookkeeping and the signals; this is the rat's
## reaction to being hit.
func _on_damaged(_amount: int, from_position: Vector3) -> void:
	_hp_bar.set_ratio(float(health) / max_health)
	Fx.spark_burst(get_parent(), from_position.lerp(global_position, 0.5) + Vector3(0, 1.0, 0))
	Snd.sfx("squeak", -4.0)
	velocity.x += signf(global_position.x - from_position.x) * 0.8


func _update_health_label() -> void:
	_health_label.text = "THE RAT"


func _on_defeated() -> void:
	state = State.DEAD
	Snd.sfx("squeak", 4.0)
	Snd.sfx("thud")
	set_physics_process(false)
	($CollisionShape3D as CollisionShape3D).set_deferred("disabled", true)
	_hitbox.set_deferred("monitoring", false)
	_health_label.text = "squeeeak!!"
	_hp_bar.visible = false
	Fx.ghost(get_parent(), global_position + Vector3(0, 1.0, 0), 2.2)
	# Drop a fruit feast and his crown, then scurry away into the background.
	var fruit_scene: PackedScene = load("res://items/food/fruit_3d.tscn")
	for offset in [-1.2, 0.0, 1.2]:
		var fruit := fruit_scene.instantiate()
		get_parent().add_child(fruit)
		fruit.global_position = global_position + Vector3(offset, 1.2, 0)
	var crown_scene: PackedScene = load("res://items/trophies/crown_3d.tscn")
	var crown := crown_scene.instantiate()
	get_parent().add_child(crown)
	crown.global_position = global_position + Vector3(0, 1.6, 0)
	var tween := create_tween()
	tween.tween_property(self, "rotation:y", -PI / 2 * signf(_visual.scale.x), 0.3)
	tween.tween_property(self, "position:z", position.z - 8.0, 1.2).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "scale", Vector3.ONE * 0.4, 1.2)
	tween.tween_callback(queue_free)
