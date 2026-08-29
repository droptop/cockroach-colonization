extends SceneTree

## Coins and run upgrades: the money is real, the purchases do what they say.
##
## Three separate claims, each of which could rot on its own:
##   - SaveGame's coin arithmetic holds (no free money, no negative balance)
##   - a spawned player actually WEARS its bought upgrades: more hearts, a
##     bigger wing tank, cheaper hits, harder attacks, and the hat exists
##   - a coin on the floor can be picked up by CONTACT, through the same
##     Area3D route every other pickup uses — driving SaveGame.add_coins from
##     a test would prove nothing about whether a player can ever earn one
##
## Everything tree-shaped waits for _process: _ready has not run during
## _initialize, and asserting there measured a player that had not applied
## anything yet.
##
## Run with:
##   godot --headless --path . --script tests/coins_upgrades_test.gd

var _phase := 0
var _t := 0.0
var _plain: Node
var _player: Node
var _coin: Node
var _base_meshes := 0
var _base_health := 0
var _base_wing := 0.0
var _base_hit_cost := 0.0
var _failures: Array[String] = []

const PLAYER := preload("res://player/player_3d.tscn")
const COIN := preload("res://items/rewards/coin_3d.tscn")


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _count_meshes(node: Node) -> int:
	var n := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		n += _count_meshes(child)
	return n


func _initialize() -> void:
	SaveGame.save_path = "user://test_coins_upgrades.cfg"
	SaveGame.clear()
	print("-- coin arithmetic")
	_check(SaveGame.coins() == 0, "a fresh save has no coins")
	SaveGame.add_coins(7)
	_check(SaveGame.coins() == 7, "coins add up")
	_check(SaveGame.spend_coins(5), "affordable spends succeed")
	_check(SaveGame.coins() == 2, "and are deducted")
	_check(not SaveGame.spend_coins(3), "overspending is refused")
	_check(SaveGame.coins() == 2, "and costs nothing")
	SaveGame.add_coins(-5)
	_check(SaveGame.coins() == 2, "negative grants are ignored")
	# A bare player first, with nothing bought, as the baseline.
	_plain = PLAYER.instantiate()
	root.add_child(_plain)


func _process(delta: float) -> bool:
	_t += delta
	match _phase:
		0:
			if _t < 0.3:
				return false
			_base_meshes = _count_meshes(_plain)
			_base_health = _plain.max_health
			_base_wing = _plain.max_wing_energy
			_base_hit_cost = _plain.wing_hit_cost
			_plain.free()
			# Now buy everything and spawn again.
			SaveGame.set_upgrade_level("heart", 1)
			SaveGame.set_upgrade_level("wing_tank", 1)
			SaveGame.set_upgrade_level("thick_shell", 1)
			SaveGame.set_upgrade_level("power_hits", 1)
			SaveGame.set_upgrade_level("hat", 1)
			_player = PLAYER.instantiate()
			root.add_child(_player)
			_phase = 1
			_t = 0.0
		1:
			if _t < 0.3:
				return false
			print("-- upgrades reach the spawned player")
			_check(_player.max_health == _base_health + 2,
				"EXTRA HEART: max health %d -> %d" % [_base_health, _player.max_health])
			_check(absf(_player.max_wing_energy - _base_wing * 1.2) < 0.01,
				"BIGGER WING TANK: %.0f -> %.0f" % [_base_wing, _player.max_wing_energy])
			_check(_player.wing_hit_cost < _base_hit_cost,
				"THICK SHELL: hit cost %.0f -> %.0f" % [_base_hit_cost, _player.wing_hit_cost])
			_check(_player._upgrade_damage_bonus == 1, "POWER HITS: +1 damage carried")
			var meshes := _count_meshes(_player)
			_check(meshes > _base_meshes,
				"RIDICULOUS HAT: %d meshes vs %d bare" % [meshes, _base_meshes])
			_check(_player.health == _player.max_health,
				"he spawns with the bought hearts full")

			# A floor under him and a coin ON him, for the contact pickup.
			var floor_body := StaticBody3D.new()
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(10, 1, 5)
			collision.shape = shape
			floor_body.add_child(collision)
			root.add_child(floor_body)
			floor_body.position = Vector3(0, -0.5, 0)
			_player.position = Vector3.ZERO
			_coin = COIN.instantiate()
			root.add_child(_coin)
			_coin.position = Vector3(0, 0.2, 0)
			_phase = 2
			_t = 0.0
		2:
			# Overlaps only refresh on a physics step, and pickup is contact
			# driven — wait in real seconds, for the event, not a frame count.
			if is_instance_valid(_coin) and _t < 5.0:
				return false
			print("-- a coin can be EARNED, by contact")
			_check(not is_instance_valid(_coin), "walking into a coin takes it")
			_check(SaveGame.coins() == 3,
				"and it lands in the save (%d coins)" % SaveGame.coins())

			# TWIN EGGS: the banking maths, through the same static the level
			# exit calls. Only babies rescued THIS level double.
			print("-- twin eggs double the fresh rescues")
			_check(Level3D.twin_egg_bank(5, 2) == 5,
				"unbought, 5 following bank as 5")
			SaveGame.set_upgrade_level("twin_eggs", 1)
			_check(Level3D.twin_egg_bank(5, 2) == 8,
				"bought, 3 fresh of 5 hatch double (5 -> 8)")
			_check(Level3D.twin_egg_bank(4, 4) == 4,
				"a level with no NEW rescues doubles nothing")
			_check(Level3D.twin_egg_bank(0, 0) == 0, "and zero stays zero")
			_phase = 3
		3:
			if _failures.is_empty():
				print("COINS UPGRADES TEST PASS")
			else:
				print("COINS UPGRADES TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
			return true
	return false
