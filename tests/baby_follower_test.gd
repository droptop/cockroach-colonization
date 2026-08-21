extends SceneTree

## The baby companion: trails behind, catches up, recovers when stranded, never
## overlaps Harry, and comes with him through a level transition.
##
## Run with:
##   godot --headless --path . --script tests/baby_follower_test.gd

const TEST_SAVE := "user://test_baby.cfg"

var _phase := 0
var _frames := 0
var _elapsed := 0.0
var _level: Node
var _player: Node
var _baby: BabyFollower3D
var _min_gap := 999.0
var _walk_from := 0.0
var _failures: Array[String] = []


## Counts colliders anywhere in the subtree — the compiler already knows the
## node itself isn't one, so the question is whether it grew a child that is.
func _collision_bodies(node: Node) -> int:
	var n := 1 if node is CollisionObject3D else 0
	for child in node.get_children():
		n += _collision_bodies(child)
	return n


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = TEST_SAVE
	SaveGame.clear()
	_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	if _frames > 200000:
		print("BABY FOLLOWER TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true

	if _baby and is_instance_valid(_baby) and _player:
		_min_gap = minf(_min_gap, _baby.global_position.distance_to(_player.global_position))

	match _phase:
		0:
			if _frames < 12:
				return false
			print("-- hatching")
			# Egg2 sits on the mid ledge, which is twelve metres of flat floor:
			# room to walk and measure without falling into a gap. And Harry is
			# STOOD at it before it hatches, because hatching an egg on the far
			# side of the level spawns the baby forty metres away and every
			# distance below becomes a measure of how far it has left to walk.
			var egg: Area3D = _level.get_node_or_null("Egg2")
			if egg == null:
				egg = _level.get_node_or_null("Egg1")
			_check(egg != null, "the drain still has its eggs")
			_check(_player.baby_count() == 0, "Harry starts alone")
			if egg:
				_player.global_position = egg.global_position + Vector3(-2.0, 0.4, 0)
				_player.velocity = Vector3.ZERO
			egg._on_body_entered(_player)
			_elapsed = 0.0
			_phase = 1
		1:
			if _elapsed < 0.7: # let the shell burst finish
				return false
			_check(_player.baby_count() == 1, "the egg produces exactly one follower")
			for child in _level.get_children():
				if child is BabyFollower3D:
					_baby = child
			_check(_baby != null, "and it lives in the level, not on the player")
			if _baby:
				_check(_baby.get_parent() == _level,
					"parented to the level, so it can't inherit Harry's squash or flip")
				_check(_collision_bodies(_baby) == 0,
					"nothing in it has collision, so it can never block or shove him")
			_min_gap = 999.0
			_elapsed = 0.0
			_walk_from = _player.global_position.x
			Input.action_press("move_right")
			_phase = 2
		2:
			# Walk, but not off the ledge: a player who falls in mid-measurement
			# makes every number meaningless. Timed to stay on whatever ledge he
			# spawned on rather than assuming where that is — this asserted
			# x > 2.0, which silently meant "the spawn is at x = 0" and broke the
			# moment the drain grew a new opening section.
			if _elapsed < 0.8:
				return false
			Input.action_release("move_right")
			var gap := _baby.global_position.distance_to(_player.global_position)
			_check(_player.global_position.x - _walk_from > 1.0,
				"Harry actually moved (%.1f m)" % (_player.global_position.x - _walk_from))
			_check(gap > 0.25, "the baby trails behind rather than sitting on him (%.2f m)" % gap)
			_check(gap < 4.0, "and stays in a readable range (%.2f m)" % gap)
			_check(_min_gap > 0.1,
				"it never overlapped him at any point (closest %.2f m)" % _min_gap)
			_phase = 3
		3:
			print("-- stuck recovery")
			# Park Harry somewhere stable first, for the same reason.
			_player.global_position = _player.spawn_position
			_player.velocity = Vector3.ZERO
			_player.reset_trail() # what a real pit respawn now does
			# Strand the baby somewhere it could never walk back from.
			_baby.global_position = _player.global_position + Vector3(0, -40, 0)
			_elapsed = 0.0
			_phase = 4
		4:
			if _elapsed < 3.0:
				return false
			var gap := _baby.global_position.distance_to(_player.global_position)
			_check(gap < 2.5, "a stranded baby recovers to Harry (%.2f m)" % gap)
			print("-- surviving a level transition")
			_check(SaveGame.babies_banked() == 1, "the count is persisted as it changes")
			_level.free()
			_level = (load("res://world/levels/street_level.tscn") as PackedScene).instantiate()
			root.add_child(_level)
			_player = _level.get_node("Player")
			_frames = 0
			_phase = 5
		5:
			if _frames < 12:
				return false
			_check(_player.baby_count() == 1,
				"the baby is still with him in the next level")
			var found := 0
			for child in _level.get_children():
				if child is BabyFollower3D:
					found += 1
			_check(found == 1, "and exactly one exists — not zero, not two")

			print("-- death costs him the babies")
			_player.take_damage(999, _player.global_position + Vector3(1, 0, 0))
			_check(_player.baby_count() == 0, "dying loses every follower")
			_check(SaveGame.babies_banked() == 0, "and that is persisted too")
			_phase = 6
		6:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
			if _failures.is_empty():
				print("BABY FOLLOWER TEST PASS")
			else:
				print("BABY FOLLOWER TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
	return false
