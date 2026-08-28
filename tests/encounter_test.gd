extends SceneTree

## Encounter fairness: nothing attacks from off-camera, and only so many things
## attack at once.
##
## This is a generic-invariant test, the kind that has earned its keep three
## times now — the perf budget, reachability, and the traversal smoke test each
## caught something every feature test happily passed over. It asks the same two
## questions of whatever enemies a level happens to contain, so a fly added to a
## level next month is covered without anyone remembering to cover it.
##
## Run with:
##   godot --headless --path . --script tests/encounter_test.gd

var _phase := 0
var _frames := 0
var _elapsed := 0.0
var _level: Node
var _player: Node
var _spiders: Array[Node] = []
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _attacking() -> int:
	return root.get_tree().get_nodes_in_group(Encounter.ATTACKING).size()


func _initialize() -> void:
	# HERMETIC: the player reads bought upgrades off the save on spawn now,
	# so a test without a scratch save measures whatever was last played.
	SaveGame.save_path = "user://test_encounter_scratch.cfg"
	SaveGame.clear()
	print("-- the rule knows what the camera can see")
	# Derived from the real rig rather than asserted as a magic number: camera
	# 8.5 back, 50 deg vertical fov, 16:9. If someone pulls the camera in, this
	# fails and the constant gets revisited, which is the point.
	var half_height: float = 8.5 * tan(deg_to_rad(50.0) * 0.5)
	var half_width: float = half_height * (16.0 / 9.0)
	_check(Encounter.ON_SCREEN_X <= half_width,
		"the on-screen limit (%.1f) is inside what the camera actually shows (%.1f)"
			% [Encounter.ON_SCREEN_X, half_width])
	_check(Encounter.ON_SCREEN_X > 4.5,
		"but wider than a spider's chase range, or nothing could ever reach him")
	_check(Encounter.MAX_ATTACKERS >= 1, "at least one thing may always attack")

	_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	if _frames > 20000:
		print("ENCOUNTER TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 25:
				return false
			print("-- nobody starts out committed")
			_check(_attacking() == 0, "the attacking group is empty at rest (%d)" % _attacking())

			# Enough spiders that the cap has to say no to somebody.
			var source := load("res://enemies/spider/spider_3d.tscn") as PackedScene
			for i in Encounter.MAX_ATTACKERS + 2:
				var spider := source.instantiate()
				_level.add_child(spider)
				spider.global_position = _player.global_position \
					+ Vector3(1.2 + 0.35 * float(i), 0.4, 0)
				_spiders.append(spider)
			_check(_spiders.size() > Encounter.MAX_ATTACKERS,
				"%d spiders for %d slots, so the cap has to bind"
					% [_spiders.size(), Encounter.MAX_ATTACKERS])
			_elapsed = 0.0
			_phase = 1
		1:
			# Real seconds, not frames: headless idle frames are not 1/60 apart.
			if _elapsed < 2.5:
				# Check the invariant EVERY frame, not just at the end — a cap
				# that holds when you look at it and slips in between is not a
				# cap. This is the assertion the whole test exists for.
				if _attacking() > Encounter.MAX_ATTACKERS:
					_check(false, "%d attacked at once, cap is %d"
						% [_attacking(), Encounter.MAX_ATTACKERS])
					_phase = 2
				return false
			print("-- the crowd takes turns")
			_check(true, "never more than %d committed across 2.5s of a real crowd"
				% Encounter.MAX_ATTACKERS)
			var lunged := 0
			for spider in _spiders:
				if is_instance_valid(spider) and spider.state == spider.State.ATTACK:
					lunged += 1
			_check(_attacking() > 0 or lunged > 0,
				"and somebody did get a turn, so the cap is not just off (%d)" % _attacking())
			_phase = 2
		2:
			print("-- and distance is what holds the rest back, not luck")
			var far: Node3D = _spiders[0]
			if not is_instance_valid(far):
				_phase = 3
				return false
			far.global_position = _player.global_position \
				+ Vector3(Encounter.ON_SCREEN_X + 4.0, 0.4, 0)
			Encounter.release(far)
			_check(not Encounter.on_screen(far, _player), "a spider off the side is off-screen")
			_check(not Encounter.may_commit(far, _player),
				"and it is not allowed to attack from there")
			far.global_position = _player.global_position + Vector3(1.5, 0.4, 0)
			_check(Encounter.on_screen(far, _player), "walk it back on and it is visible")

			print("-- holding a token does not block its own re-check")
			Encounter.commit(far)
			_check(Encounter.may_commit(far, _player),
				"an enemy mid-attack may keep attacking, or it aborts its own lunge")
			Encounter.release(far)
			_phase = 3
		3:
			print("-- a boss is exempt, because a boss IS the fight")
			var boss := _level.get_node_or_null("SpiderQueen")
			if boss == null:
				for child in _level.get_children():
					if child is BaseBoss3D:
						boss = child
			_check(boss != null, "the drain has a boss to ask about")
			if boss:
				# Even standing right on the cap, off-screen, in a full house.
				for spider in _spiders:
					Encounter.commit(spider)
				boss.global_position = _player.global_position \
					+ Vector3(Encounter.ON_SCREEN_X + 20.0, 0, 0)
				_check(Encounter.may_commit(boss, _player),
					"it does not queue behind its own adds")
				for spider in _spiders:
					Encounter.release(spider)
			_phase = 4
		4:
			print("-- and the token cannot leak")
			var doomed: Node = _spiders[1]
			if is_instance_valid(doomed):
				# Park the rivals out of reach first. They are stood next to him
				# and will legitimately take a freed slot within the settle time,
				# which is correct behaviour and made this read as a leak.
				for other in _spiders:
					if other != doomed and is_instance_valid(other):
						Encounter.release(other)
						(other as Node3D).global_position = \
							_player.global_position + Vector3(120.0, 0, 0)
				Encounter.commit(doomed)
				var held := _attacking()
				doomed.queue_free()
				_elapsed = 0.0
				_held_before = held
				_phase = 5
			else:
				_phase = 6
		5:
			if _elapsed < 0.3:
				return false
			# The reason the count is a group and not an integer: an enemy
			# killed mid-lunge would otherwise throttle the level forever.
			_check(_attacking() < _held_before,
				"an enemy that dies mid-attack gives its slot back (%d -> %d)"
					% [_held_before, _attacking()])
			_phase = 6
		6:
			if _failures.is_empty():
				print("ENCOUNTER TEST PASS")
			else:
				print("ENCOUNTER TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
	return false


var _held_before := 0
