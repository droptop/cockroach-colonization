extends SceneTree

## The Spider Queen: untouchable until her webs are cut, and the arena seals
## once the fight starts.
##
## Run with:
##   godot --headless --path . --script tests/spider_queen_test.gd

const TEST_SAVE := "user://test_queen.cfg"

var _phase := 0
var _frames := 0
var _elapsed := 0.0
var _level: Node
var _player: Node
var _queen: SpiderQueen3D
var _defeated := 0
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _anchors() -> Array[WebAnchor3D]:
	var found: Array[WebAnchor3D] = []
	for child in _level.get_children():
		if child is WebAnchor3D and not child.is_queued_for_deletion():
			found.append(child)
	return found


func _initialize() -> void:
	SaveGame.save_path = TEST_SAVE
	SaveGame.clear()
	_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")
	_queen = _level.get_node("SpiderQueen")


func _cut_all_webs() -> void:
	for anchor in _anchors():
		anchor.take_damage(99, anchor.global_position + Vector3(1, 0, 0))


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	if _frames > 20000:
		print("QUEEN TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 12:
				return false
			print("-- the drain now ends in a boss")
			_check(_level.exit_state == Level3D.ExitState.LOCKED,
				"the way out of the drain is gated behind her")
			_queen.defeated.connect(func() -> void: _defeated += 1)

			print("-- she cannot be touched while she hangs")
			_check(_queen.immune_to_damage, "suspended, she is immune")
			var before: int = _queen.health
			_queen.take_damage(99, _queen.global_position)
			_check(_queen.health == before, "hitting her does nothing at all")

			print("-- the webs are the way in")
			var anchors := _anchors()
			_check(anchors.size() == _queen.anchor_count,
				"she spins %d anchors (%d)" % [_queen.anchor_count, anchors.size()])
			if anchors.is_empty():
				_phase = 9
				return false
			_check(anchors[0].collision_layer == 4,
				"anchors sit on the enemy layer, so the normal bite finds them")
			# High enough to need the wing bar, not just a jump.
			var ledge_top := 7.4
			_check(anchors[0].global_position.y - ledge_top > 2.0,
				"and hang out of standing-jump reach (%.1f m up)"
					% (anchors[0].global_position.y - ledge_top))
			anchors[0].take_damage(1, anchors[0].global_position)
			_check(anchors[0].health == anchors[0].max_health - 1, "they take damage")
			_check(_queen.state == SpiderQueen3D.State.SUSPENDED,
				"cutting one is not enough")
			_phase = 1
		1:
			print("-- cutting the last one brings her down")
			_cut_all_webs()
			_elapsed = 0.0
			_phase = 2
		2:
			if _elapsed < 0.9: # the drop tween
				return false
			_check(_queen.state == SpiderQueen3D.State.EXPOSED,
				"she is down (state %d)" % _queen.state)
			_check(not _queen.immune_to_damage, "and finally vulnerable")
			var before: int = _queen.health
			_queen.take_damage(2, _queen.global_position + Vector3(1, 0, 0))
			_check(_queen.health == before - 2, "now she takes damage")
			_check(_level.exit_state == Level3D.ExitState.BOSS_ACTIVE,
				"the encounter is live")
			# Stand him in it first. The walls now answer to where he actually
			# is: they drop while he is outside, so that being knocked out of
			# the arena cannot lock him out of a fight he still has to win.
			# Asserting the seal from the spawn point tested nothing real.
			_player.global_position.x = _queen.global_position.x
			_level._process(0.016)
			_check(_level._arena_walls != null,
				"and the arena seals once he is inside it")
			_phase = 3
		3:
			print("-- once down, she stays down")
			_queen._timer = 0.0 # what used to end the exposed window
			_elapsed = 0.0
			_phase = 4
		4:
			if _elapsed < 2.0: # long enough that the old climb would have run
				return false
			# She used to go back up and re-spin the lot, which took the fight
			# away again the moment you had earned it.
			_check(_queen.state == SpiderQueen3D.State.EXPOSED,
				"still on the floor (state %d)" % _queen.state)
			_check(not _queen.immune_to_damage, "and still hittable")
			_check(_anchors().is_empty(),
				"with no fresh webs (%d)" % _anchors().size())
			print("-- beaten, she drops for good")
			var guard := 0
			while not _queen.is_defeated and guard < 20:
				_queen.lose_health(1, _queen.global_position)
				guard += 1
			_check(_queen.is_defeated, "she can be finished")
			_check(_defeated == 1, "and says so once")
			_check(SaveGame.is_boss_defeated("drain_spider_queen"), "the win is saved")
			_check(_anchors().is_empty(), "her webs go with her")
			_elapsed = 0.0
			_phase = 5
		5:
			if _elapsed < 2.5:
				return false
			_check(_level.exit_state == Level3D.ExitState.UNLOCKED, "the grate opens")
			_check(_level._arena_walls == null,
				"and the arena unseals, so he is never shut in with a dead boss")
			_phase = 6
		6:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
			if _failures.is_empty():
				print("QUEEN TEST PASS")
			else:
				print("QUEEN TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
		9:
			print("QUEEN TEST FAIL: she spun no webs")
			quit(1)
	return false
