extends SceneTree

## Checkpoints, and the arena soft-lock they exposed.
##
## Boss-gated exits made dying at a boss re-walk the whole level, and arena
## locking made it worse: the walls dropped on DEFEAT, so dying inside sealed
## him out of a fight he still had to win. Both are checked here.
##
## Run with:
##   godot --headless --path . --script tests/checkpoint_test.gd

const TEST_SAVE := "user://test_checkpoint.cfg"

var _phase := 0
var _frames := 0
var _elapsed := 0.0
var _level: Node
var _player: Node
var _queen: SpiderQueen3D
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _checkpoints() -> Array[Checkpoint3D]:
	var found: Array[Checkpoint3D] = []
	for child in _level.get_children():
		if child is Checkpoint3D:
			found.append(child)
	return found


func _initialize() -> void:
	SaveGame.save_path = TEST_SAVE
	SaveGame.clear()
	_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")
	_queen = _level.get_node("SpiderQueen")


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	if _frames > 20000:
		print("CHECKPOINT TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 12:
				return false
			print("-- every level has somewhere safe")
			var points := _checkpoints()
			_check(points.size() >= 2, "the drain has %d shelters" % points.size())
			if points.size() < 2:
				_phase = 9
				return false
			var start: Vector3 = _player.spawn_position

			print("-- reaching one moves the respawn AND banks what he holds")
			_player.food = 5
			_player.fruit_count = 1
			_player.fullness = 0.4
			points[0]._on_body_entered(_player)
			_check(_player.spawn_position != start, "respawn moves to the shelter")
			_check(_player.spawn_position.distance_to(points[0].global_position) < 1.0,
				"and it is THAT shelter")
			_check(_player._banked_food == 5, "the crumbs are banked (%d)" % _player._banked_food)
			_check(points[0].used, "and it is marked used")

			print("-- dying rolls back to the bank, not to nothing")
			_player.food = 9 # four gathered since
			_player.fruit_count = 3
			_player.fullness = 0.75
			_player.is_dead = false
			_player.health = 5.0
			_player._invincibility_timer = 0.0
			_player.take_damage(99, _player.global_position + Vector3(1, 0, 0), "spider")
			_elapsed = 0.0
			_phase = 1
		1:
			if _elapsed < 0.8: # let the death tween reach the ghost
				return false
			var ghosts: Array[LostGhost3D] = []
			for child in _level.get_children():
				if child is LostGhost3D and not child.is_queued_for_deletion():
					ghosts.append(child)
			_check(ghosts.size() == 1, "he leaves a ghost")
			if not ghosts.is_empty():
				_check(ghosts[0].crumbs == 4,
					"carrying only what he gathered SINCE the shelter (%d, not 9)"
						% ghosts[0].crumbs)
			_player._respawn()
			_check(_player.food == 5, "and he respawns with the banked crumbs (%d)" % _player.food)
			_check(_player.fruit_count == 1, "and banked fruit (%d)" % _player.fruit_count)
			_check(is_equal_approx(_player.fullness, 0.4),
				"and banked weight (%.2f)" % _player.fullness)
			_phase = 2
		2:
			print("-- the arena never seals him out of an unfinished fight")
			_player.global_position = _queen.global_position - Vector3(0, 4.6, 0)
			_queen.engage()
			_elapsed = 0.0
			_phase = 3
		3:
			if _elapsed < 0.3:
				return false
			_check(_level._arena_walls != null, "walls go up when the fight starts")
			_player.is_dead = true
			_elapsed = 0.0
			_phase = 4
		4:
			if _elapsed < 0.3:
				return false
			_check(_level._arena_walls == null,
				"and come DOWN when he dies — or he respawns outside a fight he cannot re-enter")
			_player.is_dead = false
			# Away from the arena: they should stay down until he walks back.
			_player.global_position = Vector3(2, 1, 0)
			_elapsed = 0.0
			_phase = 5
		5:
			if _elapsed < 0.3:
				return false
			_check(_level._arena_walls == null, "they stay down while he is elsewhere")
			_player.global_position = _queen.global_position - Vector3(0, 4.6, 0)
			_elapsed = 0.0
			_phase = 6
		6:
			if _elapsed < 0.3:
				return false
			_check(_level._arena_walls != null, "and go back up once he returns of his own accord")
			_phase = 7
		7:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
			if _failures.is_empty():
				print("CHECKPOINT TEST PASS")
			else:
				print("CHECKPOINT TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
		9:
			print("CHECKPOINT TEST FAIL: no shelters in the level")
			quit(1)
	return false
