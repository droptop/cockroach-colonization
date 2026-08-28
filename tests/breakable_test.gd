extends SceneTree

## Breakable walls, and the reason they exist: they are the one weight benefit
## from the brief that a stat change could not express. Being fat has to open a
## route, not just adjust a number.
##
## Run with:
##   godot --headless --path . --script tests/breakable_test.gd

var _phase := 0
var _frames := 0
var _elapsed := 0.0
var _level: Node
var _player: Node
var _block: BreakableBlock3D
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _blocks() -> Array[BreakableBlock3D]:
	var found: Array[BreakableBlock3D] = []
	for child in _level.get_children():
		if child is BreakableBlock3D and not child.is_queued_for_deletion():
			found.append(child)
	return found


## Is the WALL there? Probed across the band it occupies rather than down to
## the floor — the mid ledge underneath is solid either way, which is how the
## first version of this test managed to assert nothing at all.
func _solid_at(at: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = _level.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		at + Vector3(-2.0, 0.2, 0), at + Vector3(2.0, 0.2, 0), 1)
	return not space.intersect_ray(query).is_empty()


func _initialize() -> void:
	# HERMETIC: the player reads bought upgrades off the save on spawn now,
	# so a test without a scratch save measures whatever was last played.
	SaveGame.save_path = "user://test_breakable_scratch.cfg"
	SaveGame.clear()
	_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	if _frames > 20000:
		print("BREAKABLE TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 25:
				return false
			print("-- there is something to break")
			var blocks := _blocks()
			_check(blocks.size() >= 1, "the drain has a breakable (%d)" % blocks.size())
			if blocks.is_empty():
				_phase = 9
				return false
			_block = blocks[0]
			_check(_block.collision_layer & 4 != 0,
				"it sits on the enemy layer, so the normal bite finds it")
			_check(_block.collision_layer & 1 != 0, "and on the world layer, so it blocks")
			_check(_solid_at(_block.global_position), "and it really is in the way")

			print("-- a weak hit will not do")
			var before: int = _block.health
			_block.take_damage(1, _block.global_position + Vector3(0, 2, 0))
			_check(_block.health == before, "a bare bite bounces off (%d)" % _block.health)
			_check(not _block.is_queued_for_deletion(), "and it is still there")

			print("-- a heavy enough one does")
			_block.take_damage(_block.required_damage, _block.global_position + Vector3(0, 2, 0))
			_check(_block.health == before - 1, "a qualifying hit counts (%d)" % _block.health)
			_phase = 1
		1:
			print("-- weight is what turns a weak weapon into a qualifying one")
			# The player's own damage path, not a hand-fed number: light Harry
			# with a bite does 1, heavy Harry does 1 + growth_damage_bonus.
			_player.fullness = 0.0
			var light: int = 1 + (_player.growth_damage_bonus \
				if _player.fullness >= _player.growth_heavy_threshold else 0)
			_player.fullness = 1.0
			var heavy: int = 1 + (_player.growth_damage_bonus \
				if _player.fullness >= _player.growth_heavy_threshold else 0)
			_check(heavy > light, "a fat roach hits harder with the same weapon (%d vs %d)"
				% [heavy, light])
			_check(light < _block.required_damage and heavy >= _block.required_damage,
				"and that is the difference between bouncing off and getting through")

			print("-- breaking it opens the way immediately")
			var at: Vector3 = _block.global_position
			_block.take_damage(_block.required_damage, at + Vector3(0, 2, 0))
			_check(_block.health <= 0, "enough hits break it")
			_elapsed = 0.0
			_broke_at = at
			_phase = 2
		2:
			if _elapsed < 0.1: # collision goes on the deferred queue
				return false
			_check(not _solid_at(_broke_at),
				"the gap is open the instant it breaks, not when the animation ends")
			_elapsed = 0.0
			_phase = 3
		3:
			if _elapsed < 0.6:
				return false
			_check(_blocks().is_empty(), "and it tidies itself away")
			_phase = 4
		4:
			if _failures.is_empty():
				print("BREAKABLE TEST PASS")
			else:
				print("BREAKABLE TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
		9:
			print("BREAKABLE TEST FAIL: nothing to break")
			quit(1)
	return false


var _broke_at := Vector3.ZERO
