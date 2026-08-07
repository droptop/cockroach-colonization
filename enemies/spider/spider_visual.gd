@tool
extends Node2D

## Placeholder spider: two body segments, eight legs, mean little eyes.
## Drawn facing +X; spider.gd flips scale.x with movement direction.

@export var body_color := Color(0.2, 0.12, 0.22)
@export var leg_color := Color(0.3, 0.2, 0.32)
@export var eye_color := Color(0.9, 0.15, 0.1)


func _draw() -> void:
	# Eight legs, four per side, arched.
	for i in 4:
		var x := -8.0 + i * 5.0
		draw_line(Vector2(x, 0.0), Vector2(x - 7.0, -8.0), leg_color, 1.6)
		draw_line(Vector2(x - 7.0, -8.0), Vector2(x - 11.0, 8.0), leg_color, 1.6)
		draw_line(Vector2(x, 0.0), Vector2(x + 7.0, -8.0), leg_color, 1.6)
		draw_line(Vector2(x + 7.0, -8.0), Vector2(x + 11.0, 8.0), leg_color, 1.6)
	# Abdomen + head.
	draw_circle(Vector2(-6.0, -2.0), 9.0, body_color)
	draw_circle(Vector2(6.0, 0.0), 6.0, body_color)
	# Eyes.
	draw_circle(Vector2(9.0, -2.0), 1.5, eye_color)
	draw_circle(Vector2(11.0, -1.0), 1.1, eye_color)
