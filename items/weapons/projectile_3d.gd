class_name Projectile3D
extends Node3D

## Something thrown. The project's first ranged anything.
##
## It sweeps a ray from where it was to where it is going, every physics frame,
## rather than sitting in an Area3D and waiting to be told. That is both more
## robust — a fast shot cannot tunnel through a thin wall between frames — and
## simpler than reasoning about area monitoring, which reported zero overlaps
## here whatever the layers said.
##
## Damage still travels through the same duck-typed `take_damage` every melee
## hit uses, so a projectile is a different delivery for the existing combat
## system rather than a second one.

@export var damage := 1
@export var speed := 14.0
## Not `gravity`: that name is taken on several node types and the collision is
## easy to hit by accident.
@export var fall_rate := 9.0
@export var lifetime := 2.5
@export var spin := 14.0
## Passed to the victim so a death by rubber band says so.
@export var damage_cause := "shot"
## World is layer 1, enemies are layer 3. It stops on either.
@export_flags_3d_physics var hits := 1 | 4

var velocity := Vector3.ZERO

var _life := 0.0
var _spent := false
var _visual: Node3D


func _ready() -> void:
	_life = lifetime


## Given its look after construction — the launcher decides what was thrown.
func set_visual(node: Node3D) -> void:
	_visual = node
	add_child(node)


func launch(from: Vector3, direction: Vector3, power := 1.0) -> void:
	global_position = from
	velocity = direction.normalized() * speed * power


## Batted back the way it came. It keeps its speed, gains a little damage for
## the timing, and swaps who it is looking for — a shot you turned around has
## to be able to hurt the thing that fired it, or reflecting is just dodging
## with extra steps.
func reflect(by_facing: int, bonus := 1) -> void:
	velocity.x = absf(velocity.x) * signf(float(by_facing))
	if is_equal_approx(velocity.x, 0.0):
		velocity.x = speed * signf(float(by_facing))
	velocity.y = maxf(velocity.y, 1.5)
	damage += bonus
	hits = 1 | 4 # world and enemies now, rather than world and the player
	_life = maxf(_life, lifetime * 0.75)
	Snd.sfx("impact_light", 2.0, 0.2)
	Fx.impact_text(get_parent(), global_position, Color(0.7, 0.95, 1.0), "RETURN!", 0.7)


func _physics_process(delta: float) -> void:
	if _spent:
		return
	_life -= delta
	if _life <= 0.0:
		_spent = true
		queue_free() # ran out of air: no spark, it just drops out of the world
		return
	velocity.y -= fall_rate * delta
	var from := global_position
	var to := from + velocity * delta
	if _visual:
		_visual.rotation.z -= spin * delta

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, hits)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		return
	global_position = hit.position
	var struck: Object = hit.collider
	if struck and struck.has_method("take_damage"):
		struck.take_damage(damage, global_position, damage_cause)
		Fx.impact(get_parent(), global_position, damage)
	else:
		# Scenery. It stops there.
		Fx.spark_burst(get_parent(), global_position, Color(0.9, 0.85, 0.6))
	_spent = true
	queue_free()
