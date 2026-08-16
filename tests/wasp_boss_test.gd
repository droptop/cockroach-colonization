extends SceneTree

## The Wasp is never reachable on your terms. It hovers, it dives at wherever
## you are, and the only way to hurt it is to be standing over syrup when it
## commits — then step off and let it bury itself.
##
## Run with:
##   godot --headless --path . --script tests/wasp_boss_test.gd

const TEST_SAVE := "user://test_wasp.cfg"

var _phase := 0
var _frames := 0
var _elapsed := 0.0
var _level: Node
var _player: Node
var _wasp: WaspBoss3D
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = TEST_SAVE
	SaveGame.clear()
	_level = (load("res://world/levels/counter_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")
	_wasp = _level.get_node("Wasp")


## Aim a dive at `x` with the player parked somewhere else, and resolve it.
func _dive_at(x: float, player_x: float) -> void:
	_player.global_position = Vector3(player_x, _wasp.floor_y + 0.4, 0)
	_wasp._aim = Vector3(x, _wasp.floor_y, 0)
	_wasp.state = WaspBoss3D.State.DIVE
	_wasp._impact()


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	if _frames > 20000:
		print("WASP TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 15: # syrup is spilled deferred
				return false
			print("-- the counter finally ends in something")
			_check(_level.exit_state == Level3D.ExitState.LOCKED, "the way down is gated")
			_check(_wasp.immune_to_damage, "in the air it cannot be touched")
			var before: int = _wasp.health
			_wasp.take_damage(99, _wasp.global_position + Vector3(0, -2, 0))
			_check(_wasp.health == before, "swinging at it does nothing")

			print("-- it spills syrup to dive into")
			_check(_wasp._syrup.size() == _wasp.syrup_count,
				"there are %d patches (%d)" % [_wasp.syrup_count, _wasp._syrup.size()])
			if _wasp._syrup.is_empty():
				_phase = 9
				return false
			_phase = 1
		1:
			print("-- landing on bare counter costs it nothing")
			# Scan for genuinely bare counter rather than assuming a gap exists
			# where I think it does — the first version of this test picked a
			# spot 4.9 out from patch 0, which landed inside patch 1.
			var bare_x: float = _wasp._syrup[0].x
			for step in 200:
				var probe: float = _wasp._syrup[0].x + step * 0.25
				if not _wasp._in_syrup(Vector3(probe, _wasp.floor_y, 0)):
					bare_x = probe
					break
			_check(not _wasp._in_syrup(Vector3(bare_x, _wasp.floor_y, 0)),
				"that spot really is bare")
			_dive_at(bare_x, bare_x + 6.0) # player well clear
			_check(_wasp.state == WaspBoss3D.State.RECOVER,
				"it pulls straight back up (state %d)" % _wasp.state)
			_check(_wasp.immune_to_damage, "and is untouchable again")

			print("-- landing in syrup buries it")
			var syrup_x: float = _wasp._syrup[0].x
			_dive_at(syrup_x, syrup_x + 6.0)
			_check(_wasp.state == WaspBoss3D.State.STUCK,
				"it sticks (state %d)" % _wasp.state)
			_check(not _wasp.immune_to_damage, "and is finally hittable")
			var before: int = _wasp.health
			_wasp.take_damage(2, _wasp.global_position + Vector3(1, 0, 0))
			_check(_wasp.health == before - 2, "so a hit lands while it is stuck")

			print("-- but only if you actually got out of the way")
			_wasp.state = WaspBoss3D.State.HOVER
			_wasp.immune_to_damage = true
			_player.health = 5.0
			_player._invincibility_timer = 0.0
			var hp_before: float = _player.health
			_dive_at(syrup_x, syrup_x) # standing right on it
			_check(_player.health < hp_before, "taking the dive hurts")
			_check(_wasp.state != WaspBoss3D.State.STUCK,
				"and it does NOT stick — hitting you is a hit, not a mistake")
			_phase = 2
		2:
			print("-- beaten in the syrup, it drops the sugar it was guarding")
			var guard := 0
			while not _wasp.is_defeated and guard < 30:
				_wasp.lose_health(1, _wasp.global_position)
				guard += 1
			_check(_wasp.is_defeated, "it can be finished")
			_check(SaveGame.is_boss_defeated("counter_wasp"), "the win is saved")
			var rewards := 0
			for child in _level.get_children():
				if child is RewardPickup3D:
					rewards += 1
			_check(rewards >= 3, "and leaves spoils (%d)" % rewards)
			_elapsed = 0.0
			_phase = 3
		3:
			if _elapsed < 2.5:
				return false
			_check(_level.exit_state == Level3D.ExitState.UNLOCKED, "the way down opens")
			_phase = 4
		4:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
			if _failures.is_empty():
				print("WASP TEST PASS")
			else:
				print("WASP TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
		9:
			print("WASP TEST FAIL: no syrup was spilled")
			quit(1)
	return false
