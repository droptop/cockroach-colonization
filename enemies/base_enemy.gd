class_name BaseEnemy
extends CharacterBody2D

## Shared health / damage / death behaviour for ground enemies.
## Subclasses own their movement AI and can override die().

signal enemy_died

@export var max_health := 3
@export var contact_damage := 1
@export_range(0.0, 1.0) var knockback_resistance := 0.4

var health := 1


func _ready() -> void:
	health = max_health


func take_damage(amount: int, from_position: Vector2) -> void:
	if health <= 0:
		return
	health -= amount
	_flash()
	var away := signf(global_position.x - from_position.x)
	velocity.x += away * 180.0 * (1.0 - knockback_resistance)
	velocity.y -= 60.0
	if health <= 0:
		die()


func die() -> void:
	health = 0
	enemy_died.emit()
	set_physics_process(false)
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		shape.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 0.15), 0.25)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)


func _flash() -> void:
	var visual := get_node_or_null("Visual")
	if visual == null:
		return
	visual.modulate = Color(1.0, 0.25, 0.25)
	var tween := create_tween()
	tween.tween_property(visual, "modulate", Color.WHITE, 0.18)
