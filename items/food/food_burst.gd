class_name FoodBurst
extends Object

## A fountain of food out of something that just died.
##
## Static rather than a scene, like Fx: the caller is a dying enemy that is
## about to free itself, so the burst must not be parented to it.
##
## Burst food does NOT respawn. The pickups placed around a level regrow on a
## timer so the player can always refuel, but a kill that regrew its own reward
## every twelve seconds would make one respawning enemy an unlimited larder.

const CRUMB := preload("res://items/food/food_crumb_3d.tscn")
const FRUIT := preload("res://items/food/fruit_3d.tscn")
const COIN := preload("res://items/rewards/coin_3d.tscn")


## `origin` is where the thing died. Spread scales with the count so a boss
## throws its food wider than an ant does. Coins ride the same fountain — they
## are how money enters the game (BACKLOG item 22), and a separate coin burst
## would be a second implementation of this one waiting to drift.
static func spawn(parent: Node, origin: Vector3, crumbs: int, fruit := 0, coins := 0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var total := crumbs + fruit + coins
	if total <= 0:
		return
	var spread: float = clampf(0.7 + total * 0.22, 0.7, 3.2)
	var index := 0
	for i in crumbs:
		_launch(parent, CRUMB, origin, index, total, spread)
		index += 1
	for i in fruit:
		_launch(parent, FRUIT, origin, index, total, spread)
		index += 1
	for i in coins:
		_launch(parent, COIN, origin, index, total, spread)
		index += 1


static func _launch(parent: Node, scene: PackedScene, origin: Vector3,
		index: int, total: int, spread: float) -> void:
	var item := scene.instantiate()
	# One-shot: see the note above about respawning kills.
	if "respawn_seconds" in item:
		item.respawn_seconds = 0.0
	parent.add_child(item)
	if not (item is Node3D):
		return
	var node := item as Node3D
	node.global_position = origin

	# Fan them across the arc rather than at random, so a burst never happens to
	# stack every piece on one spot.
	var t: float = (float(index) + 0.5) / float(total)
	var dx: float = lerpf(-spread, spread, t) + randf_range(-0.18, 0.18)
	var peak := origin + Vector3(dx * 0.55, randf_range(1.1, 1.9), 0.0)
	var land := origin + Vector3(dx, randf_range(-0.45, -0.1), 0.0)

	var tween := node.create_tween()
	tween.tween_property(node, "global_position", peak, 0.22
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(node, "global_position", land, 0.3
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# The pickups bob around a base height captured in their own _ready, which
	# ran back at the origin. Without this they bob around where they were
	# thrown FROM and drift back up through the floor.
	tween.tween_callback(func() -> void:
		if is_instance_valid(node) and "_base_y" in node:
			node._base_y = node.position.y)
