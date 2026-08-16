extends SceneTree

## The rusty nail: equipped the instant it's grabbed, briefly deadlier for
## having just been grabbed, gone from the world until its cooldown elapses,
## and never duplicated when it comes back.
##
## Run with:
##   godot --headless --path . --script tests/rusty_nail_test.gd

var _phase := 0
var _frames := 0
var _elapsed := 0.0
var _level: Node
var _player: Node
var _hud: Node
var _pickup: Area3D
var _target: Node
var _hp_before := 0
var _ready_hit := 0
var _normal_hit := 0
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	print("-- the nail replaced the pin rather than joining it")
	_check(Player3D.WEAPON_STATS.has("rusty_nail"), "rusty_nail is a weapon")
	_check(not Player3D.WEAPON_STATS.has("pin"), "pin is gone — reskinned, not duplicated")
	# Asserting an exact count was the wrong shape — it fired when the rubber
	# band arrived, which is a new KIND of weapon rather than a duplicate niche.
	# What matters is that no two entries occupy the same one.
	var niches := {}
	for id in Player3D.WEAPON_STATS:
		var stat: Dictionary = Player3D.WEAPON_STATS[id]
		var verb := "melee"
		for trait_name in ["throws", "charge", "reflects"]:
			if stat.get(trait_name, false):
				verb = trait_name
		if stat.get("launch", 0.0) > 0.0:
			verb = "launch"
		niches["%s %d/%.2f" % [verb, stat.damage, stat.cooldown]] = true
	_check(niches.size() == Player3D.WEAPON_STATS.size(),
		"every weapon occupies its own damage/speed niche (%d weapons, %d niches)"
			% [Player3D.WEAPON_STATS.size(), niches.size()])
	var nail: Dictionary = Player3D.WEAPON_STATS["rusty_nail"]
	_check(nail.get("swing", "") == "stab", "it stabs rather than swinging in an arc")
	_check(nail.get("ready_time", 0.0) > 0.0, "it has a readiness window")
	_check(nail.get("ready_bonus", 0) > 0, "which is worth something")

	_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")
	_hud = _level.get_node("HUD")
	_pickup = _level.get_node_or_null("RustyNail1")
	_target = _level.get_node("Spider")


## Stand Harry on the target. Every wait here is in REAL SECONDS, never frames:
## headless idle frames run far faster than the 60 Hz physics tick, so a wait of
## "8 frames" can contain no physics frame at all — and then the press and the
## release both land before _handle_attack ever runs, and the swing silently
## does nothing. Both earlier versions of this test failed exactly that way.
func _line_up() -> void:
	# To the LEFT of the target and facing right. The BiteArea hangs off the
	# Visual, which flips with facing, so standing on the target's right while
	# facing right puts the hit area behind him and every swing whiffs.
	_player.global_position = _target.global_position - Vector3(0.3, 0, 0)
	_player.facing = 1
	_player._visual.rotation.y = 0.0
	_player._bite_cooldown_timer = 0.0


## Driven through Input, the way the game does it: the damage bonus is computed
## inside _handle_attack, so reaching past it would test a different code path
## than the one that ships.
func _swing() -> void:
	_hp_before = _target.health
	Input.action_press("attack")


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	if _frames > 200000:
		print("RUSTY NAIL TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _frames < 12:
				return false
			print("-- pickup")
			_check(_pickup != null, "the drain has a rusty nail lying in it")
			_check(_pickup.weapon_id == "rusty_nail", "and it is the nail")
			_check(_hud._weapon_label.text.begins_with("X - BITE"),
				"unarmed, the prompt reads X - BITE (%s)" % _hud._weapon_label.text)
			_pickup.respawn_seconds = 1.0 # 14 s is a long time to sit in a test
			_target.health = 40 # so repeated swings never kill it mid-measurement
			_target.set_physics_process(false) # hold still and stop biting back

			_pickup._on_body_entered(_player)
			# Same frame: the world copy vanishing must not delay the weapon
			# reaching his hand.
			_check(_player.active_weapon == "rusty_nail",
				"it is equipped on the very frame it is collected")
			_check(_hud._weapon_label.text.begins_with("X - HIT"),
				"armed, the prompt reads X - HIT (%s)" % _hud._weapon_label.text)
			_check(_hud._weapon_label.text.contains("RUSTY NAIL"), "and names it")
			_check(_hud._weapon_label.text.contains("READY"),
				"and shows the readiness window is open")
			_line_up()
			_elapsed = 0.0
			_phase = 1
		1:
			if _elapsed < 0.15: # let the overlap register on a physics frame
				return false
			_swing()
			_elapsed = 0.0
			_phase = 2
		2:
			if _elapsed < 0.2: # long enough to guarantee physics ticks
				return false
			Input.action_release("attack")
			_ready_hit = _hp_before - _target.health
			_check(_ready_hit > 0, "the nail connects during the readiness window")
			_elapsed = 0.0
			_phase = 3
		3:
			if _elapsed < 0.9: # outlast the 0.5 s window
				return false
			_check(_player._weapon_ready_timer <= 0.0, "the readiness window closes")
			_check(not _hud._weapon_label.text.contains("READY"),
				"and the prompt stops claiming it (%s)" % _hud._weapon_label.text)
			_check(_player.active_weapon == "rusty_nail",
				"but the nail stays equipped afterwards")
			_line_up()
			_elapsed = 0.0
			_phase = 31
		31:
			if _elapsed < 0.15:
				return false
			_swing()
			_elapsed = 0.0
			_phase = 32
		32:
			if _elapsed < 0.2:
				return false
			Input.action_release("attack")
			_normal_hit = _hp_before - _target.health
			_check(_normal_hit > 0, "and still connects afterwards")
			_check(_ready_hit > _normal_hit,
				"a fresh nail hits harder (%d vs %d)" % [_ready_hit, _normal_hit])
			_elapsed = 0.0
			_phase = 4
		4:
			if _elapsed < 2.0: # respawn_seconds was set to 1.0
				return false
			print("-- respawn")
			var nails := 0
			for child in _level.get_children():
				if child is Area3D and child.get("weapon_id") == "rusty_nail":
					nails += 1
			_check(nails == 1, "exactly one nail exists after respawning (%d)" % nails)
			_check(is_instance_valid(_pickup) and _pickup.visible,
				"and it is the same node, visible again")
			_check(_pickup.monitoring, "and it can be picked up again")
			_phase = 5
		5:
			if _failures.is_empty():
				print("RUSTY NAIL TEST PASS")
			else:
				print("RUSTY NAIL TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
	return false
