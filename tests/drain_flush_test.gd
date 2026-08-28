extends SceneTree

## The drain flush: it falls, it runs along what it lands on, and it washes
## Harry with it.
##
## Every one of those is a thing that can silently not happen. A hazard that
## spawns and drops straight through the level does nothing; one that lands and
## then sits there does nothing; one that never overlaps him does nothing. None
## of them error, and all three look like "the water didn't get me".
##
## The last check is the one that matters most: it must give WARNING before it
## lets go. Being shoved off a ledge to your death by something unsignalled is
## the difference between a hazard and a cheat.
##
## Run with:
##   godot --headless --path . --script tests/drain_flush_test.gd

var _phase := 0
var _t := 0.0
var _step := 0.0
var _level: Node
var _player: Node3D
var _flush: DrainFlush3D
var _head: Node3D
var _start_y := 0.0
var _fell := false
var _turned := false
var _pushed := 0.0
var _stuck: Array[Node] = []
var _stuck_deadline := 0.0
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
	SaveGame.save_path = "user://test_drain_flush_scratch.cfg"
	SaveGame.clear()
	_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")


func _find_head() -> Node3D:
	for child in _level.get_children():
		if child is Area3D and child.get_script() != null \
				and child.has_method("_wash"):
			return child
	return null


func _process(delta: float) -> bool:
	_t += delta
	_step += delta
	if _t > 90.0:
		print("DRAIN FLUSH TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _step < 1.0:
				return false
			print("-- the drain has a flush under its storm grate")
			for child in _level.get_children():
				if child is DrainFlush3D:
					_flush = child
			_check(_flush != null, "a flush is placed")
			if _flush == null:
				_next(9)
				return false
			_check(_flush.warning_time > 0.5,
				"it warns before it lets go (%.2fs)" % _flush.warning_time)
			# Park Harry out of the way while the first one is measured.
			_player.global_position = _flush.global_position + Vector3(0, -40, 0)
			_flush._timer = 0.4
			_next(1)
		1:
			if _head == null:
				_head = _find_head()
			if _head == null and _step < 8.0:
				return false
			_check(_head != null, "and it releases a slug of water")
			if _head == null:
				_next(9)
				return false
			_start_y = _head.global_position.y
			_next(2)
		2:
			if not is_instance_valid(_head):
				_check(_fell, "it fell (freed before it could be measured)")
				_next(3)
				return false
			if _head.global_position.y < _start_y - 1.5:
				_fell = true
			if _head._dir != 0.0:
				_turned = true
			if not (_fell and _turned) and _step < 12.0:
				return false
			_check(_fell, "it falls out of the grate")
			_check(_turned,
				"and runs left or right off whatever it lands on (dir %.0f)"
					% _head._dir)
			_next(3)
		3:
			# Now stand in one and be washed. Driven by putting him IN its path,
			# not by calling _wash: an overlap that never happens is exactly the
			# failure this is here to catch.
			print("-- and it takes him with it")
			_head = null
			_flush._timer = 0.4
			_next(4)
		4:
			if _head == null:
				_head = _find_head()
			if _head == null and _step < 8.0:
				return false
			if _head == null:
				_check(false, "a second flush was released")
				_next(9)
				return false
			_next(5)
		5:
			if not is_instance_valid(_head):
				_check(_pushed > 0.0, "he was washed along (%.1f)" % _pushed)
				_next(6)
				return false
			# Hold him in its path, and watch what it does to his velocity.
			_player.global_position = _head.global_position
			_player._invincibility_timer = 9999.0
			_pushed = maxf(_pushed, absf(_player.velocity.x))
			if _pushed < 1.0 and _step < 6.0:
				return false
			_check(_pushed > 1.0,
				"standing in it throws him along (%.1f m/s)" % _pushed)
			_next(6)
		6:
			# The one it must never do: wedge. Drop several into the level and
			# assert that every one of them is gone within its lifetime cap.
			# "It gets stuck" was the actual report, and a hazard that parks
			# itself in a corner is worse than no hazard at all.
			print("-- and none of them can wedge")
			for i in 6:
				var extra := DrainFlush3D.FlushHead.new()
				extra.setup(_flush)
				_level.add_child(extra)
				# Deliberately awkward spots: hard against the shaft walls and
				# down in the trough between them.
				extra.global_position = Vector3(31.8 + float(i) * 1.2, 6.0, 0)
				_stuck.append(extra)
			_stuck_deadline = _flush.max_lifetime + 3.0
			_next(7)
		7:
			var alive := 0
			for f in _stuck:
				if is_instance_valid(f):
					alive += 1
			if alive > 0 and _step < _stuck_deadline:
				return false
			_check(alive == 0,
				"every flush cleared itself within %.0fs (%d still there)"
					% [_stuck_deadline, alive])
			_next(8)
		8:
			if _failures.is_empty():
				print("DRAIN FLUSH TEST PASS")
			else:
				print("DRAIN FLUSH TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
			return true
		9:
			print("DRAIN FLUSH TEST FAIL: nothing to measure")
			quit(1)
			return true
	return false
