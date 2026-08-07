@tool
class_name Platform
extends StaticBody2D

## Placeholder level geometry: one solid rectangle with matching collision.
## The collision shape is built in code so levels stay tiny and easy to edit.

@export var size := Vector2(200, 40):
	set(value):
		size = value
		_refresh()
@export var color := Color(0.23, 0.2, 0.27):
	set(value):
		color = value
		queue_redraw()

var _shape_node: CollisionShape2D


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	if _shape_node == null:
		_shape_node = CollisionShape2D.new()
		_shape_node.shape = RectangleShape2D.new()
		add_child(_shape_node)
	(_shape_node.shape as RectangleShape2D).size = size
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-size / 2.0, size), color)
	# Thin top highlight so walkable surfaces read at a glance.
	draw_rect(Rect2(Vector2(-size.x / 2.0, -size.y / 2.0), Vector2(size.x, 3.0)), color.lightened(0.3))
