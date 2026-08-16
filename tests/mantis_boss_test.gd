extends SceneTree

## The Mantis guards its front. Hitting it in the face does nothing; dropping on
## it from above or getting behind it does. That is the whole fight.
##
## Run with:
##   godot --headless --path . --script tests/mantis_boss_test.gd

const TEST_SAVE := "user://test_mantis.cfg"

var _phase := 0
var _frames := 0
var _elapsed := 0.0
var _level: Node
var _player: Node
var _mantis: MantisBoss3D
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = TEST_SAVE
	SaveGame.clear()
	_level = (load("res://world/levels/street_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")
	_mantis = _level.get_node("Mantis")


## Hit it from a given offset and report whether any health came off.
func _hit_from(offset: Vector3, amount := 1) -> bool:
	var before: int = _mantis.health
	_mantis.take_damage(amount, _mantis.global_position + offset)
	return _mantis.health < before


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	if _frames > 20000:
		print("MANTIS TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 12:
				return false
			print("-- the street finally ends in something")
			_check(_level.exit_state == Level3D.ExitState.LOCKED,
				"the door is gated behind it")
			_check(not _mantis.immune_to_damage,
				"it is NOT blanket-immune — it can be hurt, just not anywhere")

			print("-- the guard")
			_mantis.state = MantisBoss3D.State.TRACKING
			_mantis.facing = 1
			_check(not _hit_from(Vector3(2.0, 0.1, 0)),
				"a hit to its face is turned aside")
			_check(not _hit_from(Vector3(1.6, 0.6, 0)),
				"and so is one from slightly above the front")
			_check(_hit_from(Vector3(-2.0, 0.1, 0)),
				"but from BEHIND it lands")
			_mantis.facing = -1
			_check(not _hit_from(Vector3(-2.0, 0.1, 0)),
				"and the guard turns with it")
			_check(_hit_from(Vector3(2.0, 0.1, 0)), "so what was safe is now open")

			print("-- the pogo always works")
			_mantis.facing = 1
			_check(_hit_from(Vector3(0.15, 2.0, 0)),
				"a down-attack from straight above beats the guard")
			_check(_hit_from(Vector3(0.9, 1.9, 0)),
				"and so does one from above and slightly in front")
			_phase = 1
		1:
			print("-- committing drops the guard entirely")
			_mantis.facing = 1
			_mantis.state = MantisBoss3D.State.RECOVER
			_check(_hit_from(Vector3(2.0, 0.1, 0)),
				"mid-recovery, even a frontal hit lands — bait it, then punish")
			_mantis.state = MantisBoss3D.State.TRACKING
			_check(not _hit_from(Vector3(2.0, 0.1, 0)), "and the guard comes back up")

			print("-- beaten, it drops what it was holding")
			var guard := 0
			while not _mantis.is_defeated and guard < 30:
				_mantis.lose_health(1, _mantis.global_position)
				guard += 1
			_check(_mantis.is_defeated, "it can be finished")
			_check(SaveGame.is_boss_defeated("street_mantis"), "the win is saved")
			var rewards := 0
			for child in _level.get_children():
				if child is RewardPickup3D:
					rewards += 1
			_check(rewards >= 2, "and it leaves spoils (%d)" % rewards)
			_elapsed = 0.0
			_phase = 2
		2:
			if _elapsed < 2.5:
				return false
			_check(_level.exit_state == Level3D.ExitState.UNLOCKED, "the door opens")
			_phase = 3
		3:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
			if _failures.is_empty():
				print("MANTIS TEST PASS")
			else:
				print("MANTIS TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
	return false
