extends SceneTree

## The shop between levels: prices are honest, refusals are free, the matrix
## shows every banked baby, and CONTINUE actually goes somewhere.
##
## Purchases are driven by PRESSING THE BUTTONS, not by calling SaveGame —
## a shop whose buttons are wired to nothing would pass any test that spends
## the money directly.
##
## Run with:
##   godot --headless --path . --script tests/shop_test.gd

var _phase := 0
var _t := 0.0
var _shop: Node
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


## Cards are Buttons NAMED by upgrade id; their faces are icon + price labels,
## not text, so text-matching would find nothing.
func _button_for(id: String) -> Button:
	var found: Button = null
	for node in _all(_shop):
		if node is Button and node.name == id:
			found = node
	return found


func _all(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children():
		out.append_array(_all(child))
	return out


func _initialize() -> void:
	SaveGame.save_path = "user://test_shop.cfg"
	SaveGame.clear()
	SaveGame.add_coins(30)
	SaveGame.set_babies_banked(5)
	ShopScreen.banked_delta = 2
	ShopScreen.next_scene_path = "res://world/levels/test_arena.tscn"
	_shop = (load("res://ui/shop/shop_screen.tscn") as PackedScene).instantiate()
	root.add_child(_shop)


func _process(delta: float) -> bool:
	_t += delta
	match _phase:
		0:
			if _t < 0.2:
				return false
			print("-- the shop sells what it says")
			# Two grids live here now: the item cards (Buttons) and the baby
			# matrix (ColorRect squares). The matrix is the one made of squares.
			var grid: GridContainer = null
			for node in _all(_shop):
				if node is GridContainer and node.get_child_count() > 0 \
						and node.get_child(0) is ColorRect:
					grid = node
			_check(grid != null and grid.get_child_count() == 5,
				"the matrix shows one square per banked baby (%d)"
					% (grid.get_child_count() if grid else 0))

			var hat := _button_for("hat")
			_check(hat != null, "the hat is on the shelf")
			# TWO presses: the first only ARMS the card. A single-click purchase
			# let browsing the shelves silently drain the balance, which the
			# live report read - correctly - as coins disappearing.
			if hat:
				hat.pressed.emit()
			_check(SaveGame.coins() == 30 and SaveGame.upgrade_level("hat") == 0,
				"one press arms, and spends NOTHING (%d coins)" % SaveGame.coins())
			if hat:
				hat.pressed.emit()
			_check(SaveGame.coins() == 24, "buying it costs its price (30 -> %d)"
				% SaveGame.coins())
			_check(SaveGame.upgrade_level("hat") == 1, "and the hat is owned")
			_check(hat != null and hat.disabled,
				"a maxed upgrade stops selling")

			var power := _button_for("power_hits")
			if power:
				power.pressed.emit()
				power.pressed.emit()
			_check(SaveGame.coins() == 4, "a second purchase deducts too (%d left)"
				% SaveGame.coins())

			var heart := _button_for("heart")
			if heart:
				heart.pressed.emit()
				heart.pressed.emit()
			_check(SaveGame.coins() == 4 and SaveGame.upgrade_level("heart") == 0,
				"an unaffordable press is refused for free")

			print("-- CONTINUE goes somewhere")
			_shop.continue_to_next()
			_phase = 1
			_t = 0.0
		1:
			var arrived := root.get_node_or_null("TestArena") != null
			if not arrived and _t < 8.0:
				return false
			_check(arrived, "the next scene actually loads")
			_check(ShopScreen.next_scene_path == "", "the handoff is consumed")
			_phase = 2
		2:
			if _failures.is_empty():
				print("SHOP TEST PASS")
			else:
				print("SHOP TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
			return true
	return false
