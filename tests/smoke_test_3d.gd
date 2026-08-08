extends SceneTree

## Headless 3D smoke test: loads the drain level, holds "right", and jumps
## when approaching each gap edge (position-triggered, not frame-timed).
## PASS = Harry crosses both gaps onto the mid ledge with health mostly intact.
## Run with:
##   godot --headless --path . --script tests/smoke_test_3d.gd

const GAP_EDGES := [5.4, 10.3, 15.3]
const TARGET_X := 20.0

var _frames := 0
var _player: Player3D
var _jumped := {}
var _jump_release_frame := -1


func _initialize() -> void:
	var scene := (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	_player = scene.get_node("Player")
	Input.action_press("move_right")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames % 120 == 0:
		print("f%d pos=(%.2f, %.2f) floor=%s hp=%d" % [
			_frames, _player.global_position.x, _player.global_position.y,
			_player.is_on_floor(), _player.health])

	var x := _player.global_position.x
	if _player.is_on_floor():
		for edge in GAP_EDGES:
			if x > edge and x < edge + 1.0 and not _jumped.has(edge):
				_jumped[edge] = true
				Input.action_press("jump")
				# Process frames tick faster than physics frames headless — hold
				# long enough that the variable-height cut never triggers.
				_jump_release_frame = _frames + 70
	if _frames == _jump_release_frame:
		Input.action_release("jump")

	var done := x >= TARGET_X or _frames >= 1500
	if done:
		print("frames=%d  x=%.2f  health=%d/%d  food=%d" % [
			_frames, x, _player.health, _player.max_health, _player.food])
		if x >= TARGET_X and _player.health >= 3:
			print("SMOKE TEST 3D PASS")
		else:
			print("SMOKE TEST 3D FAIL")
		return true
	return false
