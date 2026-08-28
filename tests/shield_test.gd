extends SceneTree

## The bottle cap as a helmet: worn ON his head, halves what gets through,
## wears out, and leaves visibly when it does.
##
## Run with:
##   godot --headless --path . --script tests/shield_test.gd

var _phase := 0
var _frames := 0
var _level: Node
var _player: Node
var _hud: Node
var _blocked_events: Array[int] = []
var _broke := 0
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _hit(amount: int) -> void:
	_player._invincibility_timer = 0.0
	_player.take_damage(amount, _player.global_position + Vector3(1, 0, 0))


func _initialize() -> void:
	# HERMETIC: the player reads bought upgrades off the save on spawn now,
	# so a test without a scratch save measures whatever was last played.
	SaveGame.save_path = "user://test_shield_scratch.cfg"
	SaveGame.clear()
	_level = (load("res://world/levels/street_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")
	_hud = _level.get_node("HUD")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 100000:
		print("SHIELD TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 12:
				return false
			_player.shield_blocked.connect(func(r: int) -> void: _blocked_events.append(r))
			_player.shield_broke.connect(func() -> void: _broke += 1)

			print("-- worn on the head, not floating over it")
			_player.collect_shield("cap")
			var cap: Node3D = _player._shield_halo
			_check(cap.visible, "the cap is worn once collected")
			# The visual's head sits at local (0.24, 0.26) with radius 0.21, so
			# its crown is y 0.47. A helmet belongs just under that, at the same x.
			_check(absf(cap.position.x - 0.24) < 0.08,
				"it sits over the head in x (%.2f vs head 0.24)" % cap.position.x)
			_check(cap.position.y > 0.3 and cap.position.y < 0.5,
				"and rests on the crown rather than hovering (%.2f)" % cap.position.y)
			_check(_player.shield_hits == _player.shield_durability,
				"it starts at full durability")

			print("-- it halves damage while it lasts")
			_player.health = 5.0
			var before: float = _player.health
			_hit(2)
			_check(is_equal_approx(before - _player.health, 1.0), "a blocked hit costs half")
			_check(_blocked_events.size() == 1, "and reports the block")
			_check(_blocked_events[-1] == _player.shield_durability - 1,
				"counting down (%d left)" % _blocked_events[-1])
			_check(_hud._shield_label.text.contains("#"),
				"the HUD shows condition, not just presence (%s)" % _hud._shield_label.text)

			print("-- it wears out")
			var guard := 0
			while _player.has_shield and guard < 20:
				_player.health = 5.0
				_hit(1)
				guard += 1
			_check(not _player.has_shield, "the cap breaks after enough hits")
			_check(_broke == 1, "and says so exactly once")
			_check(_blocked_events.size() == _player.shield_durability,
				"it absorbed exactly its durability (%d hits)" % _blocked_events.size())
			_check(not _player._shield_halo.visible, "and is no longer worn")
			_check(not _hud._shield_label.visible, "and the HUD drops it")

			print("-- and damage returns to full immediately")
			_player.health = 5.0
			var full_before: float = _player.health
			_hit(2)
			_check(is_equal_approx(full_before - _player.health, 2.0),
				"an unshielded hit costs full")

			print("-- picking one up again restores it")
			_player.collect_shield("pan")
			_check(_player.has_shield, "a fresh shield equips")
			_check(_player.shield_hits == _player.shield_durability,
				"at full durability again")
			_check(_player._shield_pan.visible and not _player._shield_halo.visible,
				"and the pan is worn instead of the cap")
			_phase = 1
		1:
			if _failures.is_empty():
				print("SHIELD TEST PASS")
			else:
				print("SHIELD TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
	return false
