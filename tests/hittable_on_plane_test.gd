extends SceneTree

## Everything that can be hurt must be WHERE HURT CAN REACH.
##
## Harry is locked to z 0 and every attack volume is a thin box around the
## play plane, so a vulnerable body sitting off-plane is unhittable no matter
## what the player does — and nothing errors. The user has now reported this
## twice from the live build ("there are bosses and enemies you can never hit
## because they're not on the same z"). The cat's summoned ants shipped six
## metres behind the plane; the report names the wasp.
##
## So: load every level, stand the player in the boss arena so fights engage,
## and SAMPLE every enemy-layer body for ten real seconds. A body is flagged
## when it is VULNERABLE (no `immune_to_damage`, or it reads false) while its
## collision extent cannot intersect the attack volumes' reach in z, for a
## sustained stretch — transient flickers during a dive are not a lockout.
##
## Bosses that are immune BY DESIGN (Granny at z -3.2, the cat at z -6) pass
## exactly as long as they stay immune; the moment one becomes vulnerable
## off-plane it is caught, which is the wasp case.
##
## Run with:
##   godot --headless --path . --script tests/hittable_on_plane_test.gd

const LEVELS := [
	"drain_level", "street_level", "kitchen_level",
	"counter_level", "granny_kitchen_level", "tabletop_level", "pantry_level", "roof_level",
	"roof_garden_level", "tree_level", "abduction_level",
]

## Attack volumes are ~0.5 deep around z 0; a body whose collision gets within
## this of the plane can be clipped by a swing.
const REACH_Z := 0.5
## How long a vulnerable body may sit out of reach before it counts as a
## lockout rather than a moment of animation.
const GRACE_SECONDS := 1.5
## Real seconds of fight observed per level.
const WATCH_SECONDS := 10.0

var _index := 0
var _t := 0.0
var _level: Node
var _player: Node3D
## instance id -> seconds continuously vulnerable-and-unreachable
var _out_of_reach := {}
## instance id -> worst [name, z, seconds] seen
var _flagged := {}
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = "user://test_hittable_on_plane.cfg"
	SaveGame.clear()
	SaveGame.set_babies_banked(0)
	print("-- everything vulnerable stays where attacks can reach")


func _all(node: Node, out: Array[Node]) -> void:
	out.append(node)
	for child in node.get_children():
		_all(child, out)


## World-space z half-extent of a body's first collision shape, so "off-plane"
## is about the collision's nearest face, not its origin.
func _half_depth(body: PhysicsBody3D) -> float:
	for child in body.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape:
			var shape := (child as CollisionShape3D).shape
			if shape is BoxShape3D:
				return (shape as BoxShape3D).size.z * 0.5
			if shape is SphereShape3D:
				return (shape as SphereShape3D).radius
			if shape is CapsuleShape3D:
				return (shape as CapsuleShape3D).radius
	return 0.3


func _vulnerable(body: Node) -> bool:
	if not body.has_method("take_damage"):
		return false
	if "is_defeated" in body and body.is_defeated:
		return false
	if "immune_to_damage" in body:
		return not body.immune_to_damage
	return true


func _process(delta: float) -> bool:
	if _index >= LEVELS.size():
		if _failures.is_empty():
			print("HITTABLE ON PLANE TEST PASS")
		else:
			print("HITTABLE ON PLANE TEST FAIL (%d): %s"
				% [_failures.size(), ", ".join(_failures)])
		quit(0 if _failures.is_empty() else 1)
		return true

	if _level == null:
		_level = (load("res://world/levels/%s.tscn" % LEVELS[_index])
			as PackedScene).instantiate()
		root.add_child(_level)
		_player = _level.get_node_or_null("Player")
		_t = 0.0
		_out_of_reach = {}
		_flagged = {}
		return false

	_t += delta
	# Park him in the fight so bosses engage and enemies behave, and keep him
	# standing so the observation window is about THEM, not about him dying.
	if _player and _t > 0.5:
		_player.health = _player.max_health
		_player._invincibility_timer = 9999.0
		var boss: Node = _level.get_node_or_null(_level.boss_path) \
			if not _level.boss_path.is_empty() else null
		if boss is Node3D and _t < 0.6:
			var bounds: Vector2 = boss.arena_bounds() if boss.has_method("arena_bounds") \
				else Vector2((boss as Node3D).global_position.x - 3.0,
					(boss as Node3D).global_position.x + 3.0)
			_player.global_position = Vector3(
				(bounds.x + bounds.y) * 0.5, _player.global_position.y + 0.5, 0.0)
			_player.velocity = Vector3.ZERO

	var nodes: Array[Node] = []
	_all(_level, nodes)
	for node in nodes:
		if not (node is PhysicsBody3D):
			continue
		var body := node as PhysicsBody3D
		if body.collision_layer & 4 == 0 or body == _player:
			continue
		var id := body.get_instance_id()
		var gap: float = absf(body.global_position.z) - _half_depth(body)
		if _vulnerable(body) and gap > REACH_Z:
			_out_of_reach[id] = _out_of_reach.get(id, 0.0) + delta
			if _out_of_reach[id] > GRACE_SECONDS:
				var worst: Array = _flagged.get(id, [body.name, 0.0, 0.0])
				worst[1] = body.global_position.z
				worst[2] = _out_of_reach[id]
				_flagged[id] = worst
		else:
			_out_of_reach[id] = 0.0

	if _t < WATCH_SECONDS:
		return false

	var name: String = LEVELS[_index]
	var report: Array[String] = []
	for id in _flagged:
		var worst: Array = _flagged[id]
		report.append("%s vulnerable at z %.1f for %.1fs" % [worst[0], worst[1], worst[2]])
	_check(report.is_empty(), "%s: everything hittable stays in reach%s"
		% [name, "" if report.is_empty() else " - OFF-PLANE: " + "; ".join(report)])

	_level.queue_free()
	_level = null
	_index += 1
	return false
