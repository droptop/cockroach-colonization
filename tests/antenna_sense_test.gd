extends SceneTree

## Antenna Sense exists because I built secrets nobody could find. Both
## breakables sit behind the spawn, where no player would think to swing at a
## wall — a secret with no tell is not a secret, it is level nobody sees.
##
## Run with:
##   godot --headless --path . --script tests/antenna_sense_test.gd

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


func _glow() -> float:
	if _block == null or _block._cracks == null:
		return -1.0
	var mat: StandardMaterial3D = (_block._cracks.multimesh.mesh as BoxMesh).material
	return mat.emission_energy_multiplier if mat.emission_enabled else 0.0


func _initialize() -> void:
	_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	if _frames > 20000:
		print("SENSE TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 25:
				return false
			print("-- the ability is bound to something spare")
			_check(InputMap.has_action("interact"), "there is an interact action")
			_check(_player.sense_radius > 0.0, "and a sense radius (%.1f)" % _player.sense_radius)
			_check(_player.sense_cooldown > 0.0, "and a cooldown, so it cannot be spammed")

			for child in _level.get_children():
				if child is BreakableBlock3D:
					_block = child
			_check(_block != null, "the drain has a secret to find")
			if _block == null:
				_phase = 9
				return false
			_check(_block.has_method("reveal"), "and it answers reveal()")
			_check(is_equal_approx(_glow(), 0.0), "which is dark until asked (%.2f)" % _glow())

			print("-- out of range, it stays hidden")
			_player.global_position = _block.global_position + Vector3(
				_player.sense_radius + 6.0, 0, 0)
			_player._sense_timer = 0.0
			Input.action_press("interact")
			_elapsed = 0.0
			_phase = 1
		1:
			if _elapsed < 0.3:
				return false
			Input.action_release("interact")
			_check(is_equal_approx(_glow(), 0.0),
				"a pulse from far away lights nothing (%.2f)" % _glow())
			_phase = 2
		2:
			print("-- close enough, it shows itself")
			_player.global_position = _block.global_position + Vector3(2.0, 0.5, 0)
			_player._sense_timer = 0.0
			Input.action_press("interact")
			_elapsed = 0.0
			_phase = 3
		3:
			if _elapsed < 0.4:
				return false
			Input.action_release("interact")
			_check(_glow() > 0.0, "the wall lights up (%.2f)" % _glow())
			_elapsed = 0.0
			_phase = 4
		4:
			if _elapsed < 3.0:
				return false
			_check(is_equal_approx(_glow(), 0.0),
				"and fades again, so it is a hint and not a permanent marker (%.2f)" % _glow())
			_phase = 5
		5:
			print("-- and it is on a cooldown")
			_player._sense_timer = 0.0
			_player._handle_sense() # not pressed, so nothing should happen
			_check(is_equal_approx(_player._sense_timer, 0.0),
				"it does nothing without the button")
			_phase = 6
		6:
			if _failures.is_empty():
				print("SENSE TEST PASS")
			else:
				print("SENSE TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
		9:
			print("SENSE TEST FAIL: nothing to find")
			quit(1)
	return false
