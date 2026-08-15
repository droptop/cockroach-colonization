class_name Player3D
extends CharacterBody3D

## Harry in 3D: same movement feel as the 2D controller, ported to metres and
## +Y-up. Motion is locked to the X/Y plane (axis_lock_linear_z) so gameplay
## stays a side-scrolling platformer inside a 3D world.

signal health_changed(current: float, max_value: int)
signal food_changed(count: int)
signal wing_energy_changed(current: float, max_value: float)
signal fruit_changed(count: int)
signal babies_changed(carried: int)
signal growth_stage_changed(stage: int)
signal weapon_changed(id: String)
signal shield_changed(equipped: bool)
## Emitted on every hit that lands. `blocked` means a shield ate half of it —
## the HUD tints the screen differently for the two.
signal damaged(amount: int, blocked: bool)
signal died
signal respawned

@export_group("Run")
@export var run_speed := 4.5
@export var ground_acceleration := 45.0
@export var ground_deceleration := 55.0
@export var air_acceleration := 30.0
@export var air_deceleration := 18.0

@export_group("Jump")
@export var gravity := 26.0
@export var max_fall_speed := 18.0
@export var jump_velocity := 8.8
## Upward velocity is multiplied by this when jump is released early (variable height).
@export_range(0.0, 1.0) var jump_cut_multiplier := 0.45
@export var coyote_time := 0.10
@export var jump_buffer_time := 0.12

@export_group("Wall")
@export var wall_slide_speed := 2.2
## Upward speed while climbing (holding toward the wall + Space).
@export var wall_climb_speed := 2.8
## x = push away from wall, y = upward kick.
@export var wall_jump_velocity := Vector2(4.8, 7.6)
@export var wall_jump_lockout := 0.12

@export_group("Wings")
@export var max_wing_energy := 100.0
@export var wing_drain_rate := 14.0
## Energy knocked off the wing bar by ANY hit (enemies, bosses, toxic sludge).
@export var wing_hit_cost := 18.0
## Upward speed flight sustains while Space is held. Deliberately modest so
## flight is a tool, not a way to skip the whole level.
@export var fly_up_speed := 3.2
## Must comfortably exceed gravity (26) or flight can't sustain height.
@export var fly_acceleration := 44.0
## Energy needed before wings re-engage after running completely dry.
@export var wing_reengage_threshold := 8.0

@export_group("Growth")
## Fullness gained per food unit (crumb = 1 unit, fruit = 2). Being full makes
## Harry bigger, slower, and worse at flying — eat for score, stay light to move.
@export var growth_per_food := 0.06
@export var growth_run_penalty := 0.35
@export var growth_fly_penalty := 0.4
@export var growth_jump_penalty := 0.12

@export_group("Dash")
@export var dash_speed := 9.0
@export var dash_duration := 0.16
@export var dash_cooldown := 0.35

@export_group("Combat")
@export var max_health := 5
@export var bite_damage := 1
@export var bite_cooldown := 0.3
@export var invincibility_time := 0.8
@export var hurt_knockback := Vector2(3.6, 4.6)
@export var respawn_delay := 2.2

## Per-weapon attack tuning. "bite" is the default, always-available attack;
## everything else is unlocked by picking up the matching item. reach_scale
## multiplies the BiteArea's base local x-offset (0.5).
const WEAPON_STATS := {
	"bite": {"damage": 1, "cooldown": 0.3, "reach_scale": 1.0, "label": "BITE", "color": Color(0.9, 0.95, 1.0)},
	"pin": {"damage": 1, "cooldown": 0.18, "reach_scale": 1.0, "label": "PIN", "color": Color(0.75, 0.78, 0.82)},
	"fork": {"damage": 2, "cooldown": 0.35, "reach_scale": 1.25, "label": "FORK", "color": Color(0.8, 0.82, 0.86)},
	"knife": {"damage": 2, "cooldown": 0.28, "reach_scale": 1.1, "label": "KNIFE", "color": Color(0.85, 0.87, 0.9)},
	"broken_bottle": {"damage": 2, "cooldown": 0.3, "reach_scale": 1.0, "label": "BROKEN BOTTLE", "color": Color(0.4, 0.65, 0.45)},
}

var health := 5.0
var food := 0
var fruit_count := 0
var fullness := 0.0
var carried_babies: Array[Node3D] = []
var _growth_stage := 0
var collected_weapons: Array[String] = ["bite"]
var has_shield := false
var shield_kind := "cap"
var _weapon_index := 0
var wing_energy := 100.0
var is_flying := false
var is_climbing := false
var facing := 1
var _wings_spent := false
var _step_timer := 0.0
## Set every frame by any hazard the player is standing in (e.g. an
## insecticide cloud); cleared at the end of _physics_process, so it only
## persists while a hazard keeps re-applying it.
var _external_slow := 0.0
var spawn_position := Vector3.ZERO
var is_dead := false
var dash_ready: bool:
	get: return _dash_available and _dash_cooldown_timer <= 0.0

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _wall_jump_lockout_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _dash_available := true
var _bite_cooldown_timer := 0.0
var _invincibility_timer := 0.0
var _was_on_floor := false
var _squash := Vector2.ONE

@onready var _visual: Node3D = $Visual
@onready var _bite_area: Area3D = $Visual/BiteArea
@onready var _collision: CollisionShape3D = $CollisionShape3D

const _BITE_AREA_BASE_X := 0.5
## Rest pose for the held-weapon pivot: angled 45° forward from the grip.
const _WEAPON_REST_ROTATION_Z := -PI / 4
var _weapon_pivot: Node3D
var _weapon_mesh: Node3D
var _weapon_swing_tween: Tween
var _shield_halo: Node3D
var _shield_pan: Node3D

var active_weapon: String:
	get: return collected_weapons[_weapon_index]


func _ready() -> void:
	health = max_health
	wing_energy = max_wing_energy
	spawn_position = global_position
	_build_weapon_visuals()
	_apply_weapon_reach()
	health_changed.emit(health, max_health)
	food_changed.emit(food)
	wing_energy_changed.emit(wing_energy, max_wing_energy)
	weapon_changed.emit(active_weapon)
	shield_changed.emit(has_shield)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_tick_timers(delta)
	var direction := Input.get_axis("move_left", "move_right")

	if _dash_timer > 0.0:
		velocity.y = 0.0 # dash ignores gravity for its whole duration
	else:
		_apply_gravity(direction, delta)
		_update_climb(direction)
		_handle_jump()
		_apply_flight(delta)
		_apply_run(direction, delta)
		_handle_dash_input(direction)
	_handle_weapon_cycle()
	_handle_attack()

	move_and_slide()

	if is_on_floor() and not _was_on_floor:
		_squash = Vector2(1.3, 0.7) # landing squash
	_was_on_floor = is_on_floor()

	Snd.wings(is_flying and not is_dead)
	_update_footsteps(delta)
	_update_visual(direction, delta)
	_external_slow = 0.0


func _update_footsteps(delta: float) -> void:
	var stepping := (is_on_floor() and absf(velocity.x) > 2.0) or (is_climbing and velocity.y > 0.5)
	if not stepping:
		_step_timer = 0.0
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = 0.3 if is_climbing else 0.22
		Snd.sfx("step", -6.0, 0.2)


func _tick_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
		_dash_available = true
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_wall_jump_lockout_timer = maxf(_wall_jump_lockout_timer - delta, 0.0)
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_bite_cooldown_timer = maxf(_bite_cooldown_timer - delta, 0.0)
	_invincibility_timer = maxf(_invincibility_timer - delta, 0.0)


func _apply_gravity(direction: float, delta: float) -> void:
	if is_on_floor():
		return
	velocity.y = maxf(velocity.y - gravity * delta, -max_fall_speed)
	# Wall slide only while actively pushing into the wall, so letting go drops cleanly.
	if is_on_wall_only() and direction != 0.0 and velocity.y < 0.0:
		velocity.y = maxf(velocity.y, -wall_slide_speed)


func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	if _jump_buffer_timer > 0.0:
		if is_on_floor() or _coyote_timer > 0.0:
			velocity.y = jump_velocity * (1.0 - fullness * growth_jump_penalty)
			_jump_buffer_timer = 0.0
			_coyote_timer = 0.0
			_squash = Vector2(0.75, 1.25)
			Snd.sfx("jump")
		elif is_on_wall_only() and not is_climbing:
			# Pressing INTO the wall means climbing; wall jump fires only when
			# neutral or pressing away.
			var away := get_wall_normal().x
			velocity.x = wall_jump_velocity.x * away
			velocity.y = wall_jump_velocity.y
			_wall_jump_lockout_timer = wall_jump_lockout
			_jump_buffer_timer = 0.0
			_squash = Vector2(0.75, 1.25)
			Snd.sfx("jump", -2.0)
	if Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= jump_cut_multiplier


## Hold toward a wall + Space to climb straight up it. Free — roaches are
## born climbers; the wing bar only drains for actual flying.
func _update_climb(direction: float) -> void:
	is_climbing = false
	if direction == 0.0 or not is_on_wall() or is_on_floor():
		return
	var into_wall := signf(direction) == -signf(get_wall_normal().x)
	if into_wall and Input.is_action_pressed("jump"):
		is_climbing = true
		# Keep any bigger upward momentum (e.g. the initial jump boost).
		velocity.y = maxf(velocity.y, wall_climb_speed)


## Hold Space in the air to fly upward, draining the wing bar. When the bar
## runs dry the wings cut out and Harry drops until food refills them past the
## re-engage threshold.
func _apply_flight(delta: float) -> void:
	is_flying = false
	if is_on_floor() or is_climbing or _wings_spent or wing_energy <= 0.0:
		return
	if not Input.is_action_pressed("jump"):
		return
	# Don't fight the initial jump impulse — flight takes over once the jump
	# has decayed to flight speed.
	if velocity.y > fly_up_speed + 0.1:
		return
	is_flying = true
	var fat_fly_speed := fly_up_speed * (1.0 - fullness * growth_fly_penalty)
	velocity.y = move_toward(velocity.y, fat_fly_speed, fly_acceleration * delta)
	wing_energy = maxf(wing_energy - wing_drain_rate * delta, 0.0)
	if wing_energy <= 0.0:
		_wings_spent = true # dry — no flutter-hovering on fumes
		is_flying = false
	wing_energy_changed.emit(wing_energy, max_wing_energy)


func add_wing_energy(amount: float) -> void:
	wing_energy = clampf(wing_energy + amount, 0.0, max_wing_energy)
	if _wings_spent and wing_energy >= wing_reengage_threshold:
		_wings_spent = false
	wing_energy_changed.emit(wing_energy, max_wing_energy)


func _apply_run(direction: float, delta: float) -> void:
	if _wall_jump_lockout_timer > 0.0:
		return # keep wall-jump momentum
	var target := direction * run_speed * (1.0 - fullness * growth_run_penalty) * (1.0 - _external_slow)
	var accel: float
	if is_on_floor():
		accel = ground_acceleration if direction != 0.0 else ground_deceleration
	else:
		accel = air_acceleration if direction != 0.0 else air_deceleration
	velocity.x = move_toward(velocity.x, target, accel * delta)


func _handle_dash_input(direction: float) -> void:
	if not Input.is_action_just_pressed("dash"):
		return
	if not _dash_available or _dash_cooldown_timer > 0.0:
		return
	var dash_dir := signf(direction) if direction != 0.0 else float(facing)
	velocity = Vector3(dash_dir * dash_speed, 0.0, 0.0)
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	_dash_available = is_on_floor() # one air dash until grounded again
	_squash = Vector2(1.35, 0.65)
	Snd.sfx("whoosh")


## N/M step through whatever weapons have been collected this life ("bite" is
## always slot 0). Picking up a new weapon jumps straight to it separately
## (see collect_weapon) — this is just manual re-cycling afterward.
func _handle_weapon_cycle() -> void:
	if collected_weapons.size() <= 1:
		return
	if Input.is_action_just_pressed("next_weapon"):
		cycle_weapon(1)
	elif Input.is_action_just_pressed("prev_weapon"):
		cycle_weapon(-1)


func cycle_weapon(direction: int) -> void:
	_weapon_index = wrapi(_weapon_index + direction, 0, collected_weapons.size())
	_apply_weapon_reach()
	_update_weapon_visual()
	weapon_changed.emit(active_weapon)


## Attack with whatever's currently equipped — damage/cooldown/reach come
## from WEAPON_STATS[active_weapon]; the hit area and slash FX are shared.
func _handle_attack() -> void:
	if not Input.is_action_just_pressed("attack") or _bite_cooldown_timer > 0.0:
		return
	var stats: Dictionary = WEAPON_STATS[active_weapon]
	_bite_cooldown_timer = stats.cooldown
	_squash = Vector2(1.2, 0.9)
	Snd.sfx("bite")
	_spawn_slash()
	_swing_weapon()
	var hit_any := false
	for body in _bite_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(stats.damage, global_position)
			hit_any = true
			# One call picks word, colour, size and sparks from the damage,
			# so a bite and a knife never look like the same hit.
			Fx.impact(get_parent(), body.global_position, stats.damage)
	if hit_any:
		var camera := get_node_or_null("Camera3D")
		if camera and camera.has_method("shake"):
			camera.shake(0.14)


## Hollow-Knight-style slash arc: a white crescent flash that sweeps in front
## of Harry on every attack, hit or miss.
func _spawn_slash() -> void:
	var slash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.55
	mesh.height = 0.16
	mesh.radial_segments = 16
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.95, 1.0)
	mat.emission_energy_multiplier = 1.4
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	slash.mesh = mesh
	slash.rotation.x = PI / 2 # flat crescent facing the camera
	slash.rotation.z = 0.5
	slash.position = Vector3(0.62, 0.32, 0.1)
	slash.scale = Vector3(0.35, 1.0, 0.6)
	_visual.add_child(slash) # flips with facing
	var tween := slash.create_tween()
	tween.tween_property(slash, "scale", Vector3(1.15, 1.0, 1.0), 0.07).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slash, "rotation:z", -0.9, 0.11)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.08)
	tween.tween_callback(slash.queue_free)


## Swings the held weapon forward from its 45° rest pose in a curved hook —
## a sickle-like slap — and back, plus a small forward punch. Runs even
## when the pivot is hidden (bite); harmless, just invisible.
func _swing_weapon() -> void:
	if _weapon_swing_tween:
		_weapon_swing_tween.kill()
	_weapon_pivot.rotation.z = _WEAPON_REST_ROTATION_Z
	_weapon_pivot.position = Vector3(0.55, 0.25, 0.0)
	_weapon_swing_tween = create_tween()
	_weapon_swing_tween.tween_property(
		_weapon_pivot, "rotation:z", _WEAPON_REST_ROTATION_Z + PI * 0.7, 0.06
	).set_ease(Tween.EASE_OUT)
	_weapon_swing_tween.parallel().tween_property(
		_weapon_pivot, "position:x", 0.55 + 0.16, 0.06
	).set_ease(Tween.EASE_OUT)
	_weapon_swing_tween.tween_property(
		_weapon_pivot, "rotation:z", _WEAPON_REST_ROTATION_Z, 0.08
	).set_ease(Tween.EASE_IN)
	_weapon_swing_tween.parallel().tween_property(_weapon_pivot, "position:x", 0.55, 0.08)


## Scales the BiteArea's reach per the active weapon (fork/knife stab a
## little further out than a bite or the pin's quick jab).
func _apply_weapon_reach() -> void:
	var stats: Dictionary = WEAPON_STATS[active_weapon]
	_bite_area.position.x = _BITE_AREA_BASE_X * stats.reach_scale


## Builds the (initially hidden) held-weapon pivot and the two shield
## visuals once; meshes swap via WeaponVisuals as the loadout changes.
func _build_weapon_visuals() -> void:
	_weapon_pivot = Node3D.new()
	_weapon_pivot.position = Vector3(0.55, 0.25, 0.0)
	_weapon_pivot.scale = Vector3.ONE * 1.7
	_weapon_pivot.rotation.z = _WEAPON_REST_ROTATION_Z
	_weapon_pivot.visible = false
	_visual.add_child(_weapon_pivot)

	# Halo (bottle cap): floats above the head.
	_shield_halo = WeaponVisuals.build_shield("cap")
	_shield_halo.position = Vector3(0.0, 0.55, 0.0)
	_shield_halo.rotation.x = PI / 2
	_shield_halo.visible = false
	_visual.add_child(_shield_halo)

	# Pan: held up in front on the opposite side from the weapon pivot.
	_shield_pan = WeaponVisuals.build_shield("pan")
	_shield_pan.position = Vector3(-0.5, 0.2, 0.0)
	_shield_pan.rotation.z = PI / 5
	_shield_pan.visible = false
	_visual.add_child(_shield_pan)


func _update_weapon_visual() -> void:
	if _weapon_pivot == null:
		return
	if _weapon_mesh:
		_weapon_mesh.queue_free()
		_weapon_mesh = null
	_weapon_pivot.visible = active_weapon != "bite"
	if _weapon_pivot.visible:
		_weapon_mesh = WeaponVisuals.build_weapon(active_weapon)
		_weapon_pivot.add_child(_weapon_mesh)


func _update_shield_visual() -> void:
	if _shield_halo == null:
		return
	_shield_halo.visible = has_shield and shield_kind == "cap"
	_shield_pan.visible = has_shield and shield_kind == "pan"


## Called every frame by a hazard (e.g. an insecticide cloud) the player is
## standing in. factor is 0..1 (0.5 = half speed). Duck-typed like
## take_damage — any hazard just needs has_method("apply_slow").
func apply_slow(factor: float) -> void:
	_external_slow = maxf(_external_slow, factor)


func take_damage(amount: int, from_position: Vector3) -> void:
	if is_dead or _invincibility_timer > 0.0:
		return
	var blocked := has_shield
	var effective_damage := float(amount) * (0.5 if blocked else 1.0)
	health = clampf(health - effective_damage, 0.0, max_health)
	health_changed.emit(health, max_health)
	damaged.emit(amount, blocked)
	# A halved hit used to look exactly like a full one. Now the shield says so.
	Fx.impact(get_parent(), global_position, amount, blocked, _visual)
	# Every hit also knocks energy out of the wings (enemies, bosses, sludge).
	wing_energy = maxf(wing_energy - wing_hit_cost, 0.0)
	if wing_energy <= 0.0:
		_wings_spent = true
	wing_energy_changed.emit(wing_energy, max_wing_energy)
	_invincibility_timer = invincibility_time
	var away := signf(global_position.x - from_position.x)
	if away == 0.0:
		away = -float(facing)
	velocity = Vector3(hurt_knockback.x * away, hurt_knockback.y, 0.0)
	_dash_timer = 0.0
	var camera := get_node_or_null("Camera3D")
	if camera and camera.has_method("shake"):
		camera.shake(0.3)
	if health <= 0:
		_die()
	elif blocked:
		Snd.sfx("thud", 2.0, 0.15) # placeholder clang — see BACKLOG audio hooks
	else:
		Snd.sfx("hurt")


## Pits knock off one health and reset to the spawn point instead of instant death.
func fall_into_pit() -> void:
	if is_dead:
		return
	_invincibility_timer = 0.0
	take_damage(1, global_position)
	if not is_dead:
		global_position = spawn_position
		velocity = Vector3.ZERO
		_invincibility_timer = invincibility_time


func collect_food(value: int) -> void:
	food += value
	food_changed.emit(food)
	_grow(value)


func collect_fruit(value: int) -> void:
	fruit_count += value
	fruit_changed.emit(fruit_count)
	_grow(value * 2)


## A weapon pickup joins the cycle and is equipped immediately.
func collect_weapon(id: String) -> void:
	if not WEAPON_STATS.has(id):
		return
	if not collected_weapons.has(id):
		collected_weapons.append(id)
	_weapon_index = collected_weapons.find(id)
	_apply_weapon_reach()
	_update_weapon_visual()
	weapon_changed.emit(active_weapon)


## A shield (bottle cap or pan): halves incoming damage per hit while
## equipped, no durability. Picking up the other kind re-skins it instead
## of being a no-op, same spirit as swapping weapons.
func collect_shield(kind: String = "cap") -> void:
	has_shield = true
	shield_kind = kind
	_update_shield_visual()
	shield_changed.emit(true)


func _grow(units: int) -> void:
	fullness = clampf(fullness + units * growth_per_food, 0.0, 1.0)
	var stage := int(fullness * 4.0) # 0..4
	if stage != _growth_stage:
		_growth_stage = stage
		growth_stage_changed.emit(stage)


## A hatched baby asks to ride on Harry's back.
func carry_baby(baby: Node3D) -> void:
	baby.ride(self, carried_babies.size())
	carried_babies.append(baby)
	babies_changed.emit(carried_babies.size())


## Called by the level exit: babies on board are delivered to safety.
func bank_babies() -> int:
	var count := carried_babies.size()
	for baby in carried_babies:
		baby.queue_free()
	carried_babies.clear()
	babies_changed.emit(0)
	return count


func _die() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	_collision.set_deferred("disabled", true)
	Snd.wings(false)
	for baby in carried_babies:
		Fx.ghost(get_parent(), baby.global_position, 0.35)
		baby.queue_free()
	carried_babies.clear()
	babies_changed.emit(0)
	Snd.sfx("death")
	died.emit()
	_spawn_death_cry()
	# "AAHH!" — little hop, keel over flat on his back, legs in the air.
	var tween := create_tween()
	tween.tween_property(_visual, "position:y", 0.5, 0.16).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_visual, "rotation:z", PI, 0.32)
	tween.tween_property(_visual, "position:y", 0.3, 0.14).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.25)
	tween.tween_callback(_spawn_ghost)
	await get_tree().create_timer(respawn_delay).timeout
	_respawn()


## Floating "AAHH!" text at the moment of death.
func _spawn_death_cry() -> void:
	var cry := Label3D.new()
	cry.text = "AAHH!"
	cry.font_size = 56
	cry.pixel_size = 0.008
	cry.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cry.modulate = Color(1, 1, 1, 0.95)
	cry.outline_size = 14
	get_parent().add_child(cry)
	cry.global_position = global_position + Vector3(0, 0.9, 0.4)
	var tween := cry.create_tween()
	tween.tween_property(cry, "position:y", cry.position.y + 0.9, 0.8).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(cry, "modulate:a", 0.0, 0.9)
	tween.tween_callback(cry.queue_free)


## White translucent ghost-Harry twirls up into the air.
func _spawn_ghost() -> void:
	var ghost := Node3D.new()
	ghost.set_script(load("res://player/roach_visual_3d.gd"))
	ghost.shell_color = Color(1, 1, 1, 0.45)
	ghost.body_color = Color(0.95, 0.98, 1, 0.45)
	ghost.blush_color = Color(1, 1, 1, 0.3)
	get_parent().add_child(ghost)
	ghost.global_position = global_position + Vector3(0, 0.25, 0)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "position:y", ghost.position.y + 3.0, 1.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ghost, "rotation:y", TAU * 2.5, 1.5)
	tween.parallel().tween_property(ghost, "scale", Vector3.ONE * 0.05, 1.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(ghost.queue_free)


func _respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	health = max_health
	food = 0
	wing_energy = max_wing_energy
	_wings_spent = false
	fullness = 0.0
	_growth_stage = 0
	is_dead = false
	_collision.set_deferred("disabled", false)
	_invincibility_timer = invincibility_time
	_visual.scale = Vector3.ONE
	_visual.rotation = Vector3.ZERO
	_visual.position = Vector3.ZERO
	_squash = Vector2.ONE
	collected_weapons = ["bite"]
	_weapon_index = 0
	has_shield = false
	shield_kind = "cap"
	_apply_weapon_reach()
	_update_weapon_visual()
	_update_shield_visual()
	health_changed.emit(health, max_health)
	food_changed.emit(food)
	wing_energy_changed.emit(wing_energy, max_wing_energy)
	weapon_changed.emit(active_weapon)
	shield_changed.emit(has_shield)
	respawned.emit()


func _update_visual(direction: float, delta: float) -> void:
	if direction != 0.0:
		facing = int(signf(direction))
	# Smoothly turn the roach around instead of snapping.
	var target_yaw := 0.0 if facing > 0 else PI
	_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, minf(14.0 * delta, 1.0))
	# Nose-up tilt while climbing a wall.
	var target_tilt := 0.55 if is_climbing else 0.0
	_visual.rotation.z = lerpf(_visual.rotation.z, target_tilt, minf(10.0 * delta, 1.0))
	_squash = _squash.lerp(Vector2.ONE, minf(12.0 * delta, 1.0))
	var girth := 1.0 + fullness * 0.5 # visible growth stage
	if _dash_timer > 0.0:
		_visual.scale = Vector3(1.35, 0.65, 1.0) * girth
	else:
		_visual.scale = Vector3(_squash.x, _squash.y, 1.0) * girth
	# Blink while invincible. Short off-beats rather than a 50/50 strobe, so he
	# reads as protected instead of as a rendering glitch, and the tail of the
	# window is solid so the moment protection ends is legible.
	if _invincibility_timer > 0.12:
		_visual.visible = fmod(_invincibility_timer, 0.12) >= 0.04
	else:
		_visual.visible = true
	if _visual.has_method("set_flying"):
		_visual.set_flying(is_flying)
