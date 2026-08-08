extends ColorRect

## On touch devices in portrait, dim the game and ask for landscape.


func _ready() -> void:
	visible = false
	if not DisplayServer.is_touchscreen_available():
		return
	get_viewport().size_changed.connect(_check_orientation)
	_check_orientation()


func _check_orientation() -> void:
	var s := get_viewport().get_visible_rect().size
	visible = s.y > s.x
