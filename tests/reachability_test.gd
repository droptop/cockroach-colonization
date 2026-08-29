extends SceneTree

## Collision the player can never touch is worse than no collision: it costs
## physics, it looks like a platform, and it silently is not one.
##
## Harry is locked to z=0 (`axis_lock_linear_z`), so any solid body whose shape
## does not span z=0 is unreachable by definition. This test caught exactly that
## the first time the street got window ledges — they sat back at z=-3.6 against
## the facades, looked like platforms, had colliders, and could never be landed
## on.
##
## Run with:
##   godot --headless --path . --script tests/reachability_test.gd

const LEVELS := [
	"drain_level", "street_level", "kitchen_level",
	"counter_level", "granny_kitchen_level", "tabletop_level", "pantry_level", "roof_level",
	"roof_garden_level", "tree_level", "abduction_level", "moon_level",
]

## Surfaces added from level scripts, which no .tscn records. Sampled directly
## so a silent regression in one shows up as a failure rather than as a level
## that quietly lost a route.
const WALKWAYS := {
	"drain_level": [[11.75, 3.4], [23.75, 5.2], [33.0, 8.0], [42.5, 10.6]],
	"street_level": [[5.0, 5.0], [11.0, 6.5], [46.0, 6.0], [52.0, 3.5], [8.0, 6.0]],
	"kitchen_level": [[20.0, 7.4], [38.0, 5.6]],
	"granny_kitchen_level": [[44.0, 4.9], [6.0, 4.7], [20.0, 4.7], [40.0, 4.7]],
}

## HERMETIC: the player reads bought upgrades off the save on spawn now, so a
## test without a scratch save measures whatever was last played.
func _initialize() -> void:
	SaveGame.save_path = "user://test_reachability_scratch.cfg"
	SaveGame.clear()


var _index := 0
var _frames := 0
var _level: Node
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


## Every box collider under `node`, as world-space z ranges.
func _unreachable_bodies(node: Node, out: Array[String]) -> void:
	if node is StaticBody3D:
		for child in node.get_children():
			if not (child is CollisionShape3D):
				continue
			var shape := (child as CollisionShape3D).shape
			if not (shape is BoxShape3D):
				continue
			var half: float = (shape as BoxShape3D).size.z * 0.5
			var centre: float = (child as CollisionShape3D).global_position.z
			if centre - half > 0.0 or centre + half < 0.0:
				out.append("%s (z %.1f..%.1f)" % [node.name, centre - half, centre + half])
	for child in node.get_children():
		_unreachable_bodies(child, out)


func _process(_delta: float) -> bool:
	_frames += 1
	if _level == null:
		if _index >= LEVELS.size():
			_report()
			return true
		_level = (load("res://world/levels/%s.tscn" % LEVELS[_index]) as PackedScene).instantiate()
		root.add_child(_level)
		_frames = 0
		return false
	if _frames < 25: # decor and deferred spawns have to land first
		return false

	var name: String = LEVELS[_index]
	# Explicitly typed: get_world_3d() on an untyped Node returns a Variant,
	# so the inferred type is unknowable to the parser.
	var space: PhysicsDirectSpaceState3D = _level.get_world_3d().direct_space_state

	# 1. Every declared walkway holds him up.
	if WALKWAYS.has(name):
		var missing: Array[String] = []
		for spot in WALKWAYS[name]:
			var query := PhysicsRayQueryParameters3D.create(
				Vector3(spot[0], spot[1] + 2.5, 0.0),
				Vector3(spot[0], spot[1] - 1.5, 0.0), 1)
			if space.intersect_ray(query).is_empty():
				missing.append("x=%.0f y=%.1f" % [spot[0], spot[1]])
		_check(missing.is_empty(), "%s: every script-built walkway is standable%s"
			% [name, "" if missing.is_empty() else " — MISSING " + ", ".join(missing)])

	# 2. Nothing solid sits entirely off the plane he is locked to.
	var stranded: Array[String] = []
	_unreachable_bodies(_level, stranded)
	_check(stranded.is_empty(), "%s: no collider is stranded off the z=0 plane%s"
		% [name, "" if stranded.is_empty() else " — " + ", ".join(stranded)])

	_level.free()
	_level = null
	_index += 1
	return false


func _report() -> void:
	if _failures.is_empty():
		print("REACHABILITY TEST PASS")
	else:
		print("REACHABILITY TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
	quit(0 if _failures.is_empty() else 1)
