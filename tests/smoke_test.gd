extends SceneTree

## Headless smoke test: loads the arena, holds "right", jumps once, and checks
## that Harry actually travelled. Run with:
##   godot --headless --path . --script tests/smoke_test.gd

var _frames := 0
var _player: Player
var _start_x := 0.0


func _initialize() -> void:
	var scene := (load("res://world/levels/test_arena.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	_player = scene.get_node("Player")
	_start_x = _player.global_position.x
	Input.action_press("move_right")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 60:
		Input.action_press("jump")
	elif _frames == 75:
		Input.action_release("jump")
	elif _frames == 120:
		Input.action_press("attack")
	elif _frames == 122:
		Input.action_release("attack")
	elif _frames >= 300:
		var moved := _player.global_position.x - _start_x
		print("moved_x=%.1f  health=%d/%d  food=%d  on_floor=%s  pos=%s" % [
			moved, _player.health, _player.max_health, _player.food,
			_player.is_on_floor(), _player.global_position])
		if moved > 150.0 and _player.health > 0:
			print("SMOKE TEST PASS")
		else:
			print("SMOKE TEST FAIL")
		return true
	return false
