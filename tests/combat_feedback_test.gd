extends SceneTree

## Combat readability. The player has to be able to tell a hit landed, how hard,
## and whether a shield ate it — without reading the health bar.
##
## Run with:
##   godot --headless --path . --script tests/combat_feedback_test.gd

var _phase := 0
var _frames := 0
var _elapsed := 0.0
var _level: Node
var _player: Node
var _flashed: Array[MeshInstance3D] = []
var _damage_events: Array = []
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	# HERMETIC: the player reads bought upgrades off the save on spawn now,
	# so a test without a scratch save measures whatever was last played.
	SaveGame.save_path = "user://test_combat_feedback_scratch.cfg"
	SaveGame.clear()
	print("-- damage tiers")
	_check(Fx.tier_for(1) == Fx.Tier.WEAK, "1 damage reads WEAK")
	_check(Fx.tier_for(2) == Fx.Tier.NORMAL, "2 damage reads NORMAL")
	_check(Fx.tier_for(3) == Fx.Tier.HEAVY, "3 damage reads HEAVY")
	_check(Fx.tier_for(9) == Fx.Tier.HEAVY, "big damage stays HEAVY")
	_check(Fx.tier_for(3, true) == Fx.Tier.BLOCKED,
		"blocked beats the damage number — the shield is the headline")
	var tiers := {}
	for t in [Fx.Tier.BLOCKED, Fx.Tier.WEAK, Fx.Tier.NORMAL, Fx.Tier.HEAVY]:
		var style: Dictionary = Fx.TIER_STYLE[t]
		tiers[style.color] = true
		_check(not (style.words as Array).is_empty(), "tier %d has its own words" % t)
	_check(tiers.size() == 4, "every tier has a distinct colour")

	_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	if _frames > 100000:
		print("COMBAT FEEDBACK TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 12:
				return false
			print("-- every enemy reacts when hurt")
			for name in ["Spider", "Ant1"]:
				var enemy: Node3D = _level.get_node_or_null(name)
				if enemy == null:
					_check(false, "%s present in the drain" % name)
					continue
				var visual: Node3D = enemy.get_node("Visual")
				enemy.take_damage(1, enemy.global_position + Vector3(2, 0, 0))
				var overlaid := _count_overlaid(visual)
				_check(overlaid > 0, "%s flashes on hit (%d meshes overlaid)" % [name, overlaid])
				_collect(visual)
			_elapsed = 0.0
			_phase = 1
		1:
			if _elapsed < 0.6:
				return false
			var still := 0
			for m in _flashed:
				if is_instance_valid(m) and m.material_overlay != null:
					still += 1
			_check(still == 0, "the flash clears itself (%d still overlaid)" % still)

			print("-- player damage feedback")
			_player.damaged.connect(func(a: int, b: bool) -> void:
				_damage_events.append({"amount": a, "blocked": b}))

			_player.has_shield = false
			_player._invincibility_timer = 0.0
			var before: float = _player.health
			_player.take_damage(2, _player.global_position + Vector3(1, 0, 0))
			_check(_damage_events.size() == 1, "an unblocked hit reports once")
			_check(not _damage_events[-1].blocked, "and reports itself as unblocked")
			_check(is_equal_approx(before - _player.health, 2.0), "unblocked costs full health")

			_player.collect_shield("cap")
			_player._invincibility_timer = 0.0
			before = _player.health
			_player.take_damage(2, _player.global_position + Vector3(1, 0, 0))
			_check(_damage_events.size() == 2, "a blocked hit still reports")
			_check(_damage_events[-1].blocked, "and flags itself as blocked")
			_check(is_equal_approx(before - _player.health, 1.0), "blocked costs half")

			# Invulnerability must still swallow follow-up hits.
			var events_before := _damage_events.size()
			_player.take_damage(2, _player.global_position + Vector3(1, 0, 0))
			_check(_damage_events.size() == events_before,
				"a hit during invulnerability reports nothing")
			_phase = 2
		2:
			if _failures.is_empty():
				print("COMBAT FEEDBACK TEST PASS")
			else:
				print("COMBAT FEEDBACK TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
	return false


func _count_overlaid(node: Node) -> int:
	var n := 0
	if node is MeshInstance3D and (node as MeshInstance3D).material_overlay != null:
		n += 1
	for child in node.get_children():
		n += _count_overlaid(child)
	return n


func _collect(node: Node) -> void:
	if node is MeshInstance3D:
		_flashed.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect(child)
