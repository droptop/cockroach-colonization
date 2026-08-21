extends SceneTree

## Can the granny kitchen actually be FINISHED?
##
## The report was "you cannot get past Granny", and the existing granny test
## passes: it checks that her patience drains, that she is immune to weapons,
## that the exit gates on her. All true, and none of it answers the question,
## because every one of those is measured by poking the boss directly.
##
## This one plays the level. It dodges her — moves Harry away from wherever she
## is about to strike — and then walks him into the exit and asserts the level
## actually hands over to the next one. Three separate things have to hold for
## that, and each has been broken at some point today:
##
##   1. her patience has to reach zero from DODGING, which stops being possible
##      if anything is also attacking him while he does it
##   2. the exit has to open when she goes
##   3. the exit has to fire even if he is already stood in it, which
##      body_entered does not do on its own
##
## Run with:
##   godot --headless --path . --script tests/granny_level_completable_test.gd

var _phase := 0
var _t := 0.0
var _step := 0.0
var _level: Node
var _player: Node3D
var _granny: Node
var _start_patience := 0
var _dodge_timer := 0.0
var _dodge_side := 1.0
var _threats_at_start := 0
var _defeated := false
var _unlocked := false
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _next(phase: int) -> void:
	_phase = phase
	_step = 0.0


func _initialize() -> void:
	SaveGame.save_path = "user://test_granny_level.cfg"
	# WIPE IT FIRST. This test beats her, and beating her is persisted, so the
	# scratch save carries "granny_kitchen defeated" into the next run — the
	# level then removes her before the test starts and it fails from the
	# second run onward. It passed alone and failed in the suite, which is the
	# signature of a test that pollutes its own fixture.
	SaveGame.clear()
	_level = (load("res://world/levels/granny_kitchen_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")


## Everything on the floor that could interrupt a dodge.
func _threats() -> int:
	var n := 0
	for child in _level.get_children():
		if child.has_method("stagger"):
			n += 1
	return n


func _process(delta: float) -> bool:
	_t += delta
	_step += delta
	if _t > 120.0:
		print("GRANNY LEVEL TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true

	# He is dodging, not tanking: kept alive so the measurement is about her
	# patience rather than about his health bar.
	if _player and _phase >= 1 and _phase <= 3:
		_player.health = _player.max_health
		_player._invincibility_timer = 9999.0

	match _phase:
		0:
			if _step < 1.0:
				return false
			print("-- the kitchen has a Granny, and she gates the door")
			for child in _level.get_children():
				if child is GrannyBoss3D:
					_granny = child
			_check(_granny != null, "she is there")
			if _granny == null:
				_next(9)
				return false
			_check(_level.exit_state == Level3D.ExitState.LOCKED,
				"the way out starts locked")
			_granny.defeated.connect(func() -> void: _defeated = true)
			_level.exit_state_changed.connect(func(st: int) -> void:
				if st == Level3D.ExitState.UNLOCKED:
					_unlocked = true)
			_start_patience = _granny.health
			_threats_at_start = _threats()
			# Stand in front of her so she engages.
			_player.global_position = _granny.global_position + Vector3(-3.0, 1.0, 0)
			_next(1)
		1:
			# SHE MUST NOT CALL FOR HELP. Her fight is "do not be hit", and her
			# patience drains when she misses, so adds would be summoned BY
			# dodging well and would then stop him dodging at all.
			_check(_granny.summon_count == 0,
				"she does not summon adds into a dodging fight (%d)"
					% _granny.summon_count)
			_next(2)
		2:
			# The dodge. She aims at where he IS when she telegraphs and strikes
			# that spot afterwards, so standing still is what gets you hit no
			# matter where you stand. He has to keep MOVING, further than her
			# strike radius, faster than her telegraph.
			_dodge_timer -= delta
			if _dodge_timer <= 0.0:
				_dodge_timer = 0.35
				_dodge_side = -_dodge_side
				var here := _player.global_position
				_player.global_position = Vector3(
					_granny.global_position.x + _dodge_side * 4.0, here.y, here.z)
				_player.velocity = Vector3.ZERO
			if not _defeated and _step < 60.0:
				return false
			_check(_defeated,
				"dodging drains her patience to nothing (%d -> %d)"
					% [_start_patience, _granny.health])
			_check(_threats() <= _threats_at_start,
				"and she added nothing to the floor while he did it (%d -> %d)"
					% [_threats_at_start, _threats()])
			_next(3)
		3:
			if not _unlocked and _step < 10.0:
				return false
			_check(_unlocked, "beating her opens the way out")
			# Now stand in the exit, the way a player who just won does.
			var zone: Area3D = _level.get_node_or_null("ExitZone")
			_check(zone != null, "the level has an exit")
			if zone:
				_player.global_position = zone.global_position
				_player.velocity = Vector3.ZERO
			_next(4)
		4:
			if _level.exit_state != Level3D.ExitState.TRANSITION and _step < 8.0:
				return false
			_check(_level.exit_state == Level3D.ExitState.TRANSITION,
				"and walking into it actually leaves the kitchen (state %d)"
					% _level.exit_state)
			_next(5)
		5:
			if _failures.is_empty():
				print("GRANNY LEVEL TEST PASS")
			else:
				print("GRANNY LEVEL TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
			return true
		9:
			print("GRANNY LEVEL TEST FAIL: no Granny to fight")
			quit(1)
			return true
	return false
