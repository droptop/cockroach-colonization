extends SceneTree

## The first ranged weapon. Hold to draw, release to fire; a full draw hits
## harder and flies flatter than a panicked tap.
##
## Run with:
##   godot --headless --path . --script tests/projectile_test.gd

var _phase := 0
var _frames := 0
var _elapsed := 0.0
var _level: Node
var _player: Node
var _target: Node
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _shots() -> Array[Projectile3D]:
	var found: Array[Projectile3D] = []
	for child in _level.get_children():
		if child is Projectile3D and not child.is_queued_for_deletion():
			found.append(child)
	return found


func _initialize() -> void:
	# HERMETIC: the player reads bought upgrades off the save on spawn now,
	# so a test without a scratch save measures whatever was last played.
	SaveGame.save_path = "user://test_projectile_scratch.cfg"
	SaveGame.clear()
	print("-- the rubber band is a different kind of weapon")
	var stats: Dictionary = Player3D.WEAPON_STATS
	_check(stats.has("slingshot"), "it exists")
	_check(stats["slingshot"].get("charge", false), "and it charges rather than swinging")
	_check(stats["slingshot"].get("projectile_speed", 0.0) > 0.0, "and it throws something")
	var charging := 0
	for id in stats:
		if stats[id].get("charge", false):
			charging += 1
	_check(charging == 1, "it is the only charged weapon, so the others are unaffected")

	_level = (load("res://world/levels/street_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")
	_target = _level.get_node("Mantis")


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	if _frames > 20000:
		print("PROJECTILE TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 12:
				return false
			print("-- it is out there to find")
			_check(_level.get_node_or_null("Slingshot1") != null,
				"the street has one lying in it")
			_player.collect_weapon("slingshot")
			_check(_player.active_weapon == "slingshot", "and it can be equipped")
			_check(_shots().is_empty(), "nothing has been fired yet")

			print("-- holding draws it, releasing fires")
			_player.global_position = Vector3(20, 0.6, 0)
			_player.facing = 1
			_player._bite_cooldown_timer = 0.0
			Input.action_press("attack")
			_elapsed = 0.0
			_phase = 1
		1:
			if _elapsed < 0.3: # part-way through a 0.55 s draw
				return false
			_check(_player._charge_timer > 0.0,
				"holding builds charge (%.2f)" % _player._charge_timer)
			_check(_shots().is_empty(), "and fires nothing while still held")
			Input.action_release("attack")
			_elapsed = 0.0
			_phase = 2
		2:
			# Settle in REAL time, not one idle frame. Releasing and checking on
			# consecutive idle frames can span no physics frame at all, and the
			# fire happens in _physics_process. This passed by luck first time.
			if _elapsed < 0.25:
				return false
			var shots := _shots()
			_check(shots.size() == 1, "releasing fires exactly one shot (%d)" % shots.size())
			if shots.is_empty():
				_phase = 9
				return false
			_check(shots[0].velocity.x > 0.0,
				"it travels the way he is facing (%.1f)" % shots[0].velocity.x)
			_check(_player._charge_timer == 0.0, "and the draw resets")
			# A short draw should lob; hold on to the value to compare.
			_snap_rise = shots[0].velocity.y
			shots[0].queue_free()
			_player._bite_cooldown_timer = 0.0
			_elapsed = 0.0
			_phase = 3
		3:
			# Now a full draw. Every wait here is real seconds: releasing and
			# checking on consecutive IDLE frames can span no physics frame at
			# all, and the fire happens in _physics_process.
			Input.action_press("attack")
			if _elapsed < 0.9: # past charge_time of 0.55
				return false
			Input.action_release("attack")
			_elapsed = 0.0
			_phase = 4
		4:
			if _elapsed < 0.25:
				return false
			var shots := _shots()
			_check(shots.size() == 1, "a full draw fires too (%d)" % shots.size())
			if not shots.is_empty():
				_check(shots[0].velocity.y < _snap_rise,
					"and flies flatter than a snap shot (%.2f vs %.2f)"
						% [shots[0].velocity.y, _snap_rise])
				_check(shots[0].damage >= 2, "and hits harder (%d)" % shots[0].damage)
				# FIRE it into the mantis's back rather than parking it alongside:
				# a parked shot just falls to the pavement, which is a hit on
				# scenery and tells us nothing. Behind, because its guard would
				# absorb a frontal one — a mantis rule, not a projectile one.
				_target.facing = 1
				_target.state = MantisBoss3D.State.TRACKING
				shots[0].fall_rate = 0.0 # flat, so the test measures the hit not the arc
				shots[0].launch(_target.global_position - Vector3(2.5, -0.9, 0),
					Vector3(1, 0, 0), 1.0)
			_hp_before = _target.health
			_elapsed = 0.0
			_phase = 5
		5:
			if _elapsed < 0.4:
				return false
			_check(_target.health < _hp_before,
				"a shot that reaches an enemy hurts it (%d -> %d)"
					% [_hp_before, _target.health])
			_check(_shots().is_empty(), "and is spent on impact")
			_phase = 6
		6:
			print("-- a shot that hits nothing does not fly forever")
			var stray := Projectile3D.new()
			stray.lifetime = 0.25
			_level.add_child(stray)
			# High over the level, aimed at open air.
			stray.launch(Vector3(20, 60, 0), Vector3(1, 1, 0), 1.0)
			_check(not _shots().is_empty(), "the stray is in flight")
			_elapsed = 0.0
			_phase = 7
		7:
			if _elapsed < 1.2:
				return false
			_check(_shots().is_empty(), "it expires on its own")
			_phase = 8
		8:
			if _failures.is_empty():
				print("PROJECTILE TEST PASS")
			else:
				print("PROJECTILE TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
		9:
			print("PROJECTILE TEST FAIL: nothing was fired")
			quit(1)
	return false


var _snap_rise := 0.0
var _hp_before := 0
