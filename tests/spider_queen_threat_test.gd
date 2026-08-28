extends SceneTree

## The Spider Queen actually THREATENS him now (BACKLOG item 18, by request):
##   - she shoots a web glob that WRAPS him where he stands
##   - wiggling (alternating left/right presses) breaks him out faster than
##     waiting does — the grab is fought, not sat through
##   - her summons are her own brood: small spiders, on the play plane
##   - and a swing that whiffs near an active boss re-shows the rule, because
##     silence at an untouchable boss reads as a broken game (the live
##     "z-index" report)
##
## Driven by parking him in her arena and letting her fight; nothing here
## calls her attacks directly.
##
## Run with:
##   godot --headless --path . --script tests/spider_queen_threat_test.gd

var _phase := 0
var _t := 0.0
var _step := 0.0
var _level: Node
var _player: Node
var _boss: Node
var _passive_time := 0.0
var _wiggle_time := 0.0
var _wiggle_side := false
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = "user://test_queen_threat.cfg"
	SaveGame.clear()
	_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")
	_boss = _level.get_node("SpiderQueen")
	print("-- the Queen grabs, the grab is fought, the brood is hers")


func _park() -> void:
	_player.health = _player.max_health
	_player._invincibility_timer = 9999.0
	if not _player.is_wrapped() and _player.global_position.distance_to(
			Vector3(40.0, 8.0, 0.0)) > 3.0:
		_player.global_position = Vector3(40.0, 8.2, 0.0)
		_player.velocity = Vector3.ZERO


func _process(delta: float) -> bool:
	_t += delta
	_step += delta
	if _t > 120.0:
		print("QUEEN THREAT TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	_park()

	match _phase:
		0:
			# She notices him and, within her shot interval, tangles him.
			if not _player.is_wrapped() and _step < 15.0:
				return false
			_check(_player.is_wrapped(), "her web glob WRAPS him (%.1fs in)" % _step)
			if not _player.is_wrapped():
				_phase = 9
				return false
			_phase = 1
			_step = 0.0
		1:
			# Sit still: how long does the wrap hold on its own?
			if _player.is_wrapped() and _step < 6.0:
				return false
			_passive_time = _step
			_check(not _player.is_wrapped() and _passive_time > 0.8,
				"left alone it holds him %.1fs" % _passive_time)
			_phase = 2
			_step = 0.0
		2:
			# Wait out the grace period for the next glob.
			if not _player.is_wrapped() and _step < 20.0:
				return false
			_check(_player.is_wrapped(), "she tangles him again for the wiggle test")
			if not _player.is_wrapped():
				_phase = 9
				return false
			_phase = 3
			_step = 0.0
		3:
			# WIGGLE: alternate fresh presses at a human mashing cadence.
			# Toggling every idle frame outruns the physics tick and most
			# presses never register as just_pressed at all.
			if fmod(_step, 0.12) < delta:
				_wiggle_side = not _wiggle_side
				Input.action_release("move_left" if _wiggle_side else "move_right")
				Input.action_press("move_right" if _wiggle_side else "move_left")
			if _player.is_wrapped() and _step < 6.0:
				return false
			_wiggle_time = _step
			Input.action_release("move_left")
			Input.action_release("move_right")
			_check(not _player.is_wrapped() and _wiggle_time < _passive_time - 0.25,
				"wiggling frees him faster (%.1fs vs %.1fs)"
					% [_wiggle_time, _passive_time])
			_phase = 4
			_step = 0.0
		4:
			# Her brood: force a wave, and it must be small spiders on the
			# plane. Only the NEW arrivals count — the drain places a full-size
			# spider of its own halfway along the level.
			var before := {}
			for spider in _spiders():
				before[spider.get_instance_id()] = true
			_boss._summon_wave()
			var spawned := 0
			var on_plane := true
			var small := true
			for spider in _spiders():
				if before.has(spider.get_instance_id()):
					continue
				spawned += 1
				if absf(spider.global_position.z) > 0.05:
					on_plane = false
				# The shrink lives on the visual's PARTS (the parent's scale
				# is animation-owned), so that is where smallness is checked.
				var visual: Node3D = spider.get_node_or_null("Visual")
				if visual and visual.get_child_count() > 0:
					var part := visual.get_child(0) as Node3D
					if part and part.scale.x > 0.9:
						small = false
			_check(spawned == _boss.summon_count,
				"a wave brings %d of her own spiders (%d)" % [_boss.summon_count, spawned])
			_check(on_plane, "the brood lands ON the play plane")
			_check(small, "and they are visibly babies")
			_phase = 5
			_step = 0.0
		5:
			# Whiffing near her, mid-fight, re-shows the rule. Wait for older
			# HUD messages to clear first, then swing at nothing.
			if _step < 4.5:
				return false
			var hud := _level.get_node("HUD")
			var message: Label = hud.get_node("Message")
			message.visible = false
			_player.global_position = Vector3(40.0, 8.2, 0.0)
			_player._bite_cooldown_timer = 0.0
			Input.action_press("attack")
			_phase = 6
			_step = 0.0
		6:
			Input.action_release("attack")
			if _step < 0.6:
				return false
			var hud := _level.get_node("HUD")
			var message: Label = hud.get_node("Message")
			_check(message.visible and message.text == _boss.boss_rule,
				"a whiffed swing near her re-shows the rule ('%s')" % message.text)
			_phase = 7
		7:
			if _failures.is_empty():
				print("QUEEN THREAT TEST PASS")
			else:
				print("QUEEN THREAT TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
			return true
		9:
			print("QUEEN THREAT TEST FAIL (%d): %s"
				% [_failures.size(), ", ".join(_failures)])
			quit(1)
			return true
	return false


func _spiders() -> Array[Node]:
	var out: Array[Node] = []
	for child in _level.get_children():
		if child.get_script() != null \
				and child.get_script().resource_path.ends_with("spider_3d.gd"):
			out.append(child)
	return out
