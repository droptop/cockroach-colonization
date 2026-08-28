extends SceneTree

## The spoon is feeble on its own — its damage comes from other people's
## ammunition. That only means anything if something actually shoots at you,
## so this covers both halves: a fly that spits, and batting the spit back.
##
## Run with:
##   godot --headless --path . --script tests/reflect_test.gd

var _phase := 0
var _frames := 0
var _elapsed := 0.0
var _level: Node
var _player: Node
var _fly: Node
var _caught: Projectile3D
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
	SaveGame.save_path = "user://test_reflect_scratch.cfg"
	SaveGame.clear()
	print("-- the spoon is a defensive weapon")
	var stats: Dictionary = Player3D.WEAPON_STATS
	_check(stats.has("spoon"), "it exists")
	_check(stats["spoon"].get("reflects", false), "and it reflects")
	_check(stats["spoon"].damage <= 1,
		"and is feeble by itself (%d damage)" % stats["spoon"].damage)
	var reflecting := 0
	for id in stats:
		if stats[id].get("reflects", false):
			reflecting += 1
	_check(reflecting == 1, "nothing else reflects, so the niche is its own")

	_level = (load("res://world/levels/tabletop_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")
	_fly = _level.get_node("Fly1")


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	if _phase == 1 and _caught == null:
		var flying := _shots()
		if not flying.is_empty():
			_caught = flying[0]
	if _frames > 20000:
		print("REFLECT TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 15:
				return false
			print("-- something finally shoots back")
			_check(_fly.spits, "the tabletop's flies are spitters")
			_check(_level.get_node_or_null("Spoon1") != null,
				"and there is a spoon in front of them")
			_check(_shots().is_empty(), "nothing in the air yet")
			# A narrow band, and both edges are real. Closer than ~4.5 and it
			# dives instead of spitting — the fly working correctly and the test
			# asking the wrong question. Further than Encounter.ON_SCREEN_X and
			# it holds fire, because shooting from off-camera is now against the
			# rules. Fly1 is at x=23, so 18 sits between the two.
			_player.global_position = Vector3(18.0, 0.5, 0)
			_fly._spit_timer = 0.0
			_elapsed = 0.0
			_phase = 1
		1:
			# Wait for one to appear, rather than for a fixed interval.
			if _caught == null and _elapsed < 4.0:
				return false
			_check(_caught != null, "the fly spits")
			if _caught == null:
				_phase = 9
				return false
			var glob: Projectile3D = _caught
			_check(glob.hits & 2 != 0, "its spit is looking for the PLAYER")
			_check(glob.hits & 4 == 0, "and not for its own side")
			_before_damage = glob.damage

			print("-- batting it back turns it around")
			_player.collect_weapon("spoon")
			_player.facing = 1
			var was_x := glob.velocity.x
			glob.reflect(_player.facing)
			_check(glob.velocity.x > 0.0,
				"it now travels the way he is facing (%.1f from %.1f)" % [glob.velocity.x, was_x])
			_check(glob.damage > _before_damage,
				"and hits harder for the timing (%d from %d)" % [glob.damage, _before_damage])
			_check(glob.hits & 4 != 0, "and can now hurt the thing that fired it")
			_check(glob.hits & 2 == 0,
				"and can no longer hurt him — otherwise reflecting is just dodging")
			_phase = 2
		2:
			print("-- and a returned shot really does hurt them")
			var glob := Projectile3D.new()
			glob.damage = 2
			glob.fall_rate = 0.0
			glob.hits = 1 | 4
			_level.add_child(glob)
			_fly.health = 9
			_hp_before = _fly.health
			glob.launch(_fly.global_position - Vector3(2.5, 0, 0), Vector3(1, 0, 0), 1.0)
			_elapsed = 0.0
			_phase = 3
		3:
			if _elapsed < 0.5:
				return false
			_check(_fly.health < _hp_before,
				"the fly takes its own spit back (%d -> %d)" % [_hp_before, _fly.health])
			_phase = 4
		4:
			if _failures.is_empty():
				print("REFLECT TEST PASS")
			else:
				print("REFLECT TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
		9:
			print("REFLECT TEST FAIL: nothing was spat")
			quit(1)
	return false


var _before_damage := 0
var _hp_before := 0
