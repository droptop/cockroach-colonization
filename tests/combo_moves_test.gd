extends SceneTree

## The two combo attacks, driven by PRESSING THE KEYS.
##
## Both are the ordinary attack with a direction already held, which is what
## makes them free: no new binding, and nothing to be eaten by a browser. It
## also makes them easy to break without noticing, because the thing that
## decides which move you get is a pair of booleans read at the top of
## _handle_attack, and getting either wrong just gives you a normal swing.
##
## So this presses down-then-attack in the air and back-then-attack on the
## ground and looks at what his body actually does. Calling _mega_smash()
## directly would prove the function works and say nothing about whether the
## combination reaches it.
##
## The MEGA SMASH is gated on fall DISTANCE, not on being airborne, so the
## last check is that a little hop does not earn it. A combo that fires on
## every pogo is not a combo.
##
## Run with:
##   godot --headless --path . --script tests/combo_moves_test.gd

var _phase := 0
var _t := 0.0
var _step := 0.0
var _level: Node
var _player: Node3D
var _smash_speed := 0.0
var _flip_dir := 0.0
var _flip_lift := 0.0
var _hop_speed := 0.0
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _next(phase: int) -> void:
	_phase = phase
	_step = 0.0


func _initialize() -> void:
	# HERMETIC: the player reads bought upgrades off the save on spawn now,
	# so a test without a scratch save measures whatever was last played.
	SaveGame.save_path = "user://test_combo_moves_scratch.cfg"
	SaveGame.clear()
	_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")


func _release_all() -> void:
	for a in ["attack", "move_down", "move_left", "move_right", "move_up"]:
		Input.action_release(a)


func _process(delta: float) -> bool:
	_t += delta
	_step += delta
	if _t > 90.0:
		print("COMBO TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _step < 1.0:
				return false
			print("-- mega smash: down + attack, after a real fall")
			_player._invincibility_timer = 9999.0
			# High over the mid ledge, so there is room to fall.
			_player.global_position = Vector3(24.0, 14.0, 0)
			_player.velocity = Vector3.ZERO
			_player._fall_peak = 14.0
			_next(1)
		1:
			# Let him drop past the threshold before swinging.
			if _player._fall_peak - _player.global_position.y < 3.5 and _step < 6.0:
				return false
			_player._bite_cooldown_timer = 0.0
			Input.action_press("move_down")
			Input.action_press("attack")
			_next(2)
		2:
			_smash_speed = minf(_smash_speed, _player.velocity.y)
			if _smash_speed > -20.0 and _step < 2.0:
				return false
			_release_all()
			# It drives him DOWN hard. A plain down-attack does not touch
			# velocity at all, so any strong downward push is the smash.
			_check(_smash_speed < -20.0,
				"down + attack after a fall drives him down (%.1f m/s)" % _smash_speed)
			_next(3)
		3:
			if _step < 0.6:
				return false
			print("-- and a little hop does NOT earn it")
			_player.global_position = Vector3(24.0, 2.0, 0)
			_player.velocity = Vector3.ZERO
			_player._fall_peak = 2.4 # barely left the floor
			_player._bite_cooldown_timer = 0.0
			_hop_speed = 0.0
			Input.action_press("move_down")
			Input.action_press("attack")
			_next(4)
		4:
			_hop_speed = minf(_hop_speed, _player.velocity.y)
			if _step < 0.35:
				return false
			_release_all()
			_check(_hop_speed > -20.0,
				"a short drop stays an ordinary pogo (%.1f m/s)" % _hop_speed)
			_next(5)
		5:
			if _step < 0.6:
				return false
			print("-- backflip kick: attack while holding away from facing")
			_player.global_position = Vector3(24.0, 1.2, 0)
			_player.velocity = Vector3.ZERO
			_player.facing = 1
			_next(6)
		6:
			# He has to be ON the floor for it, so let him settle.
			if not _player.is_on_floor() and _step < 4.0:
				return false
			_player._bite_cooldown_timer = 0.0
			Input.action_press("move_left") # away from facing +1
			Input.action_press("attack")
			_next(7)
		7:
			_flip_dir = minf(_flip_dir, _player.velocity.x)
			_flip_lift = maxf(_flip_lift, _player.velocity.y)
			if _flip_lift < 1.0 and _step < 2.0:
				return false
			_release_all()
			# It throws him backwards and up, and turns him round.
			_check(_flip_lift > 1.0,
				"back + attack lifts him off the floor (%.1f m/s)" % _flip_lift)
			_check(_player.facing == -1,
				"and turns him to face the way he kicked (%d)" % _player.facing)
			_next(8)
		8:
			if _failures.is_empty():
				print("COMBO TEST PASS")
			else:
				print("COMBO TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
			return true
	return false
