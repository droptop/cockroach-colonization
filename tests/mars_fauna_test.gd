extends SceneTree

## Do the two Mars-only enemies actually DO anything?
##
## This exists because the dust hopper never had. Its script failed to parse
## (see `scripts_load_test`), so both hoppers shipped as scriptless boxes, and
## because nothing ever spawned one in a test, nothing noticed. The gasbag did
## work, but only by luck: it had exactly as much coverage, which is none.
##
## Compiling is not behaving, so each is held to its whole contract as a player
## meets it: it MOVES on its own, it HURTS on contact, and it DIES to the attack
## button. Not to a `take_damage()` call, which proves nothing about whether a
## swing can reach it.
##
## Run with:
##   godot --headless --path . --script tests/mars_fauna_test.gd

const SUBJECTS := [
	{"node": "Hopper1", "label": "dust hopper", "aim_up": false},
	{"node": "Gasbag2", "label": "gasbag", "aim_up": true},
]
## REAL seconds throughout: headless idle frames run far faster than 60/s.
const MOVE_SECONDS := 4.0
const BITE_TIMEOUT := 6.0
const KILL_TIMEOUT := 10.0
const HANDS_OFF_SECONDS := 1.0
## Basin2 ends at x 38 and the arena starts at x 40. Nothing is under the gap.
const PIT_EDGE_X := 38.0
const PIT_FAR_X := 40.0
const BRINK_SECONDS := 7.0
const BAIT_HEIGHT := 6.0
const RUN_TIMEOUT := 90.0

var _level: Node3D
var _player: Node3D
var _subject: Node3D
var _index := 0
var _phase := 0
var _phase_ms := 0
var _start := Vector3.ZERO
var _strayed := 0.0
var _health_before := 0.0
var _swing_ms := 0
var _swinging := false
var _lowest := 0.0
var _began_ms := Time.get_ticks_msec()
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = "user://test_mars_fauna.cfg"
	SaveGame.clear()
	print("-- the Mars fauna move, bite and die like everything else")
	_load_level()


## A fresh Mars per subject, with the rest of the fauna cleared out, so that
## nothing but the one on trial can bite him or wander into a swing.
func _load_level() -> void:
	if _level:
		_level.free()
	_level = (load("res://world/levels/mars_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = null
	_phase_ms = Time.get_ticks_msec()


func _elapsed() -> float:
	return (Time.get_ticks_msec() - _phase_ms) / 1000.0


func _goto(phase: int) -> void:
	_phase = phase
	_phase_ms = Time.get_ticks_msec()


func _label() -> String:
	return SUBJECTS[_index].label


func _alive() -> bool:
	return is_instance_valid(_subject) and not _subject.is_queued_for_deletion() \
		and int(_subject.get("health")) > 0


func _release_all() -> void:
	for action in ["attack", "move_up"]:
		Input.action_release(action)
	_swinging = false


func _finish() -> void:
	_release_all()
	if _failures.is_empty():
		print("MARS FAUNA TEST PASS")
	else:
		print("MARS FAUNA TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
	quit(0 if _failures.is_empty() else 1)


func _process(_delta: float) -> bool:
	# Never wait for ever: a stalled phase has to end the run, loudly.
	if Time.get_ticks_msec() - _began_ms > RUN_TIMEOUT * 1000.0:
		_check(false, "finished inside %.0f s (stalled in phase %d on the %s)" % [
			RUN_TIMEOUT, _phase, _label() if _index < SUBJECTS.size() else "pit"])
		_finish()
		return true
	# Gone before its trial was over (fell out of the level, say). Phase 3
	# expects it to vanish; the two before it do not.
	if (_phase == 1 or _phase == 2) and not is_instance_valid(_subject):
		_check(false, "%s: is still in the level to be tested" % _label())
		_goto(4)
		return false
	match _phase:
		0: # let the level settle, then pick the subject up
			if _elapsed() < 0.5:
				return false
			for node in get_nodes_in_group("player"):
				_player = node
			_subject = _level.get_node_or_null(SUBJECTS[_index].node) as Node3D
			if _player == null or _subject == null:
				_check(false, "%s: is placed on Mars" % _label())
				_finish()
				return true
			_check(_subject.get_script() != null and _subject.has_method("take_damage"),
				"%s: has its script" % _label())
			for other in get_nodes_in_group("enemies"):
				if other != _subject and not other.is_in_group("bosses"):
					other.free()
			_start = _subject.global_position
			_strayed = 0.0
			_goto(1)
		1: # left alone, it moves
			_strayed = maxf(_strayed, _subject.global_position.distance_to(_start))
			if _elapsed() < MOVE_SECONDS:
				return false
			_check(_strayed > 0.25, "%s: moves on its own (%.2f m)" % [_label(), _strayed])
			_health_before = _player.health
			_goto(2)
		2: # stood next to it, he gets hurt
			if _elapsed() > 0.05 and absf(_player.global_position.x - _subject.global_position.x) > 1.2:
				_player.global_position = Vector3(_subject.global_position.x - 0.5, _start.y + 0.2, 0.0)
				_player.velocity = Vector3.ZERO
			if _player.health < _health_before or _elapsed() > BITE_TIMEOUT:
				_check(_player.health < _health_before, "%s: hurts on contact (it is at %s, he is at %s)" % [
					_label(), _subject.global_position.snappedf(0.1), _player.global_position.snappedf(0.1)])
				_player.health = _player.max_health
				_goto(3)
		3: # and the attack BUTTON kills it
			_player.health = _player.max_health # the subject is on trial here, not him
			# A beat with NO input first: if it dies in this window, something
			# other than the swing killed it and the claim below would be a lie.
			if _elapsed() < HANDS_OFF_SECONDS:
				if not _alive():
					_check(false, "%s: survives until it is actually attacked" % _label())
					_goto(4)
				return false
			if not _alive():
				_release_all()
				_check(true, "%s: dies to the attack button (%.2f s after the first press)" % [
					_label(), _elapsed() - HANDS_OFF_SECONDS])
				_goto(4)
				return false
			if _elapsed() > KILL_TIMEOUT:
				_release_all()
				_check(false, "%s: dies to the attack button (still on %d health at %s, he is at %s)" % [
					_label(), int(_subject.get("health")), _subject.global_position.snappedf(0.1),
					_player.global_position.snappedf(0.1)])
				_goto(4)
				return false
			# Keep up with it and keep FACING it, the way a player chasing it
			# would. He is always put on its left, so he looks right.
			if absf(_player.global_position.x - _subject.global_position.x) > 1.2:
				_player.global_position = Vector3(_subject.global_position.x - 0.5, _start.y + 0.2, 0.0)
				_player.velocity = Vector3.ZERO
			_player.facing = 1 if _subject.global_position.x >= _player.global_position.x else -1
			if SUBJECTS[_index].aim_up:
				Input.action_press("move_up")
			# Press and let go in real time: a held button is one swing.
			if Time.get_ticks_msec() - _swing_ms > 140:
				_swing_ms = Time.get_ticks_msec()
				_swinging = not _swinging
				if _swinging:
					Input.action_press("attack")
				else:
					Input.action_release("attack")
		4:
			_index += 1
			_load_level()
			_goto(0 if _index < SUBJECTS.size() else 5)
		5: # the hopper, hunting, on the brink of the pit before the arena
			if _elapsed() < 0.5:
				return false
			for node in get_nodes_in_group("player"):
				_player = node
			_subject = _level.get_node_or_null("Hopper2") as Node3D
			for other in get_nodes_in_group("enemies"):
				if other != _subject and not other.is_in_group("bosses"):
					other.free()
			# One full bound short of the far side: the obvious hop lands in
			# the two-metre gap between the basin and the arena.
			_subject.global_position = Vector3(PIT_EDGE_X - 1.8, 0.1, 0.0)
			_subject.set("_target", _player)
			_subject.set("state", 1) # CHASE
			_lowest = _subject.global_position.y
			_goto(6)
		6:
			# Bait held just across the pit and out of reach overhead. A bite
			# bounces the hopper backwards, and this is about where it CHOOSES
			# to land, not where it gets knocked.
			_player.global_position = Vector3(PIT_FAR_X + 1.5, BAIT_HEIGHT, 0.0)
			_player.velocity = Vector3.ZERO
			if is_instance_valid(_subject):
				_lowest = minf(_lowest, _subject.global_position.y)
			if _elapsed() < BRINK_SECONDS:
				return false
			_check(is_instance_valid(_subject) and _lowest > -1.0,
				"dust hopper: hunts to the brink of a pit and stays out of it (lowest y %.1f)" % _lowest)
			_finish()
			return true
	return false
