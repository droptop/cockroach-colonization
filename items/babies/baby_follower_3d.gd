class_name BabyFollower3D
extends Node3D

## A hatched baby roach trailing after Harry.
##
## Deliberately NOT a physics body. The brief asks that the baby never block or
## overlap the player, and the cheapest way to guarantee that is for it to have
## no collision at all — it cannot shove Harry off a ledge, cannot wedge itself
## in a doorway, and cannot trip a hazard meant for him.
##
## It follows the breadcrumb trail Harry actually walked (see
## `Player3D.trail_point`) rather than his current position, so it rounds
## corners and drops off ledges the same way he did instead of cutting across
## geometry in a straight line.

## Metres back along the trail per slot, so a queue of babies spaces out.
@export var trail_spacing := 0.85
@export var follow_speed := 6.5
## Beyond this it stops ambling and hurries.
@export var catch_up_distance := 2.2
@export var catch_up_speed := 12.0
## Held further than this for `stuck_time`, it gives up and teleports. Level
## geometry WILL strand a follower eventually; the recovery is not optional.
@export var teleport_distance := 6.0
@export var stuck_time := 1.5

var slot := 0
var player: Node3D

var _stuck := 0.0
var _time := 0.0
var _visual: Node3D


func _ready() -> void:
	_time = randf() * TAU
	_visual = Node3D.new()
	# A CHEAP visual, not the player's. Banked babies follow you into every
	# level and are all on screen at once: eight of them wearing the full player
	# model added 184 draw calls and took the tabletop to nearly twice its
	# budget, so the game got heavier the better you had played.
	_visual.set_script(load("res://items/babies/baby_visual_3d.gd"))
	_visual.shell_color = Color(0.85, 0.75, 0.65)
	_visual.body_color = Color(0.96, 0.93, 0.88)
	add_child(_visual)
	_visual.scale = Vector3.ONE * 0.4


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_time += delta
	var target: Vector3 = player.trail_point(trail_spacing * (slot + 1))
	var distance := global_position.distance_to(target)
	var speed := catch_up_speed if distance > catch_up_distance else follow_speed
	global_position = global_position.move_toward(target, speed * delta)

	# Stuck recovery: only after being far away for a sustained stretch, so a
	# long jump or a lift never teleports it and spoils the illusion.
	if distance > teleport_distance:
		_stuck += delta
		if _stuck >= stuck_time:
			global_position = player.global_position
			_stuck = 0.0
	else:
		_stuck = 0.0

	# Face the way it's heading, and bob along.
	var dx := target.x - global_position.x
	if absf(dx) > 0.02:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, 0.0 if dx > 0.0 else PI,
			minf(12.0 * delta, 1.0))
	_visual.position.y = absf(sin(_time * 9.0)) * 0.06


## Puff away when Harry dies — the babies are lost with him.
func vanish() -> void:
	Fx.ghost(get_parent(), global_position, 0.35)
	queue_free()
