extends SceneTree

## The run-up gauntlet: walking into it brings a crowd up out of the dark, the
## crowd is bounded, and it ends.
##
## Driven by WALKING HIM INTO IT, not by calling the spawner. A trigger that
## fires when poked directly proves nothing about whether a player can ever set
## it off, which is the same blind spot that let three destructibles ship
## unhittable.
##
## The two things that actually matter here are the bounds. A wave spawner that
## never stops is a level nobody finishes, and one that ignores `Encounter` is
## an ambush rather than a fight: the cap of two committed attackers has to hold
## no matter how many bodies are on the floor.
##
## Run with:
##   godot --headless --path . --script tests/climber_wave_test.gd

var _phase := 0
var _t := 0.0
var _step := 0.0
var _level: Node
var _player: Node3D
var _wave: ClimberWave3D
var _started := false
var _cleared := false
var _peak_attackers := 0
var _peak_alive := 0
var _clear_timer := 0.0
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _next(phase: int) -> void:
	_phase = phase
	_step = 0.0


func _initialize() -> void:
	_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")


func _alive() -> int:
	var n := 0
	for child in _level.get_children():
		# Duck-typed like the rest of the project: ants, spiders and flies are
		# the things that answer stagger(), and Ant3D has no class_name.
		if child.has_method("stagger"):
			n += 1
	return n


func _process(delta: float) -> bool:
	_t += delta
	_step += delta
	if _t > 120.0:
		print("CLIMBER WAVE TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	if _wave and _wave._fired:
		_peak_attackers = maxi(_peak_attackers, Encounter.attackers(_level))
		_peak_alive = maxi(_peak_alive, _alive())

	match _phase:
		0:
			if _step < 1.0:
				return false
			print("-- the drain has a run-up before the Queen")
			for child in _level.get_children():
				if child is ClimberWave3D:
					_wave = child
			_check(_wave != null, "a climber wave is placed")
			if _wave == null:
				_next(9)
				return false
			_wave.started.connect(func() -> void: _started = true)
			_wave.cleared.connect(func() -> void: _cleared = true)
			# Make it quick to sit through, without changing what is tested.
			_wave.waves = 2
			_wave.per_wave = 2
			_wave.spawn_interval = 0.15
			_wave.wave_gap = 0.3
			_wave.wave_timeout = 4.0
			_wave.climb_time = 0.2
			_check(not _started, "and it is asleep until he reaches it")
			_next(1)
		1:
			# WALK him in. Nothing here calls the spawner.
			_player.global_position = _wave.global_position + Vector3(-3.0, 1.0, 0)
			_player.velocity = Vector3.ZERO
			_player._invincibility_timer = 9999.0
			if _step < 0.5:
				return false
			Input.action_press("move_right")
			_next(2)
		2:
			if not _started and _step < 6.0:
				return false
			Input.action_release("move_right")
			_check(_started, "walking into it wakes it")
			_next(3)
		3:
			# He must not die mid-measurement, and he is not what is on trial.
			_player._invincibility_timer = 9999.0
			_player.health = _player.max_health
			# Stand in for a player clearing the floor. Without this the wave
			# correctly waits for the crowd to be dealt with and the test simply
			# measures its own refusal to fight.
			_clear_timer -= delta
			if _clear_timer <= 0.0:
				_clear_timer = 0.5
				for child in _level.get_children():
					if child.has_method("stagger") and child.has_method("take_damage"):
						child.take_damage(99, _player.global_position)
			if not _cleared and _step < 60.0:
				return false
			_check(_cleared, "and it ends rather than spawning forever")
			_check(_peak_alive > 0, "something actually climbed up (%d at once)"
				% _peak_alive)
			# The whole point of routing them through Encounter.
			_check(_peak_attackers <= Encounter.MAX_ATTACKERS,
				"never more than %d committed at once (peak %d), crowd or not"
					% [Encounter.MAX_ATTACKERS, _peak_attackers])
			_next(4)
		4:
			# And the floor is left clear, not littered with stuck climbers.
			if _step < 1.5:
				return false
			_check(_wave._done, "the spawner has finished")
			if _failures.is_empty():
				print("CLIMBER WAVE TEST PASS")
			else:
				print("CLIMBER WAVE TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
			return true
		9:
			print("CLIMBER WAVE TEST FAIL: no wave to test")
			quit(1)
			return true
	return false
