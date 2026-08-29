extends SceneTree

## Brood eggs (BACKLOG #19 remainder + #20): the deniable spawn.
##
## Three claims, each of which could rot alone:
##   - an egg CRACKED by a real attack press never hatches
##   - an egg left alone hatches, exactly once, where it stood
##   - the mantis REAPER hits a grounded player and misses an airborne one
##
## The egg cases press the attack button, per the standing rule: driving
## take_damage from a test proves nothing about whether a player can crack it.
##
## Run with:
##   godot --headless --path . --script tests/brood_test.gd

var _phase := 0
var _t := 0.0
var _step := 0.0
var _level: Node
var _player: Node
var _mantis: Node
var _egg: Node
var _hatched: Array[Vector3] = []
var _attack_down := false
var _hp_before := 0
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = "user://test_brood.cfg"
	SaveGame.clear()
	_level = (load("res://world/levels/street_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")
	_mantis = _level.get_node("Mantis")
	print("-- eggs are a choice, not a spawn")


func _lay(at: Vector3) -> Node:
	var egg := BroodEgg3D.new()
	egg.hatch_time = 2.0
	egg.hatch_action = func(hatch_at: Vector3) -> void:
		_hatched.append(hatch_at)
	_level.add_child(egg)
	egg.global_position = at
	return egg


func _park_at(x: float) -> void:
	_player.health = _player.max_health
	_player._invincibility_timer = 9999.0
	_player.global_position = Vector3(x, 1.0, 0.0)
	_player.velocity = Vector3.ZERO


func _mash() -> void:
	_player._bite_cooldown_timer = 0.0
	_attack_down = not _attack_down
	if _attack_down:
		Input.action_press("attack")
	else:
		Input.action_release("attack")


func _process(delta: float) -> bool:
	_t += delta
	_step += delta
	if _t > 120.0:
		print("BROOD TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _step < 0.5:
				return false
			# Far from the mantis, so only the egg is in front of the bite.
			_egg = _lay(Vector3(4.0, 0.8, 0.0))
			_step = 0.0
			_phase = 1
		1:
			_park_at(3.2)
			_player.facing = 1
			_mash()
			if is_instance_valid(_egg) and _step < 6.0:
				return false
			Input.action_release("attack")
			_check(not is_instance_valid(_egg),
				"a real attack press cracks the egg")
			_check(_hatched.is_empty(), "and a cracked egg never hatches")
			_egg = _lay(Vector3(9.0, 0.8, 0.0))
			_park_at(2.0) # well away: nobody cracks this one
			_step = 0.0
			_phase = 2
		2:
			if is_instance_valid(_egg) and _step < 8.0:
				return false
			_check(_hatched.size() == 1,
				"left alone it hatches exactly once (%d)" % _hatched.size())
			if _hatched.size() == 1:
				_check(_hatched[0].distance_to(Vector3(9.0, 0.8, 0.0)) < 1.0,
					"and it hatches where it stood")
			print("-- the reaper reads the FLOOR")
			# Stand in reach, grounded, and let the sweep land.
			_park_at(_mantis.global_position.x - 2.0)
			_hp_before = _player.health
			_mantis._target = _player
			_mantis.engage()
			_mantis._begin_reaper()
			_step = 0.0
			_phase = 3
		3:
			# Invincibility OFF, or the sweep lands and the check reads a lie.
			_player._invincibility_timer = 0.0
			_player.global_position.x = _mantis.global_position.x - 2.0
			_player.velocity.x = 0.0
			if _mantis.state == _mantis.State.REAPER and _step < 6.0:
				return false
			_check(_player.health < _hp_before,
				"grounded in reach, the sweep lands (%d -> %d)"
					% [_hp_before, _player.health])
			# Again, airborne: the counter is the jump.
			_park_at(_mantis.global_position.x - 2.0)
			_hp_before = _player.health
			_mantis._begin_reaper()
			_step = 0.0
			_phase = 4
		4:
			# Held aloft through the whole swing: is_on_floor() stays false.
			_player._invincibility_timer = 0.0
			_player.global_position = Vector3(
				_mantis.global_position.x - 2.0, 3.2, 0.0)
			_player.velocity = Vector3.ZERO
			if _mantis.state == _mantis.State.REAPER and _step < 6.0:
				return false
			_check(_player.health == _hp_before,
				"airborne, it sweeps under him (%d unchanged)" % _player.health)
			_phase = 5
		5:
			if _failures.is_empty():
				print("BROOD TEST PASS")
			else:
				print("BROOD TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
			return true
	return false
