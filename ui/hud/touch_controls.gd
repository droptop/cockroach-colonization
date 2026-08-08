extends Control

## Touchscreen controls (phones/tablets, landscape):
## - hold the LEFT half of the screen  -> run left
## - hold the RIGHT half of the screen -> run right
## - hold BOTH halves                  -> jump; keep holding -> fly
## Feeds the same input actions as the keyboard, so the player code is unchanged.

var _touch_sides := {} # touch index -> "L" / "R"
var _left := false
var _right := false
var _jump := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not DisplayServer.is_touchscreen_available():
		visible = false
		set_process_input(false)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_sides[event.index] = _side_for(event.position)
		else:
			_touch_sides.erase(event.index)
		_recompute()
	elif event is InputEventScreenDrag:
		var side := _side_for(event.position)
		if _touch_sides.get(event.index, "") != side:
			_touch_sides[event.index] = side
			_recompute()


func _side_for(pos: Vector2) -> String:
	return "L" if pos.x < get_viewport_rect().size.x / 2.0 else "R"


func _recompute() -> void:
	var left := false
	var right := false
	for side in _touch_sides.values():
		if side == "L":
			left = true
		else:
			right = true
	if left != _left:
		_left = left
		if left:
			Input.action_press("move_left")
		else:
			Input.action_release("move_left")
	if right != _right:
		_right = right
		if right:
			Input.action_press("move_right")
		else:
			Input.action_release("move_right")
	# Both sides held = jump / fly. (Left+right cancel out, so Harry rises straight up.)
	var both := left and right
	if both != _jump:
		_jump = both
		if both:
			Input.action_press("jump")
		else:
			Input.action_release("jump")
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var s := size
	var y := s.y - 70.0
	# Left / right hold hints, brighter while held.
	var left_col := Color(1, 1, 1, 0.5 if _left else 0.18)
	var right_col := Color(1, 1, 1, 0.5 if _right else 0.18)
	draw_colored_polygon(PackedVector2Array([
		Vector2(60, y), Vector2(96, y - 24), Vector2(96, y + 24)]), left_col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(s.x - 60, y), Vector2(s.x - 96, y - 24), Vector2(s.x - 96, y + 24)]), right_col)
	if _jump:
		var up_col := Color(0.6, 0.9, 1.0, 0.55)
		draw_colored_polygon(PackedVector2Array([
			Vector2(s.x / 2.0, y - 30), Vector2(s.x / 2.0 - 26, y + 10), Vector2(s.x / 2.0 + 26, y + 10)]), up_col)
