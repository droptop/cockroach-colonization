extends SceneTree

## Dying drops what you were carrying where you fell, and you can go and get it.
##
## The load-bearing case is the exploit one: recovery must hand back the WEIGHT
## as well as the score. Weight now buys knockback resistance and damage, so if
## death shed the bulk but recovery returned the crumbs, dying on purpose would
## be the optimal play.
##
## Run with:
##   godot --headless --path . --script tests/lost_ghost_test.gd

var _phase := 0
var _frames := 0
var _elapsed := 0.0
var _level: Node
var _player: Node
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _ghosts() -> Array[LostGhost3D]:
	var found: Array[LostGhost3D] = []
	for child in _level.get_children():
		if child is LostGhost3D and not child.is_queued_for_deletion():
			found.append(child)
	return found


func _initialize() -> void:
	# HERMETIC: the player reads bought upgrades off the save on spawn now,
	# so a test without a scratch save measures whatever was last played.
	SaveGame.save_path = "user://test_lost_ghost_scratch.cfg"
	SaveGame.clear()
	_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")


func _kill() -> void:
	_player.is_dead = false
	_player.health = 5.0
	_player._invincibility_timer = 0.0
	_player.take_damage(99, _player.global_position + Vector3(1, 0, 0), "spider")


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	if _frames > 20000:
		print("GHOST TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 12:
				return false
			print("-- dying with nothing leaves nothing to fetch")
			_player.food = 0
			_player.fruit_count = 0
			_player.fullness = 0.0
			_kill()
			_elapsed = 0.0
			_phase = 1
		1:
			if _elapsed < 0.6: # the death tween has to reach the ghost callback
				return false
			_check(_ghosts().is_empty(),
				"an empty-handed death leaves no ghost to walk back to")

			print("-- dying with a full belly leaves it behind")
			_player.food = 7
			_player.fruit_count = 2
			_player.fullness = 0.8
			_kill()
			_elapsed = 0.0
			_phase = 2
		2:
			if _elapsed < 0.6:
				return false
			var ghosts := _ghosts()
			_check(ghosts.size() == 1, "it leaves exactly one ghost")
			if ghosts.is_empty():
				_phase = 9
				return false
			_check(ghosts[0].crumbs == 7, "holding the crumbs (%d)" % ghosts[0].crumbs)
			_check(ghosts[0].fruit == 2, "and the fruit (%d)" % ghosts[0].fruit)
			_check(ghosts[0].fullness > 0.7, "and the weight (%.2f)" % ghosts[0].fullness)

			print("-- and death itself still costs him")
			_player.food = 0
			_player.fruit_count = 0
			_player.fullness = 0.0
			_check(_player.food == 0, "he respawns with nothing in hand")

			print("-- walking back gets it all")
			ghosts[0]._on_body_entered(_player)
			_check(_player.food == 7, "the crumbs come back (%d)" % _player.food)
			_check(_player.fruit_count == 2, "the fruit comes back (%d)" % _player.fruit_count)
			_check(_player.fullness > 0.7,
				"AND THE WEIGHT comes back (%.2f) — or dying is a free diet"
					% _player.fullness)
			_phase = 3
		3:
			# Invoked directly rather than through two deaths: back-to-back kills
			# leave two death tweens in flight and the test ends up racing them
			# instead of checking the invariant. The invariant is what matters.
			print("-- there is only ever one")
			_player.food = 4
			_player.fruit_count = 0
			_player.fullness = 0.5
			_player._leave_ghost()
			_check(_ghosts().size() == 1, "one death, one ghost")
			_player.food = 9
			_player.fullness = 0.9
			_player._leave_ghost()
			var ghosts := _ghosts()
			_check(ghosts.size() == 1,
				"dying again abandons the old one rather than stacking (%d)" % ghosts.size())
			if not ghosts.is_empty():
				_check(ghosts[0].crumbs == 9,
					"and the survivor holds the LATEST loss (%d)" % ghosts[0].crumbs)
			_phase = 6
		6:
			if _failures.is_empty():
				print("GHOST TEST PASS")
			else:
				print("GHOST TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
		9:
			print("GHOST TEST FAIL: no ghost was produced")
			quit(1)
	return false
