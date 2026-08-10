extends Area3D

## A shield lying around a level: the bottle cap (street) or the frying pan
## (kitchen). Same effect either way (collect_shield halves damage) — the
## kind only changes the mesh and how the player wears/holds it.

@export var shield_kind := "cap"
## 0 = never respawns.
@export var respawn_seconds := 14.0

var _time := 0.0
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)
	add_child(WeaponVisuals.build_shield(shield_kind))


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 2.6) * 0.07
	rotation.y += delta * 1.0


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("collect_shield"):
		return
	body.collect_shield(shield_kind)
	Snd.sfx("crumb")
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.6, 0.12)
	tween.parallel().tween_property(self, "position:y", position.y + 0.3, 0.12)
	tween.tween_callback(_after_taken)


func _after_taken() -> void:
	if respawn_seconds <= 0.0:
		queue_free()
		return
	visible = false
	await get_tree().create_timer(respawn_seconds).timeout
	scale = Vector3.ONE
	position.y = _base_y
	visible = true
	set_deferred("monitoring", true)
