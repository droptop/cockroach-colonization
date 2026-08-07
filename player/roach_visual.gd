@tool
extends Node2D

## Placeholder Harry: oval body, head, six legs, antennae.
## Drawn facing +X; Player flips this node's scale.x to turn around.

@export var body_color := Color(0.32, 0.2, 0.12)
@export var accent_color := Color(0.55, 0.35, 0.18)


func _draw() -> void:
	# Six little legs under the body.
	for i in 6:
		var x := -10.0 + i * 4.0
		var splay := -3.0 if i % 2 == 0 else 3.0
		draw_line(Vector2(x, 4.0), Vector2(x + splay, 10.0), accent_color, 1.5)
	# Body (ellipse as polygon).
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * i / 24.0
		points.append(Vector2(cos(angle) * 13.0, sin(angle) * 7.0))
	draw_colored_polygon(points, body_color)
	# Head + eye.
	draw_circle(Vector2(11.0, -1.0), 4.5, accent_color)
	draw_circle(Vector2(12.5, -2.0), 1.6, Color.BLACK)
	draw_circle(Vector2(13.0, -2.5), 0.6, Color.WHITE)
	# Antennae.
	draw_line(Vector2(13.0, -4.0), Vector2(22.0, -12.0), accent_color, 1.2)
	draw_line(Vector2(13.0, -4.0), Vector2(24.0, -7.0), accent_color, 1.2)
