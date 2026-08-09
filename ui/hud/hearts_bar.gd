extends Control

## Row of hearts for Harry's life. Full hearts are red; lost ones stay as
## dark sockets. Drawn by hand so we don't depend on font glyphs (the web
## build's default font lacks the heart character).

const HEART_SPACING := 30.0
const HEART_SIZE := 10.0

var _current := 5
var _max := 5


func set_health(current: int, max_value: int) -> void:
	_current = current
	_max = max_value
	queue_redraw()


func _draw() -> void:
	for i in _max:
		var center := Vector2(14.0 + i * HEART_SPACING, 14.0)
		var filled := i < _current
		var color := Color(0.9, 0.22, 0.3) if filled else Color(0.25, 0.22, 0.28, 0.9)
		_draw_heart(center, HEART_SIZE, color)
		if filled:
			# little shine
			draw_circle(center + Vector2(-3.5, -4.5), 1.6, Color(1, 1, 1, 0.55))


func _draw_heart(center: Vector2, size: float, color: Color) -> void:
	var r := size * 0.5
	draw_circle(center + Vector2(-r * 0.9, -r * 0.6), r, color)
	draw_circle(center + Vector2(r * 0.9, -r * 0.6), r, color)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-size * 0.92, -size * 0.1),
		center + Vector2(size * 0.92, -size * 0.1),
		center + Vector2(0, size * 1.05),
	]), color)
