extends SceneTree

## The Hollow-Knight feel pass: the pogo, attack buffering, corner correction,
## and weight actually buying something.
##
## Run with:
##   godot --headless --path . --script tests/game_feel_test.gd

var _phase := 0
var _frames := 0
var _elapsed := 0.0
var _level: Node
var _player: Node
var _target: Node
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	print("-- the tuning the brief asks for is already the tuning")
	_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")
	_target = _level.get_node("Spider")
	_check(is_equal_approx(_player.coyote_time, 0.10), "coyote time is 0.10 s")
	_check(is_equal_approx(_player.jump_buffer_time, 0.12), "jump buffer is 0.12 s")
	_check(_player.jump_cut_multiplier < 1.0, "jump height is variable")
	var to_full_speed: float = _player.run_speed / _player.ground_acceleration
	_check(to_full_speed >= 0.10 and to_full_speed <= 0.15,
		"reaches running speed in %.3f s (brief wants 0.10-0.15)" % to_full_speed)
	_check(_player.ground_deceleration > _player.ground_acceleration,
		"braking is stronger than acceleration, so turns feel immediate")
	_check(_player.air_acceleration < _player.ground_acceleration,
		"air control is reduced but present")
	_check(InputMap.has_action("move_down"), "there is a down input to aim with")


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	if _frames > 20000:
		print("FEEL TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 12:
				return false
			print("-- attacks queue like jumps")
			_check(_player.attack_buffer_time > 0.0, "attacks have a buffer window")
			_player._bite_cooldown_timer = 0.5
			_player._attack_buffer_timer = 0.0
			Input.action_press("attack")
			_player._handle_attack()
			Input.action_release("attack")
			_check(_player._attack_buffer_timer > 0.0,
				"a press during cooldown is remembered rather than eaten")

			print("-- weight buys something")
			_check(_player.growth_knockback_resist > 0.0, "heavy resists knockback")
			_check(_player.growth_damage_bonus > 0, "and hits harder")
			# Light: full knockback.
			_player.fullness = 0.0
			_player.health = 5.0
			_player._invincibility_timer = 0.0
			_player.take_damage(1, _player.global_position + Vector3(1, 0, 0))
			var light_knock: float = absf(_player.velocity.x)
			# Heavy: braced.
			_player.fullness = 1.0
			_player.health = 5.0
			_player._invincibility_timer = 0.0
			_player.velocity = Vector3.ZERO
			_player.take_damage(1, _player.global_position + Vector3(1, 0, 0))
			var heavy_knock: float = absf(_player.velocity.x)
			_check(heavy_knock < light_knock,
				"a fat roach is shoved less (%.2f vs %.2f)" % [heavy_knock, light_knock])
			_check(heavy_knock > 0.0, "but is still moved — resistance, not immunity")
			_phase = 1
		1:
			print("-- the pogo")
			_check(_player.down_attack_bounce > 0.0, "a down-attack bounce exists")
			_check(_player._down_area != null, "with its own sweep volume")
			_check(_player._down_area.collision_mask == 4,
				"that looks for enemies")
			# Hang the spider in mid-air OVER THE PIT and drop him onto it. Doing
			# this above the ledge meant he landed first, and a grounded strike is
			# a forward one — which is how the first run of this test "passed" the
			# damage check while measuring no bounce at all.
			_target.set_physics_process(false)
			_target.health = 40
			_target.global_position = Vector3(16.5, 3.0, 0)
			_player.fullness = 0.0
			_player._bite_cooldown_timer = 0.0
			_player._invincibility_timer = 99.0 # ignore the spider's contact damage
			_elapsed = 0.0
			_phase = 2
		2:
			# Hold him falling just above it until the overlap has registered.
			_player.global_position = _target.global_position + Vector3(0, 0.95, 0)
			_player.velocity = Vector3(0, -3.0, 0)
			if _elapsed < 0.2:
				return false
			var hp_before: int = _target.health
			var falling: float = _player.velocity.y
			_check(falling < 0.0, "he is falling before the strike (%.1f)" % falling)
			Input.action_press("move_down")
			Input.action_press("attack")
			_elapsed = 0.0
			_phase = 3
			_check(hp_before > 0, "the target is alive to be pogoed")
		3:
			if _elapsed < 0.25:
				return false
			Input.action_release("attack")
			Input.action_release("move_down")
			_check(_target.health < 40, "the down-attack connects (%d)" % _target.health)
			_check(_player.velocity.y > 0.0,
				"and bounces him upward off it (%.1f)" % _player.velocity.y)
			_check(_player.dash_ready or _player._dash_available,
				"and gives the air dash back, so pogo chains work")
			_phase = 4
		4:
			print("-- hit-stop is brief and self-clearing")
			_check(is_equal_approx(Engine.time_scale, 1.0),
				"time is running normally after the hits (%.3f)" % Engine.time_scale)
			_phase = 5
		5:
			if _failures.is_empty():
				print("FEEL TEST PASS")
			else:
				print("FEEL TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
	return false
