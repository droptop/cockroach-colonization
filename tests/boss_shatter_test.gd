extends SceneTree

## Bosses pay out in SHAPES now (BACKLOG item 22's last half, on the user's
## call): every creature boss shatters into its own meshes on defeat and the
## death burst resolves into treats and coins where the pieces fall. The
## household's mammals are exempt by design — Granny storms off and the cat
## slinks away; the game does not blow up people or pets.
##
## Run with:
##   godot --headless --path . --script tests/boss_shatter_test.gd

## level -> [boss node name, shatters?]
const CASES := [
	["kitchen_level", "RatBoss", true],
	["drain_level", "SpiderQueen", true],
	["street_level", "Mantis", true],
	["counter_level", "Wasp", true],
	["pantry_level", "Toad", true],
	["roof_level", "Magpie", true],
	["roof_garden_level", "Snail", true],
	["granny_kitchen_level", "Granny", false],
	["tabletop_level", "Cat", false],
]

var _index := 0
var _t := 0.0
var _level: Node
var _boss: Node
var _pickups_before := 0
var _boss_was_there := false
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = "user://test_boss_shatter.cfg"
	SaveGame.clear()
	print("-- creature bosses shatter into treats; people and pets walk away")


func _count_pickups() -> int:
	var n := 0
	for child in _level.get_children():
		if child is Area3D and (child as Area3D).collision_layer & 16 != 0:
			n += 1
	return n


func _process(delta: float) -> bool:
	if _index >= CASES.size():
		if _failures.is_empty():
			print("BOSS SHATTER TEST PASS")
		else:
			print("BOSS SHATTER TEST FAIL (%d): %s"
				% [_failures.size(), ", ".join(_failures)])
		quit(0 if _failures.is_empty() else 1)
		return true

	if _level == null:
		_level = (load("res://world/levels/%s.tscn" % CASES[_index][0])
			as PackedScene).instantiate()
		root.add_child(_level)
		_boss = _level.get_node_or_null(CASES[_index][1])
		_boss_was_there = _boss != null
		_t = 0.0
		return false

	_t += delta
	if _t < 1.0:
		return false
	if _t < 1.1 and _boss != null and not _boss.is_defeated:
		_pickups_before = _count_pickups()
		_boss.lose_health(99)
		return false
	if _t < 2.4:
		return false

	var name: String = "%s/%s" % [CASES[_index][0], CASES[_index][1]]
	var shatters: bool = CASES[_index][2]
	if _boss == null and not _boss_was_there:
		_check(false, "%s: boss missing" % name)
	elif _boss == null:
		# It shattered and then freed itself entirely (the rat's cleanup):
		# maximally gone. The treats still have to be there.
		_check(shatters, "%s shatters into pieces (and frees itself)" % name)
		_check(_count_pickups() > _pickups_before,
			"%s and the pieces resolve into treats and coins (%d -> %d)"
				% [name, _pickups_before, _count_pickups()])
	else:
		var visual: Node3D = _boss.get("_visual")
		var gone: bool = visual == null or not is_instance_valid(visual) \
			or not visual.visible
		if shatters:
			_check(_boss.is_defeated and gone,
				"%s shatters into pieces" % name)
			_check(_count_pickups() > _pickups_before,
				"%s and the pieces resolve into treats and coins (%d -> %d)"
					% [name, _pickups_before, _count_pickups()])
		else:
			_check(_boss.is_defeated and not gone,
				"%s keeps its body and walks away" % name)
	_level.queue_free()
	_level = null
	_boss = null
	_index += 1
	return false
