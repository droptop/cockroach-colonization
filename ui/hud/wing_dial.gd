extends Control

## Wing-energy bar: long strip across the top middle of the screen.
## Drains while flying, refills from food. Turns red when empty.

var _ratio := 1.0
var _empty := false


func set_energy(current: float, max_value: float) -> void:
	_ratio = clampf(current / maxf(max_value, 0.001), 0.0, 1.0)
	_empty = current <= 0.5
	queue_redraw()


func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	draw_rect(full, Color(0.08, 0.08, 0.13, 0.85))
	draw_rect(full, Color(0.55, 0.6, 0.7, 0.9), false, 2.0)
	var pad := 3.0
	var fill_width := (size.x - pad * 2.0) * _ratio
	if fill_width > 1.0:
		var color := Color(0.45, 0.85, 0.95) if not _empty else Color(0.75, 0.3, 0.25)
		draw_rect(Rect2(Vector2(pad, pad), Vector2(fill_width, size.y - pad * 2.0)), color)
	elif _empty:
		draw_rect(Rect2(Vector2(pad, pad), Vector2(size.x - pad * 2.0, size.y - pad * 2.0)),
			Color(0.75, 0.3, 0.25, 0.25))
