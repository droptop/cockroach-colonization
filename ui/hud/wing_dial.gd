extends Control

## Wing-energy gauge: 270-degree dial with a needle. Drains while flying,
## refills from food. Turns red when empty.

const START_ANGLE := PI * 0.75
const SWEEP := PI * 1.5

var _ratio := 1.0
var _empty := false


func set_energy(current: float, max_value: float) -> void:
	_ratio = clampf(current / maxf(max_value, 0.001), 0.0, 1.0)
	_empty = current <= 0.5
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 5.0
	# Background arc.
	draw_arc(center, radius, START_ANGLE, START_ANGLE + SWEEP, 32, Color(0.22, 0.22, 0.28, 0.9), 7.0, true)
	# Energy arc.
	if _ratio > 0.01:
		var color := Color(0.45, 0.85, 0.95) if not _empty else Color(0.75, 0.3, 0.25)
		draw_arc(center, radius, START_ANGLE, START_ANGLE + SWEEP * _ratio, 32, color, 7.0, true)
	# Needle.
	var angle := START_ANGLE + SWEEP * _ratio
	var tip := center + Vector2(cos(angle), sin(angle)) * (radius - 1.0)
	draw_line(center, tip, Color(0.95, 0.95, 1.0), 2.0, true)
	draw_circle(center, 3.0, Color(0.95, 0.95, 1.0))
	if _empty:
		draw_circle(center, radius * 0.35, Color(0.75, 0.3, 0.25, 0.35))
