extends SceneTree

## Baby provenance (BACKLOG item 23): every banked baby remembers which
## level's door banked it, the ledger survives the count going DOWN (babies
## die with him and come back as ghosts), and a real level credits itself.
##
## Run with:
##   godot --headless --path . --script tests/baby_matrix_test.gd

var _phase := 0
var _t := 0.0
var _step := 0.0
var _level: Node
var _player: Node
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = "user://test_baby_matrix.cfg"
	SaveGame.clear()
	print("-- the ledger credits, drains newest-first, and matches the total")
	SaveGame.set_provenance_hint("drain_level")
	SaveGame.set_babies_banked(2)
	SaveGame.set_provenance_hint("street_level")
	SaveGame.set_babies_banked(5)
	var ledger := SaveGame.babies_by_level()
	_check(int(ledger.get("drain_level", 0)) == 2
		and int(ledger.get("street_level", 0)) == 3,
		"gains credit the level in play (%s)" % str(ledger))

	# He dies with four of them: the newest rescues are the ones lost.
	SaveGame.set_babies_banked(1)
	ledger = SaveGame.babies_by_level()
	_check(int(ledger.get("street_level", 0)) == 0
		and int(ledger.get("drain_level", 0)) == 1,
		"losses drain the newest level first (%s)" % str(ledger))
	var total := 0
	for level_id in ledger:
		total += int(ledger[level_id])
	_check(total == SaveGame.babies_banked(),
		"the ledger always sums to the total (%d)" % total)

	# No hint set: writers with no context credit "unknown", never crash.
	SaveGame.set_provenance_hint("")
	SaveGame.set_babies_banked(3)
	_check(int(SaveGame.babies_by_level().get("unknown", 0)) == 2,
		"contextless writes land in the unknown row")

	print("-- a real level credits its own door")
	SaveGame.clear()
	_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")


func _process(delta: float) -> bool:
	_t += delta
	_step += delta
	if _t > 40.0:
		print("BABY MATRIX TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _step < 1.0:
				return false
			# One rescue in his train, the Queen out of the way, and out the door.
			var baby := BabyFollower3D.new()
			_level.add_child(baby)
			baby.global_position = _player.global_position
			_player.adopt_baby(baby)
			_level.get_node("SpiderQueen").lose_health(99)
			_phase = 1
			_step = 0.0
		1:
			_player.health = _player.max_health
			_player._invincibility_timer = 9999.0
			var arrived := false
			for child in root.get_children():
				if child.has_method("continue_to_next"):
					arrived = true
			if not arrived:
				if _step > 3.0:
					_player.global_position = Vector3(46, 8.3, 0)
					_player.velocity = Vector3.ZERO
				return false
			var ledger := SaveGame.babies_by_level()
			_check(int(ledger.get("drain_level", 0)) == 1,
				"the drain's door banks a DRAIN baby (%s)" % str(ledger))
			_check(ShopScreen.banked_level == "drain_level",
				"and the shop is told whose row to light (%s)" % ShopScreen.banked_level)
			_phase = 2
		2:
			if _failures.is_empty():
				print("BABY MATRIX TEST PASS")
			else:
				print("BABY MATRIX TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
			return true
	return false
