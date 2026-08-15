extends SceneTree

## Granny: not killable, beaten by dodging, and every attack damaging exactly
## the circle it drew.
##
## Run with:
##   godot --headless --path . --script tests/granny_encounter_test.gd

const TEST_SAVE := "user://test_granny.cfg"

var _phase := 0
var _frames := 0
var _elapsed := 0.0
var _level: Node
var _player: Node
var _granny: GrannyBoss3D
var _patience: Array[int] = []
var _defeated := 0
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = TEST_SAVE
	SaveGame.clear()
	_level = (load("res://world/levels/granny_kitchen_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")
	_granny = _level.get_node("Granny")


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	if _frames > 20000:
		print("GRANNY TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 12:
				return false
			print("-- she is not a damage sponge")
			_check(_granny.immune_to_damage, "Granny is immune to weapons")
			_check(_level.exit_state == Level3D.ExitState.LOCKED,
				"and her level starts locked behind her")
			_granny.boss_health_changed.connect(func(c: int, _m: int) -> void: _patience.append(c))
			_granny.defeated.connect(func() -> void: _defeated += 1)

			var before: int = _granny.health
			_granny.take_damage(99, _granny.global_position + Vector3(1, 0, 0))
			_check(_granny.health == before, "hitting her does nothing at all")
			_check(not _granny.is_defeated, "she cannot be killed with a weapon")

			print("-- she notices him")
			_check(_granny.state == GrannyBoss3D.State.HIDDEN, "she starts hidden")
			_player.global_position = _granny.global_position + Vector3(-4, -6, 3.2)
			_elapsed = 0.0
			_phase = 1
		1:
			if _elapsed < 2.6: # rise + shock
				return false
			_check(_granny.state != GrannyBoss3D.State.HIDDEN,
				"getting close brings her up (state %d)" % _granny.state)
			_check(_granny._eeked, "and she shrieks")
			_check(_level.exit_state == Level3D.ExitState.BOSS_ACTIVE,
				"which starts the encounter")

			print("-- a miss costs her patience, a hit does not")
			var patience_before: int = _granny.health
			# Resolve an attack aimed somewhere he plainly is not.
			_granny._resolve(_player.global_position + Vector3(30, 0, 0), 1.0, 2)
			_check(_granny.health == patience_before - 1, "missing him wears her down")
			# And one aimed right at him.
			_player.health = 5.0
			_player._invincibility_timer = 0.0
			var patience_after: int = _granny.health
			var hp_before: float = _player.health
			_granny._resolve(_player.global_position, 1.5, 2)
			_check(_player.health < hp_before, "landing one hurts him")
			_check(_granny.health == patience_after, "and costs her nothing")
			_phase = 2
		2:
			print("-- worn out, she leaves and the way opens")
			var guard := 0
			while not _granny.is_defeated and guard < 30:
				_granny._resolve(_player.global_position + Vector3(50, 0, 0), 1.0, 2)
				guard += 1
			_check(_granny.is_defeated, "enough misses and she gives up")
			_check(_defeated == 1, "and says so once")
			_check(_granny.state == GrannyBoss3D.State.RETREATING, "she retreats rather than dying")
			_check(SaveGame.is_boss_defeated("granny_kitchen"), "the win is saved")
			_elapsed = 0.0
			_phase = 3
		3:
			if _elapsed < 2.5: # defeat sequence, then the gate opens
				return false
			_check(_level.exit_state == Level3D.ExitState.UNLOCKED,
				"and the exit unlocks")
			print("-- every attack damages exactly the circle it drew")
			# The telegraph disc and the strike are handed the same radius by
			# _telegraph_and_strike; check the resolve honours that boundary.
			var aim: Vector3 = _player.global_position
			_player.global_position = aim + Vector3(2.0, 0, 0)
			_player._invincibility_timer = 0.0
			_player.health = 5.0
			var outside_before: float = _player.health
			_granny._resolve(aim, 1.0, 2) # he is 2 m away from a 1 m circle
			_check(is_equal_approx(_player.health, outside_before),
				"standing outside the marked circle is safe")
			_player.global_position = aim + Vector3(0.5, 0, 0)
			_player._invincibility_timer = 0.0
			var inside_before: float = _player.health
			_granny._resolve(aim, 1.0, 2) # inside the same circle
			_check(_player.health < inside_before, "standing inside it is not")
			_phase = 4
		4:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
			if _failures.is_empty():
				print("GRANNY TEST PASS")
			else:
				print("GRANNY TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
	return false
