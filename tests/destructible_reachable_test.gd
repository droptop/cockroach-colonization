extends SceneTree

## Can Harry's actual attack hit the things that are supposed to be hittable?
##
## This exists because the answer was NO, for three of them, in the shipped
## build — and every other test passed the whole time. The Spider Queen's webs,
## the cat's paw and both breakable walls were StaticBody3D, and an Area3D does
## not report a StaticBody3D in get_overlapping_bodies(). The attack volumes are
## Areas. So those three were invisible to every attack in the game.
##
## Nothing caught it because every test drove damage the same convenient way:
##   anchor.take_damage(2, pos)     <- bypasses the attack volume entirely
## which proves the object dies when damaged, and says nothing at all about
## whether a player can ever damage it. This test only presses buttons.
##
## Run with:
##   godot --headless --path . --script tests/destructible_reachable_test.gd

var _phase := 0
var _t := 0.0
var _step_t := 0.0
var _level: Node
var _player: Node
var _kinds: Array[String] = []
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


## A body an Area3D can actually see. StaticBody3D is not one of them, which is
## the entire bug: it collides fine, it just cannot be detected.
func _area_visible(node: Node) -> bool:
	return node is AnimatableBody3D or node is CharacterBody3D


func _initialize() -> void:
	print("-- every damageable must be a body the attack volumes can see")
	# Generic: walks the scripts rather than naming the three known offenders,
	# so a destructible added next month is covered without anyone remembering.
	var offenders: Array[String] = []
	var checked := 0
	for path in ["res://enemies/spider_queen/web_anchor_3d.gd",
			"res://world/props3d/breakable_block3d.gd",
			"res://enemies/cat/cat_paw_3d.gd",
			"res://enemies/spider/spider_3d.gd",
			"res://enemies/ant/ant_3d.gd",
			"res://enemies/fly/fly_3d.gd"]:
		var script := load(path) as GDScript
		if script == null:
			continue
		var made = script.new()
		if not made.has_method("take_damage"):
			made.free()
			continue
		checked += 1
		if not _area_visible(made):
			offenders.append("%s is %s" % [path.get_file(), made.get_class()])
		made.free()
	_check(checked >= 5, "checked %d damageable types" % checked)
	_check(offenders.is_empty(),
		"all of them are area-visible%s" % ("" if offenders.is_empty()
			else " — INVISIBLE: " + ", ".join(offenders)))

	# Area-visible is only half of it. An Area3D reports a body only if the
	# body sits on a layer the area MASKS, so collision_layer 0 is just as
	# unhittable as the wrong node type. The Spider Queen shipped that way:
	# once her webs were cut she could not be interacted with by any means,
	# and the boss test passed throughout because it called take_damage()
	# directly. This walks the placed bosses in the real scenes.
	print("-- every boss is on a layer an attack area can see")
	var layerless: Array[String] = []
	var bosses := 0
	for level_path in ["res://world/levels/drain_level.tscn"]:
		var scene := (load(level_path) as PackedScene).instantiate()
		for child in scene.get_children():
			if child is BaseBoss3D:
				bosses += 1
				if (child as BaseBoss3D).collision_layer == 0:
					layerless.append("%s in %s" % [child.name, level_path.get_file()])
		scene.free()
	_check(bosses > 0, "found %d placed bosses" % bosses)
	_check(layerless.is_empty(), "all of them are on a layer%s"
		% ("" if layerless.is_empty() else " — UNHITTABLE: " + ", ".join(layerless)))

	_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")


func _process(delta: float) -> bool:
	_t += delta
	_step_t += delta
	if _t > 90.0:
		print("REACHABLE TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true
	match _phase:
		0:
			if _step_t < 1.0:
				return false
			print("-- a real swing at a web anchor")
			for child in _level.get_children():
				if child is WebAnchor3D:
					_anchor = child
					break
			_check(_anchor != null, "the drain's queen spins webs")
			if _anchor == null:
				_phase = 8
				return false
			_hp = _anchor.health
			_next(1)
		1:
			# Park him with the knot squarely inside the up-attack volume.
			_player.global_position = _anchor.global_position + Vector3(0, -0.9, 0)
			_player.velocity = Vector3.ZERO
			_player._invincibility_timer = 99.0
			if _step_t < 1.0:
				return false
			_player._bite_cooldown_timer = 0.0
			Input.action_press("move_up")
			Input.action_press("attack")
			_next(2)
		2:
			_player.global_position = _anchor.global_position + Vector3(0, -0.9, 0)
			_player.velocity = Vector3.ZERO
			# Wait for the HIT rather than a fixed interval — the strike needs a
			# physics step, and headless idle frames are not locked to those.
			if _anchor.health >= _hp and _step_t < 2.0:
				return false
			Input.action_release("attack")
			Input.action_release("move_up")
			_check(_anchor.health < _hp,
				"an up-attack cuts a web (%d -> %d)" % [_hp, _anchor.health])
			# And it must not throw him off the thing he is cutting. The Queen
			# hangs among her own webs and is on the enemy layer so she can be
			# hit at all, so the bite area finds HER on every swing at an
			# anchor. Recoiling off her made the fight's one required action
			# impossible while looking like bad flying.
			_check(absf(_player.velocity.x) < 3.0,
				"and does not bounce him off the immune Queen beside it (%.1f)"
					% absf(_player.velocity.x))
			_next(3)
		3:
			print("-- a real swing at a breakable wall")
			for child in _level.get_children():
				if child is BreakableBlock3D:
					_block = child
					break
			_check(_block != null, "the drain has a breakable")
			if _block == null:
				_phase = 6
				return false
			_hp = _block.health
			_next(4)
		4:
			# Heavy, so his bite qualifies against required_damage.
			_player.global_position = _block.global_position + Vector3(-1.0, 0.0, 0)
			_player.velocity = Vector3.ZERO
			_player.fullness = 1.0
			_player.facing = 1
			if _step_t < 1.0:
				return false
			_player._bite_cooldown_timer = 0.0
			Input.action_press("attack")
			_next(5)
		5:
			_player.global_position = _block.global_position + Vector3(-1.0, 0.0, 0)
			_player.velocity = Vector3.ZERO
			if _block.health >= _hp and _step_t < 2.0:
				return false
			Input.action_release("attack")
			_check(_block.health < _hp,
				"a heavy bite cracks a breakable wall (%d -> %d)" % [_hp, _block.health])
			_next(6)
		6:
			print("-- and the cat's paw, which is the whole cat fight")
			var scene := load("res://world/levels/tabletop_level.tscn") as PackedScene
			_level.queue_free()
			_level = scene.instantiate()
			root.add_child(_level)
			_player = _level.get_node("Player")
			_next(7)
		7:
			if _step_t < 1.0:
				return false
			var paw: Node = null
			for child in _level.get_children():
				if child.get_script() != null \
						and child.get_script().resource_path.ends_with("cat_paw_3d.gd"):
					paw = child
			if paw == null:
				# The paw is spawned by the fight, not placed in the scene.
				# The class-level check in _initialize already covers it.
				_check(true, "paw is spawned during the fight; base class checked above")
			else:
				_check(_area_visible(paw), "the paw is a body an attack can see")
			_phase = 8
		8:
			if _failures.is_empty():
				print("DESTRUCTIBLE REACHABLE TEST PASS")
			else:
				print("DESTRUCTIBLE REACHABLE TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
	return false


func _next(phase: int) -> void:
	_phase = phase
	_step_t = 0.0


var _anchor: WebAnchor3D
var _block: BreakableBlock3D
var _hp := 0
