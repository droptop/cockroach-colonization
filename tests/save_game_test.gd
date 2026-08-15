extends SceneTree

## Save persistence, and the P0 criterion it exists to satisfy: a boss beaten
## in an earlier session must not have to be fought again.
##
## Writes to a scratch file, never to the real save — a test that wipes a
## player's progress to prove a point is not worth the point.
##
## Run with:
##   godot --headless --path . --script tests/save_game_test.gd

const TEST_PATH := "user://test_save_game.cfg"

var _phase := 0
var _frames := 0
var _level: Node
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = TEST_PATH
	SaveGame.clear()

	print("-- round trip")
	_check(not SaveGame.is_boss_defeated("rat"), "a fresh save has beaten nobody")
	_check(SaveGame.defeated_boss_count() == 0, "and counts zero bosses")
	SaveGame.mark_boss_defeated("rat")
	_check(SaveGame.is_boss_defeated("rat"), "a defeat is recorded")

	# The real question: does it survive the process forgetting everything?
	SaveGame.invalidate()
	_check(SaveGame.is_boss_defeated("rat"), "and survives a reload from disk")
	_check(SaveGame.defeated_boss_count() == 1, "the count reads back too")
	_check(not SaveGame.is_boss_defeated("cat"), "an unbeaten boss stays unbeaten")
	_check(not SaveGame.is_boss_defeated(""), "an empty boss_id never counts as beaten")

	SaveGame.set_babies_banked(7)
	SaveGame.set_furthest_level("res://world/levels/kitchen_level.tscn")
	SaveGame.mark_achievement("king_of_cockroaches")
	SaveGame.invalidate()
	_check(SaveGame.babies_banked() == 7, "banked babies persist")
	_check(SaveGame.furthest_level().ends_with("kitchen_level.tscn"), "progress persists")
	_check(SaveGame.has_achievement("king_of_cockroaches"), "achievements persist")

	print("-- version guard")
	var stale := ConfigFile.new()
	stale.set_value("meta", "version", SaveGame.VERSION + 99)
	stale.set_value("bosses", "rat", true)
	stale.save(TEST_PATH)
	SaveGame.invalidate()
	_check(not SaveGame.is_boss_defeated("rat"),
		"a save from another version is discarded, not half-read")

	print("-- a boss already beaten is not fought again")
	SaveGame.clear()
	SaveGame.mark_boss_defeated("rat")
	_level = (load("res://world/levels/kitchen_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 100000:
		print("SAVE GAME TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 12:
				return false
			_check(_level.get_node_or_null("RatBoss") == null,
				"the beaten rat is not in the level")
			_check(_level.exit_state == Level3D.ExitState.UNLOCKED,
				"and the exit it was gating starts open")
			_level.free()

			# Same level, clean save: the rat is back and the gate holds.
			SaveGame.clear()
			_level = (load("res://world/levels/kitchen_level.tscn") as PackedScene).instantiate()
			root.add_child(_level)
			_frames = 0
			_phase = 1
		1:
			if _frames < 12:
				return false
			_check(_level.get_node_or_null("RatBoss") != null,
				"on a clean save the rat is present again")
			_check(_level.exit_state == Level3D.ExitState.LOCKED,
				"and the exit is locked again")

			var rat: Node = _level.get_node("RatBoss")
			rat.take_damage(999, rat.global_position)
			_check(SaveGame.is_boss_defeated("rat"),
				"beating him writes straight through to the save")
			_phase = 2
		2:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
			if _failures.is_empty():
				print("SAVE GAME TEST PASS")
			else:
				print("SAVE GAME TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
	return false
