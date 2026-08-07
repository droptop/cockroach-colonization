extends Area2D

## A crumb. Bobs gently; anything with collect_food() eats it.

@export var value := 1
@export var crumb_color := Color(0.85, 0.68, 0.4)

var _time := 0.0
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU # desync bobbing between crumbs
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 3.0) * 2.0


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, crumb_color)
	draw_circle(Vector2(-2.0, -2.0), 2.0, crumb_color.lightened(0.3))
	draw_circle(Vector2(3.0, 2.0), 1.5, crumb_color.darkened(0.2))


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("collect_food"):
		return
	body.collect_food(value)
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.12)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.12)
	tween.tween_callback(queue_free)
