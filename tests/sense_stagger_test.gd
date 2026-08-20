extends SceneTree

## The antennae pulse (E) staggers normal enemies, and deliberately does NOT
## touch bosses.
##
## Both halves matter. The pulse has a 9 unit radius and no aiming, so if it
## reached bosses it would be a way around all six boss verbs at once: you could
## interrupt the Queen without ever cutting a web, or the mantis without ever
## getting behind its guard. "Bosses do not implement stagger()" is a design
## decision, so it is asserted here rather than left as a thing to remember.
##
## The stagger half only presses the button. Calling enemy.stagger() directly
## would prove the method works and say nothing about whether the pulse ever
## reaches it, which is exactly how three destructibles shipped unhittable.
##
## Run with:
##   godot --headless --path . --script tests/sense_stagger_test.gd

var _phase := 0
var _t := 0.0
var _step_t := 0.0
var _level: Node
var _player: Node
var _ant: Node
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _next(phase: int) -> void:
	_phase = phase
	_step_t = 0.0


func _initialize() -> void:
	print("-- normal enemies answer stagger(), bosses do not")
	for path in ["res://enemies/ant/ant_3d.gd", "res://enemies/spider/spider_3d.gd",
			"res://enemies/fly/fly_3d.gd"]:
		var made = (load(path) as GDScript).new()
		_check(made.has_method("stagger"), "%s can be staggered" % path.get_file())
		made.free()
	var boss_offenders: Array[String] = []
	for path in ["res://enemies/rat/rat_boss_3d.gd",
			"res://enemies/cat/cat_boss_3d.gd",
			"res://enemies/granny/granny_boss_3d.gd",
			"res://enemies/mantis/mantis_boss_3d.gd",
			"res://enemies/wasp/wasp_boss_3d.gd",
			"res://enemies/spider_queen/spider_queen_3d.gd"]:
		var script := load(path) as GDScript
		if script == null:
			continue
		var made = script.new()
		if made.has_method("stagger"):
			boss_offenders.append(path.get_file())
		made.free()
	_check(boss_offenders.is_empty(),
		"no boss is staggerable%s" % ("" if boss_offenders.is_empty()
			else " — BYPASSABLE: " + ", ".join(boss_offenders)))

	_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")


func _process(delta: float) -> bool:
	_t += delta
	_step_t += delta
	if _t > 60.0:
		print("SENSE STAGGER TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _step_t < 1.0:
				return false
			print("-- pressing E actually reaches an enemy")
			_ant = (load("res://enemies/ant/ant_3d.tscn") as PackedScene).instantiate()
			_level.add_child(_ant)
			_next(1)
		1:
			# Well inside sense_radius, and the ant needs a frame to be ready.
			_ant.global_position = _player.global_position + Vector3(2.0, 0, 0)
			if _step_t < 0.5:
				return false
			_check(_ant._stagger_timer == 0.0, "the ant starts unstaggered")
			_player._sense_timer = 0.0
			_player._invincibility_timer = 99.0
			Input.action_press("interact")
			_next(2)
		2:
			# Wait for the EFFECT, not a fixed interval: is_action_just_pressed
			# needs a frame, and headless idle frames are not physics steps.
			if _ant._stagger_timer <= 0.0 and _step_t < 3.0:
				return false
			Input.action_release("interact")
			_check(_ant._stagger_timer > 0.0,
				"pressing E staggers a nearby ant (%.2f s left)" % _ant._stagger_timer)
			_next(3)
		3:
			# And it wears off rather than freezing the enemy forever.
			if _ant._stagger_timer > 0.0 and _step_t < 5.0:
				return false
			_check(_ant._stagger_timer <= 0.0, "and it wears off")
			_next(4)
		4:
			if _failures.is_empty():
				print("SENSE STAGGER TEST PASS")
			else:
				print("SENSE STAGGER TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
			return true
	return false
