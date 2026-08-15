extends SceneTree

## The cat: hittable only on the paw it leaves behind, and only while that paw
## is down. Hitting the cat itself must do nothing, or the weak-point mechanic
## is just decoration on an ordinary boss.
##
## Run with:
##   godot --headless --path . --script tests/cat_boss_test.gd

const TEST_SAVE := "user://test_cat.cfg"

var _phase := 0
var _frames := 0
var _elapsed := 0.0
var _level: Node
var _player: Node
var _cat: CatBoss3D
var _paw: CatPaw3D
var _defeated := 0
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = TEST_SAVE
	SaveGame.clear()
	_level = (load("res://world/levels/tabletop_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")
	_cat = _level.get_node("Cat")


func _find_paw() -> CatPaw3D:
	for child in _level.get_children():
		if child is CatPaw3D:
			return child
	return null


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	if _frames > 20000:
		print("CAT TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 12:
				return false
			print("-- the cat itself is not the target")
			_check(_cat.immune_to_damage, "the cat's body is immune")
			_check(_level.exit_state == Level3D.ExitState.LOCKED, "and it gates the exit")
			_cat.defeated.connect(func() -> void: _defeated += 1)
			var before: int = _cat.health
			_cat.take_damage(99, _cat.global_position)
			_check(_cat.health == before, "hitting the cat does nothing")

			print("-- the paw is the weak point")
			# Drive one swipe directly rather than waiting on the rotation.
			_player.global_position = Vector3(48, 0.6, 0)
			_cat._swipe()
			_elapsed = 0.0
			_phase = 1
		1:
			if _elapsed < 1.6: # telegraph, then the paw lands
				return false
			_paw = _find_paw()
			_check(_paw != null, "the swipe leaves a paw on the table")
			if _paw == null:
				_phase = 9
				return false
			_check(_paw.collision_layer == 4,
				"the paw is on the enemy layer, so the normal bite area finds it")
			_check(_paw.vulnerable, "and it is vulnerable while it rests there")
			var health_before: int = _cat.health
			_paw.take_damage(1, _paw.global_position + Vector3(2, 0, 0))
			_check(_cat.health == health_before - 1, "hitting the paw hurts the cat")

			print("-- but only while it is down")
			_paw.set_vulnerable(false)
			var guarded: int = _cat.health
			_paw.take_damage(3, _paw.global_position)
			_check(_cat.health == guarded, "hitting a raised paw does nothing")
			_phase = 2
		2:
			print("-- enough punished swipes and it leaves")
			_paw.set_vulnerable(true)
			var guard := 0
			while not _cat.is_defeated and guard < 30:
				_paw.take_damage(1, _paw.global_position)
				guard += 1
			_check(_cat.is_defeated, "the cat can be beaten through the paw alone")
			_check(_defeated == 1, "and says so once")
			_check(_cat.state == CatBoss3D.State.RETREATING, "it retreats")
			_check(SaveGame.is_boss_defeated("tabletop_cat"), "the win is saved")
			_elapsed = 0.0
			_phase = 3
		3:
			if _elapsed < 2.5:
				return false
			_check(_level.exit_state == Level3D.ExitState.UNLOCKED, "and the way out opens")

			print("-- the table is lethal at the edges")
			var death: Area3D = _level.get_node("DeathZone")
			_check(death.global_position.y < -4.0,
				"the drop zone is well below the table (%.1f)" % death.global_position.y)
			_player.global_position = Vector3(27, -9.0, 0)
			_player.health = 5.0
			var fell_from: float = _player.health
			_player.fall_into_pit()
			_check(_player.health < fell_from, "falling off the table costs him")
			_phase = 4
		4:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
			if _failures.is_empty():
				print("CAT TEST PASS")
			else:
				print("CAT TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
		9:
			print("CAT TEST FAIL: no paw was produced")
			quit(1)
	return false
