extends Control

## Row of hearts for Harry's life. Full hearts are red; lost ones stay as
## dark sockets. Drawn by hand so we don't depend on font glyphs (the web
## build's default font lacks the heart character).

const HEART_SPACING := 30.0
const HEART_SIZE := 10.0

const FULL_COLOR := Color(0.9, 0.22, 0.3)
const EMPTY_COLOR := Color(0.25, 0.22, 0.28, 0.9)

var _current := 5.0
var _max := 5


## The bottle-cap shield halves damage, so hearts can sit at a .5 remainder —
## current is a float and hearts render as full/half/empty accordingly.
func set_health(current: float, max_value: int) -> void:
	_current = current
	_max = max_value
	queue_redraw()


func _draw() -> void:
	for i in _max:
		var center := Vector2(14.0 + i * HEART_SPACING, 14.0)
		var remaining := clampf(snappedf(_current - i, 0.5), 0.0, 1.0)
		if remaining >= 1.0:
			_draw_heart(center, HEART_SIZE, FULL_COLOR)
			draw_circle(center + Vector2(-3.5, -4.5), 1.6, Color(1, 1, 1, 0.55)) # little shine
		elif remaining > 0.0:
			_draw_heart_split(center, HEART_SIZE, FULL_COLOR, EMPTY_COLOR)
		else:
			_draw_heart(center, HEART_SIZE, EMPTY_COLOR)


func _draw_heart(center: Vector2, size: float, color: Color) -> void:
	var r := size * 0.5
	draw_circle(center + Vector2(-r * 0.9, -r * 0.6), r, color)
	draw_circle(center + Vector2(r * 0.9, -r * 0.6), r, color)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-size * 0.92, -size * 0.1),
		center + Vector2(size * 0.92, -size * 0.1),
		center + Vector2(0, size * 1.05),
	]), color)


## Same geometry as _draw_heart, split vertically down the centre: left lobe
## + left half of the bottom triangle in left_color, right half in right_color.
func _draw_heart_split(center: Vector2, size: float, left_color: Color, right_color: Color) -> void:
	var r := size * 0.5
	draw_circle(center + Vector2(-r * 0.9, -r * 0.6), r, left_color)
	draw_circle(center + Vector2(r * 0.9, -r * 0.6), r, right_color)
	var top_left := center + Vector2(-size * 0.92, -size * 0.1)
	var top_right := center + Vector2(size * 0.92, -size * 0.1)
	var top_mid := center + Vector2(0, -size * 0.1)
	var tip := center + Vector2(0, size * 1.05)
	draw_colored_polygon(PackedVector2Array([top_left, top_mid, tip]), left_color)
	draw_colored_polygon(PackedVector2Array([top_mid, top_right, tip]), right_color)
