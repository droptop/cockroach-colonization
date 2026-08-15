extends SceneTree

## Boss gate regression test. Two things must both stay true:
##   1. A level with NO boss declared opens exactly as it always did. This is
##      the regression that would silently brick an ungated level. Uses the
##      street, because the drain has had a boss since the Spider Queen landed.
##   2. A level WITH a boss keeps its exit shut until that boss is down.
##
## Run with:
##   godot --headless --path . --script tests/boss_gate_test.gd

const DEFEAT_WAIT := 3.0 # defeat_sequence_time (1.6) plus generous margin
## This test kills a boss, and boss defeats now persist. Point the save at a
## scratch file or the run pollutes the real one — and the SECOND run would
## find the rat already dead and fail for the wrong reason.
const TEST_SAVE := "user://test_boss_gate.cfg"

var _phase := 0
var _elapsed := 0.0
var _frames := 0
var _level: Node
var _drain: Node
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = TEST_SAVE
	SaveGame.clear()
	_drain = (load("res://world/levels/street_level.tscn") as PackedScene).instantiate()
	root.add_child(_drain)


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	if _frames > 100000: # never spin forever if an assert throws mid-phase
		print("BOSS GATE TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 5:
				return false
			print("-- level with no boss declared")
			_check(_drain.exit_state == Level3D.ExitState.UNLOCKED,
				"street starts UNLOCKED (no boss_path set)")
			_check(_drain.boss_path.is_empty(), "street declares no boss")
			_drain.free()
			_phase = 1
		1:
			print("-- level with a boss declared")
			_level = (load("res://world/levels/kitchen_level.tscn") as PackedScene).instantiate()
			root.add_child(_level)
			_phase = 2
		2:
			if _frames < 12:
				return false
			var rat: Node = _level.get_node_or_null("RatBoss")
			_check(rat != null, "kitchen finds its boss node")
			_check(rat is BaseBoss3D, "the rat is a BaseBoss3D")
			_check(_level.exit_state == Level3D.ExitState.LOCKED,
				"kitchen starts LOCKED")

			# Reaching the exit early must be refused, not silently ignored.
			_level._on_exit_zone_body_entered(_level.get_node("Player"))
			_check(_level.exit_state == Level3D.ExitState.LOCKED,
				"touching the exit while the boss lives does NOT start a transition")

			# Hurt it: the fight starts, the bar populates, the exit stays shut.
			rat.take_damage(1, rat.global_position + Vector3(2, 0, 0))
			_check(_level.exit_state == Level3D.ExitState.BOSS_ACTIVE,
				"damaging the boss moves the exit to BOSS_ACTIVE")
			_check(rat.health == rat.max_health - 1, "boss health tracks damage")
			_level._on_exit_zone_body_entered(_level.get_node("Player"))
			_check(_level.exit_state == Level3D.ExitState.BOSS_ACTIVE,
				"exit still refused mid-fight")

			rat.take_damage(999, rat.global_position)
			_check(rat.is_defeated, "boss reports defeated")
			_check(rat.health == 0, "boss health floors at 0, never negative")
			# Overkill after death must not re-fire anything.
			rat.take_damage(5, rat.global_position)
			_check(rat.health == 0, "damage after defeat is ignored")
			_check(_level.exit_state == Level3D.ExitState.BOSS_DEFEATED,
				"exit is BOSS_DEFEATED while the defeat sequence plays")
			_elapsed = 0.0
			_phase = 3
		3:
			# Real seconds, not frames: headless idle frames are not 1/60 s.
			if _elapsed < DEFEAT_WAIT:
				return false
			_check(_level.exit_state == Level3D.ExitState.UNLOCKED,
				"exit UNLOCKS after the defeat sequence")
			_phase = 4
		4:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
			if _failures.is_empty():
				print("BOSS GATE TEST PASS")
			else:
				print("BOSS GATE TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
	return false
