extends SceneTree

## Rewards must never be granted silently, and must never be swallowed by a
## bar that is already full.
##
## Run with:
##   godot --headless --path . --script tests/rewards_test.gd

var _phase := 0
var _frames := 0
var _elapsed := 0.0
var _level: Node
var _player: Node
var _fly: Node
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	# HERMETIC: the player reads bought upgrades off the save on spawn now,
	# so a test without a scratch save measures whatever was last played.
	SaveGame.save_path = "user://test_rewards_scratch.cfg"
	SaveGame.clear()
	_level = (load("res://world/levels/street_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")
	_fly = _level.get_node("Fly1")


## Coins are RewardPickup3D too now, and levels PLACE some — so the heart and
## energy assertions filter by kind rather than assuming every reward in the
## level is the one the fly just dropped.
func _rewards(kind := "") -> Array[RewardPickup3D]:
	var found: Array[RewardPickup3D] = []
	for child in _level.get_children():
		if child is RewardPickup3D and (kind == "" or child.kind == kind):
			found.append(child)
	return found


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	if _frames > 20000:
		print("REWARDS TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 12:
				return false
			print("-- the restore calls report what they did")
			_player.health = float(_player.max_health)
			_check(not _player.restore_health(1.0), "healing at full reports that it did nothing")
			_player.health = 2.0
			_check(_player.restore_health(1.0), "healing below full reports success")
			_check(is_equal_approx(_player.health, 3.0), "and actually heals")
			_player.health = 4.5
			_player.restore_health(5.0)
			_check(is_equal_approx(_player.health, float(_player.max_health)),
				"healing never exceeds the maximum (%.1f)" % _player.health)
			_player.wing_energy = _player.max_wing_energy
			_check(not _player.add_wing_energy(10.0), "full wings report nothing done")
			_player.wing_energy = 10.0
			_check(_player.add_wing_energy(10.0), "wings below full report success")

			print("-- a beaten fly pays out")
			_check(_rewards("heart").is_empty() and _rewards("energy").is_empty(),
				"no hearts or shards are lying about beforehand")
			var coins_before := _rewards("coin").size()
			_fly.take_damage(99, _fly.global_position + Vector3(1, 0, 0))
			var dropped := _rewards("heart") + _rewards("energy")
			_check(dropped.size() == 1, "the fly leaves exactly one heart-or-shard")
			if dropped.is_empty():
				_phase = 8
				return false
			_check(dropped[0].kind == "heart", "and it is a heart")
			_check(_rewards("coin").size() == coins_before + 1,
				"and its death burst carries a coin (%d -> %d)"
					% [coins_before, _rewards("coin").size()])
			_phase = 1
		1:
			print("-- taking it says so")
			var reward := _rewards("heart")[0]
			_player.health = 2.0
			var before: float = _player.health
			reward._on_body_entered(_player)
			_check(_player.health > before, "walking into it heals him")
			_check(reward.is_queued_for_deletion(), "and consumes it")

			print("-- but a full bar does not swallow it")
			var spare := RewardPickup3D.new()
			spare.kind = "heart"
			_level.add_child(spare)
			spare.global_position = _player.global_position
			_player.health = float(_player.max_health)
			spare._on_body_entered(_player)
			_check(not spare.is_queued_for_deletion(),
				"a reward taken at full health is LEFT for later, not eaten")
			_check(is_equal_approx(_player.health, float(_player.max_health)),
				"and health is unchanged")
			# ...and once there is room, the same one works.
			_player.health = 2.0
			spare._full_cooldown = 0.0
			var room_before: float = _player.health
			spare._on_body_entered(_player)
			_check(_player.health > room_before, "and it still works once there is room")
			_check(spare.is_queued_for_deletion(), "and is consumed then")
			_phase = 2
		2:
			print("-- rewards drift toward him")
			var drifter := RewardPickup3D.new()
			drifter.kind = "energy"
			_level.add_child(drifter)
			drifter.global_position = _player.global_position + Vector3(2.0, 0, 0)
			var start := drifter.global_position.distance_to(_player.global_position)
			drifter._process(0.2)
			var after := drifter.global_position.distance_to(_player.global_position)
			_check(after < start, "one within range closes the gap (%.2f -> %.2f)" % [start, after])
			var far := RewardPickup3D.new()
			far.kind = "heart"
			_level.add_child(far)
			far.global_position = _player.global_position + Vector3(20.0, 0, 0)
			var far_start := far.global_position.distance_to(_player.global_position)
			far._process(0.2)
			_check(is_equal_approx(far.global_position.distance_to(_player.global_position), far_start),
				"one out of range stays put, so it can be collected manually")
			_phase = 3
		3:
			if _failures.is_empty():
				print("REWARDS TEST PASS")
			else:
				print("REWARDS TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
		8:
			print("REWARDS TEST FAIL: the fly dropped nothing")
			quit(1)
	return false
