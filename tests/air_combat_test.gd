extends SceneTree

## Air-to-air combat, from the live report: "can we hit the wasp in the air?
## same with flies?" The bite volume was half a metre tall, so mid-air swings
## against a bobbing fly whiffed by centimetres and read as impossible.
##
## Three claims:
##   - a FLY can be killed mid-air, flying beside it with real inputs
##   - a mid-air swing at the hovering WASP physically rocks it (shrugged,
##     never damaging - the syrup stays the only opening - but an EVENT)
##   - the wasp's reinforcements FLY now, on the play plane, instead of the
##     ground ants that sat on top of you unhittable
##
## Run with:
##   godot --headless --path . --script tests/air_combat_test.gd

var _phase := 0
var _t := 0.0
var _step := 0.0
var _level: Node
var _player: Node
var _fly: Node
var _wasp: Node
var _attack_down := false
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = "user://test_air_combat.cfg"
	SaveGame.clear()
	_level = (load("res://world/levels/street_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")
	_fly = _level.get_node("Fly1")
	print("-- a fly can be fought in its own element")


func _mash() -> void:
	_attack_down = not _attack_down
	if _attack_down:
		Input.action_press("attack")
	else:
		Input.action_release("attack")
	_player._bite_cooldown_timer = 0.0


func _hold_at(target: Vector3) -> void:
	# Real flight, not a pin: wings topped, jump held, nudged toward station.
	_player.wing_energy = _player.max_wing_energy
	_player._wings_spent = false
	_player.health = _player.max_health
	_player._invincibility_timer = 9999.0
	Input.action_press("jump")
	var dx: float = target.x - _player.global_position.x
	if absf(dx) > 0.3:
		Input.action_press("move_right" if dx > 0 else "move_left")
		Input.action_release("move_left" if dx > 0 else "move_right")
	else:
		Input.action_release("move_right")
		Input.action_release("move_left")
	if _player.global_position.distance_to(target) > 4.0:
		_player.global_position = target + Vector3(-1.2, -0.4, 0.0)
		_player.velocity = Vector3.ZERO


func _process(delta: float) -> bool:
	_t += delta
	_step += delta
	if _t > 60.0:
		print("AIR COMBAT TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _step < 1.0:
				return false
			if not is_instance_valid(_fly):
				_check(true, "the fly dies to mid-air swings (%.1fs)" % _step)
				_phase = 1
				_step = 0.0
				for a in ["jump", "attack", "move_left", "move_right"]:
					Input.action_release(a)
				_level.queue_free()
				return false
			_hold_at(_fly.global_position)
			if _player.global_position.distance_to(_fly.global_position) < 1.6:
				_mash()
			if _step > 25.0:
				_check(false, "the fly dies to mid-air swings (still alive, hp %s)"
					% str(_fly.health))
				_phase = 1
				_step = 0.0
			return false
		1:
			if _step < 0.5:
				return false
			print("-- the hovering wasp answers an air hit")
			_level = (load("res://world/levels/counter_level.tscn") as PackedScene).instantiate()
			root.add_child(_level)
			_player = _level.get_node("Player")
			_wasp = _level.get_node("Wasp")
			_phase = 2
			_step = 0.0
		2:
			if _step < 1.0:
				return false
			_hold_at(_wasp.global_position)
			if _player.global_position.distance_to(_wasp.global_position) < 1.8:
				_mash()
			if _wasp._air_knocks > 0:
				_check(true, "a mid-air swing ROCKS the wasp (%d knocks)" % _wasp._air_knocks)
				_check(_wasp.health == _wasp.max_health,
					"without ever hurting it - the syrup stays the opening")
				for a in ["jump", "attack", "move_left", "move_right"]:
					Input.action_release(a)
				_phase = 3
				_step = 0.0
			elif _step > 20.0:
				_check(false, "a mid-air swing ROCKS the wasp (no knock registered)")
				_phase = 3
			return false
		3:
			print("-- its reinforcements fly")
			# Diffed against the level's own placed flies: the first summon
			# takes the collision-free name "Fly", so name filters undercount.
			var before := {}
			for child in _level.get_children():
				before[child.get_instance_id()] = true
			_wasp._summon_wave()
			var fliers := 0
			var on_plane := true
			for child in _level.get_children():
				if before.has(child.get_instance_id()):
					continue
				var script: Script = child.get_script()
				if script and script.resource_path.ends_with("fly_3d.gd"):
					fliers += 1
					if absf(child.global_position.z) > 0.05:
						on_plane = false
			_check(fliers == _wasp.summon_count,
				"the swarm is %d small FLIERS, not ground ants" % fliers)
			_check(on_plane, "and they arrive on the play plane")
			_phase = 4
		4:
			if _failures.is_empty():
				print("AIR COMBAT TEST PASS")
			else:
				print("AIR COMBAT TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
			return true
	return false
