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
var _exit_x := 0.0
var _walked := 0.0
var _arrived: Node3D
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

			# What she leaves behind has to be REACHABLE. Everything she drops
			# was positioned relative to her, and she stands six metres up on a
			# counter: the pantry opened at her shoulder and the spoils were
			# saved only by a hand-tuned offset that happened to suit this one
			# level. A reward you can see and cannot touch is worse than none.
			var floor_y: float = _player.global_position.y
			var high: Array[String] = []
			var rewards := 0
			for child in _level.get_children():
				if child is RewardPickup3D:
					rewards += 1
					var dy: float = (child as Node3D).global_position.y - floor_y
					if dy > 2.0 or dy < -2.0:
						high.append("%.1f m off the floor" % dy)
			_check(rewards > 0, "she leaves spoils (%d)" % rewards)
			_check(high.is_empty(), "and they are within reach%s"
				% ("" if high.is_empty() else " — UNREACHABLE: " + ", ".join(high)))
			var zone: Area3D = _level.get_node_or_null("ExitZone")
			_check(zone != null, "the level has an exit")
			if zone:
				_exit_x = zone.global_position.x
				# And nothing she leaves behind may stand ON the door. The
				# pantry was three metres wide at x 52 with the exit at x 53,
				# so the payoff for beating her was parked on the way out.
				var blocking: Array[String] = []
				for child in _level.get_children():
					if child is MeshInstance3D and child.get_script() == null:
						var at: Vector3 = (child as Node3D).global_position
						var d: float = absf(at.x - _exit_x)
						# At DOOR height. The first version of this compared x
						# only and flagged a foreground pipe eleven metres up.
						var dy: float = absf(at.y - zone.global_position.y)
						# Something with real BULK. Flat floor decals share the
						# door's x and y and occlude nothing; a grout line 2 cm
						# thick is not what hides an exit.
						var bulky := false
						var mesh := (child as MeshInstance3D).mesh
						if mesh is BoxMesh:
							bulky = (mesh as BoxMesh).size.y > 0.6
						elif mesh != null:
							bulky = true
						if d < 1.6 and dy < 2.5 and bulky:
							blocking.append("%s at %.1f" % [child.name,
								(child as Node3D).global_position.x])
				_check(blocking.is_empty(), "and nothing is parked on it%s"
					% ("" if blocking.is_empty()
						else " — BLOCKING: " + ", ".join(blocking)))
			# Put him back at HER, on the floor, and make him WALK.
			_player.global_position = Vector3(
				_granny.global_position.x, _player.global_position.y, 0.0)
			_player.velocity = Vector3.ZERO
			_next(4)
		4:
			# WALK to the door. Teleporting into the exit is what hid the real
			# bug: the arena's invisible collider was never actually released,
			# so the gate wound up and a solid wall stayed behind it. He beat
			# her and could not reach the door, and every teleporting test
			# passed the whole time.
			Input.action_press("move_right")
			_walked = maxf(_walked, _player.global_position.x)
			if _level.exit_state != Level3D.ExitState.TRANSITION and _step < 20.0:
				return false
			Input.action_release("move_right")
			_check(_level.exit_state == Level3D.ExitState.TRANSITION,
				"and he can WALK from her to the door (reached x %.1f of %.1f)"
					% [_walked, _exit_x])
			_next(5)
		5:
			# THE THING THAT ACTUALLY MATTERS. Reaching TRANSITION only means
			# the level agreed to leave; the report is that it never arrives
			# anywhere. change_scene_to_file happens 1.4s later and nothing
			# here was checking it, so "you cannot get to the next level"
			# stayed true through a passing test.
			if root.get_child_count() > 0:
				for child in root.get_children():
					if child != _level and child is Node3D:
						_arrived = child
			if _arrived == null and _step < 12.0:
				return false
			_check(_arrived != null,
				"and the next level actually loads (%s)"
					% (_arrived.name if _arrived else "NOTHING — stuck in the kitchen"))
			_next(6)
		6:
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
