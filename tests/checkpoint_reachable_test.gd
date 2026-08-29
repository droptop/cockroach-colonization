extends SceneTree

## Can Harry actually touch every checkpoint that has been placed?
##
## This exists because most of them could not. The signs are placed at z 1.2 to
## 1.4 so they read against the wall, and the trigger was a sphere of radius 1.1
## centred on the sign — so its near face sat at z 0.1 to 0.3 while Harry runs at
## z 0. The ones at 1.4 were dead outright. Nothing errored: a checkpoint that
## never fires just means you respawn further back than you expected, and you
## blame yourself for missing it.
##
## Checked against the PLAY PLANE rather than by walking him into each one, so
## it covers all six levels cheaply and cannot be fooled by a route he happens
## not to take. The geometry is the thing that was wrong.
##
## Run with:
##   godot --headless --path . --script tests/checkpoint_reachable_test.gd

const LEVELS := [
	"drain_level", "street_level", "kitchen_level",
	"counter_level", "granny_kitchen_level", "tabletop_level", "pantry_level", "roof_level",
	"roof_garden_level", "tree_level", "abduction_level", "moon_level", "ship_level",
]

## Where gameplay happens. Everything is locked to this plane.
const PLAY_Z := 0.0
## He is not a point. Half his body depth, so a trigger that only just grazes
## z 0 still counts as a miss rather than as a pass by a hair.
const BODY_HALF_DEPTH := 0.25

var _index := 0
var _frames := 0
var _level: Node
var _total := 0
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _all(node: Node, out: Array[Node]) -> void:
	out.append(node)
	for child in node.get_children():
		_all(child, out)


## World-space Z span of an Area3D's shape, whatever shape it is.
func _z_span(area: Area3D) -> Vector2:
	for child in area.get_children():
		if not (child is CollisionShape3D):
			continue
		var cs := child as CollisionShape3D
		var centre: float = cs.global_position.z
		var half := 0.0
		if cs.shape is BoxShape3D:
			half = (cs.shape as BoxShape3D).size.z * 0.5
		elif cs.shape is SphereShape3D:
			half = (cs.shape as SphereShape3D).radius
		elif cs.shape is CylinderShape3D:
			half = (cs.shape as CylinderShape3D).radius
		return Vector2(centre - half, centre + half)
	return Vector2(1.0, -1.0) # no shape at all: an empty span, which fails


func _initialize() -> void:
	# HERMETIC: the player reads bought upgrades off the save on spawn now,
	# so a test without a scratch save measures whatever was last played.
	SaveGame.save_path = "user://test_checkpoint_reachable_scratch.cfg"
	SaveGame.clear()
	print("-- every placed checkpoint reaches the plane Harry runs on")


func _process(_delta: float) -> bool:
	if _index >= LEVELS.size():
		_check(_total > 0, "found %d checkpoints across %d levels"
			% [_total, LEVELS.size()])
		if _failures.is_empty():
			print("CHECKPOINT REACHABLE TEST PASS")
		else:
			print("CHECKPOINT REACHABLE TEST FAIL (%d): %s"
				% [_failures.size(), ", ".join(_failures)])
		quit(0 if _failures.is_empty() else 1)
		return true

	if _level == null:
		var path := "res://world/levels/%s.tscn" % LEVELS[_index]
		_level = (load(path) as PackedScene).instantiate()
		root.add_child(_level)
		_frames = 0
		return false
	# Decor is built in _ready and some of it lands deferred.
	if _frames < 20:
		_frames += 1
		return false

	var name: String = LEVELS[_index]
	var nodes: Array[Node] = []
	_all(_level, nodes)
	var unreachable: Array[String] = []
	var count := 0
	for node in nodes:
		if not (node is Checkpoint3D):
			continue
		count += 1
		_total += 1
		var span := _z_span(node as Checkpoint3D)
		var reaches: bool = span.x <= PLAY_Z + BODY_HALF_DEPTH \
			and span.y >= PLAY_Z - BODY_HALF_DEPTH
		if not reaches:
			unreachable.append("%s at x %.0f (z %.2f..%.2f)"
				% [name, (node as Node3D).global_position.x, span.x, span.y])
	_check(unreachable.is_empty(), "%s: all %d reachable%s"
		% [name, count, "" if unreachable.is_empty()
			else " — DEAD: " + ", ".join(unreachable)])

	_level.queue_free()
	_level = null
	_index += 1
	return false
