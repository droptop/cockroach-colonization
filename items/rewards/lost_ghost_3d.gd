class_name LostGhost3D
extends Area3D

## What Harry dropped when he died, hovering where he fell.
##
## The soul rises out of him and then STAYS, holding the crumbs, fruit and
## bulk he had. Walk back to it and you get them; die again on the way and the
## old one is gone — there is only ever one, so a bad run compounds.
##
## It carries `fullness` as well as the counts, deliberately. Dying resets his
## weight, and weight now buys knockback resistance and damage as well as
## costing speed; if recovery handed back the score but not the bulk, dying
## would be a free way to shed the downside and keep the upside.

@export var crumbs := 0
@export var fruit := 0
@export var fullness := 0.0
@export var rise := 1.4
@export var rise_time := 1.1

var _time := 0.0
var _settled := false
var _visual: Node3D


func _ready() -> void:
	collision_layer = 16 # pickup
	collision_mask = 2 # player
	monitorable = false
	_time = randf() * TAU
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.55
	shape.shape = sphere
	add_child(shape)

	_visual = Node3D.new()
	_visual.set_script(load("res://player/roach_visual_3d.gd"))
	_visual.shell_color = Color(0.85, 0.95, 1.0, 0.5)
	_visual.body_color = Color(0.92, 0.97, 1.0, 0.5)
	_visual.blush_color = Color(0.8, 0.9, 1.0, 0.35)
	add_child(_visual)
	_visual.scale = Vector3.ONE * 0.85

	body_entered.connect(_on_body_entered)
	# Drifts up out of the body, then hangs there waiting.
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y + rise, rise_time
		).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _settled = true)


func _process(delta: float) -> void:
	_time += delta
	_visual.rotation.y += delta * 0.9
	if _settled:
		_visual.position.y = sin(_time * 1.8) * 0.12


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("recover_lost"):
		return
	body.recover_lost(crumbs, fruit, fullness)
	Snd.sfx("complete", -4.0)
	Fx.impact_text(get_parent(), global_position, Color(0.8, 0.95, 1.0),
		"GOT IT BACK!", 0.8)
	Fx.spark_burst(get_parent(), global_position, Color(0.8, 0.95, 1.0))
	queue_free()


## Anything worth coming back for? A ghost holding nothing should just fade.
func has_anything() -> bool:
	return crumbs > 0 or fruit > 0 or fullness > 0.01
