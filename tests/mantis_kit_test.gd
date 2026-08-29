extends SceneTree

## The mantis KIT (BACKLOG item 19) and the wasp's syrup priority (item 14).
##
## Mantis: the spinning-blade charge crosses the arena unguarded and ends
## dizzy; two quick hits while it has its footing make it WARP to the far
## side, inside its arena, on the plane; and when the big one dies, nymphs
## drop in at the gate. Wasp: a dive that lands in syrup STICKS even when it
## also hit him - standing in the honey is expensive now, not a dead end.
##
## Run with:
##   godot --headless --path . --script tests/mantis_kit_test.gd

var _phase := 0
var _t := 0.0
var _step := 0.0
var _level: Node
var _player: Node
var _mantis: Node
var _hp_before_blade := 0.0
var _pre_warp_side := 0.0
var _pre_warp_mx := 0.0
var _hit_px := 0.0
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = "user://test_mantis_kit.cfg"
	SaveGame.clear()
	_level = (load("res://world/levels/street_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")
	_mantis = _level.get_node("Mantis")
	print("-- the mantis has a kit now")


func _park(x: float) -> void:
	_player.health = _player.max_health
	_player.global_position = Vector3(x, 1.0, 0.0)
	_player.velocity = Vector3.ZERO


func _process(delta: float) -> bool:
	_t += delta
	_step += delta
	if _t > 90.0:
		print("MANTIS KIT TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			# Stand him in the charge lane and let the mantis ENGAGE naturally
			# first - forcing an attack pre-engagement left `_engaged` false,
			# and the first later hit then restarted the whole roar intro.
			_park(46.0)
			_player._invincibility_timer = 0.0
			if _mantis.state != MantisBoss3D.State.TRACKING and _step < 8.0:
				return false
			_hp_before_blade = _player.health
			_mantis._attack_index = -1
			_mantis._begin_attack()
			_phase = 1
			_step = 0.0
		1:
			if _mantis.state != MantisBoss3D.State.BLADE and _step < 6.0:
				_player.global_position.z = 0.0
				return false
			_check(_mantis.state == MantisBoss3D.State.BLADE,
				"the fourth attack is the BLADE CHARGE")
			var frontal: bool = _mantis._absorbs(1,
				(_mantis as Node3D).global_position + Vector3(_mantis.facing * 2.0, 0.5, 0))
			_check(not frontal, "and the guard is DOWN while it spins")
			_phase = 2
			_step = 0.0
		2:
			# Let it saw through the parked player and hit the far wall.
			if _mantis.state == MantisBoss3D.State.BLADE and _step < 8.0:
				return false
			_check(_player.health < _hp_before_blade,
				"the saw hurts what it passes through (%d -> %d)"
					% [_hp_before_blade, _player.health])
			_check(_mantis.state == MantisBoss3D.State.RECOVER,
				"and the spin-out leaves it DIZZY")
			_phase = 3
			_step = 0.0
		3:
			# Wait out the dizzy, then two quick hits from behind: it must warp
			# to the player's far side, in-arena, on the plane. The player is
			# invincible from here on so knockback drift cannot muddy the
			# before/after geometry.
			_player._invincibility_timer = 9999.0
			if _mantis.state != MantisBoss3D.State.TRACKING and _step < 8.0:
				return false
			_park(_mantis.global_position.x - _mantis.facing * 2.0)
			_pre_warp_mx = _mantis.global_position.x
			_hit_px = _player.global_position.x
			_pre_warp_side = signf(_pre_warp_mx - _hit_px)
			var behind: Vector3 = (_mantis as Node3D).global_position \
				+ Vector3(-_mantis.facing * 1.0, 0.5, 0)
			_mantis.take_damage(1, behind)
			_mantis.take_damage(1, behind)
			_phase = 4
			_step = 0.0
		4:
			if _mantis.state == MantisBoss3D.State.WARP or _step < 1.5:
				if _step > 8.0:
					_check(false, "it never warped")
					_phase = 5
				return false
			# Judged against where things stood AT THE HIT, not where later
			# drift put anyone.
			var side := signf(_mantis.global_position.x - _hit_px)
			var bounds: Vector2 = _mantis.arena_bounds()
			_check(absf(_mantis.global_position.x - _pre_warp_mx) > 3.0
				and side != 0.0 and side != _pre_warp_side,
				"two quick hits WARP it to the far side (%.1f -> %.1f over him at %.1f)"
					% [_pre_warp_mx, _mantis.global_position.x, _hit_px])
			_check(_mantis.global_position.x > bounds.x
				and _mantis.global_position.x < bounds.y,
				"the warp stays inside its arena")
			_check(absf(_mantis.global_position.z) < 0.05,
				"and ON the play plane (z %.2f)" % _mantis.global_position.z)
			_check(_mantis._warp_cooldown_left > 0.0,
				"and cannot chain-warp (cooldown armed)")
			_phase = 5
			_step = 0.0
		5:
			# Kill it (from behind, past the guard) and the brood guards the gate.
			_player._invincibility_timer = 9999.0
			var before := _nymph_count()
			for i in 12:
				_mantis.take_damage(1, (_mantis as Node3D).global_position
					+ Vector3(-_mantis.facing * 1.0, 0.5, 0))
			_phase = 6
			_step = 0.0
		6:
			if _step < 2.0:
				return false
			var zone: Node3D = _level.get_node("ExitZone")
			var guards := 0
			for nymph in _nymphs():
				if absf(nymph.global_position.x - zone.global_position.x) < 6.0:
					guards += 1
			_check(_mantis.is_defeated, "the big one goes down")
			_check(guards >= 2,
				"and %d nymphs drop in to guard the gate" % guards)
			_level.queue_free()
			_phase = 7
			_step = 0.0
		7:
			if _step < 0.5:
				return false
			print("-- the wasp's syrup outranks the hit")
			_level = (load("res://world/levels/counter_level.tscn") as PackedScene).instantiate()
			root.add_child(_level)
			_player = _level.get_node("Player")
			_phase = 8
			_step = 0.0
		8:
			if _step < 1.5:
				return false
			var wasp: Node = _level.get_node("Wasp")
			# Park him IN the syrup, aim the dive at his feet, and let it land:
			# the old order bounced off him and the fight never opened.
			var pool: Vector3 = wasp._syrup[wasp._syrup.size() / 2]
			_player.health = _player.max_health
			_player.global_position = pool + Vector3(0, 0.6, 0)
			_player.velocity = Vector3.ZERO
			var hp_before: float = _player.health
			wasp._aim = pool
			wasp.state = WaspBoss3D.State.DIVE
			wasp.global_position = pool + Vector3(0, 0.3, 0)
			wasp._impact()
			_check(not wasp.immune_to_damage
				and wasp.state == WaspBoss3D.State.STUCK,
				"a dive that hits him in the syrup still STICKS")
			_check(_player.health < hp_before,
				"and the hit still costs him (%d -> %d)" % [hp_before, _player.health])
			_phase = 9
		9:
			if _failures.is_empty():
				print("MANTIS KIT TEST PASS")
			else:
				print("MANTIS KIT TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
			return true
	return false


func _nymphs() -> Array[Node]:
	var out: Array[Node] = []
	for child in _level.get_children():
		if child is MantisBoss3D and child != _mantis:
			out.append(child)
	return out


func _nymph_count() -> int:
	return _nymphs().size()
