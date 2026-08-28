extends SceneTree

## Headless 3D smoke test: can Harry get out of the start of the drain on his
## own two feet, holding right and jumping when he has to?
##
## This is the ONLY test that walks the opening of a level from its spawn point.
## The completability tests teleport him to the boss, so between the spawn and
## the arena nothing else is covered at all.
##
## It jumps by LOOKING for the edge rather than at hardcoded x positions. The
## previous version listed the gaps as [5.4, 10.3, 15.3] with a target of x 20,
## which were right for a 51 m drain that started him near the origin. The drain
## was then extended to 91 m with a new outfall opening and the spawn moved to
## x -37, so he walked off the first ledge at x -32.5, fell in, and never
## reached a single one of the three positions the test knew how to jump at.
## It had been failing on main ever since, with the suite reporting it and
## nobody reading it.
##
## So: a ray down, one body-length ahead. No floor there means jump. That
## re-calibrates itself the next time a level moves, which has now happened
## twice.
##
## Run with:
##   godot --headless --path . --script tests/smoke_test_3d.gd

## Far enough to clear the whole outfall staircase and get into the drain
## proper. Spawn is x -37.
const TARGET_X := -10.0
## How far ahead to look for missing floor, and how far down to accept one.
const LOOK_AHEAD := 1.3
const DROP_TOLERANCE := 1.6
## Held in REAL SECONDS, not frames. Headless idle frames tick far faster than
## 60/s, so a 70-frame hold is a fraction of a second: long enough to clear the
## variable-height jump cut, nowhere near long enough to CLIMB. Holding toward a
## wall with jump down is how a roach goes up one, and that is the only way out
## of the gaps between the outfall steps.
const JUMP_HOLD := 0.9
const WORLD_LAYER := 1

var _frames := 0
var _player: Player3D
var _jump_hold_left := 0.0
var _best_x := -999.0
var _stuck_frames := 0
var _jumps := 0


func _initialize() -> void:
	# HERMETIC: the player reads bought upgrades off the save on spawn now,
	# so a test without a scratch save measures whatever was last played.
	SaveGame.save_path = "user://test_smoke_test_3d_scratch.cfg"
	SaveGame.clear()
	var scene := (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	_player = scene.get_node("Player")
	_best_x = _player.global_position.x
	Input.action_press("move_right")


## Is there anything to land on just ahead of him?
func _floor_ahead() -> bool:
	var from := _player.global_position + Vector3(LOOK_AHEAD, 0.4, 0.0)
	var to := from + Vector3(0.0, -(DROP_TOLERANCE + 0.4), 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = WORLD_LAYER
	query.exclude = [_player.get_rid()]
	return not _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _process(delta: float) -> bool:
	_frames += 1
	var x := _player.global_position.x
	if x > _best_x + 0.05:
		_best_x = x
		_stuck_frames = 0
	else:
		_stuck_frames += 1

	if _frames % 200 == 0:
		print("f%d pos=(%.2f, %.2f) floor=%s hp=%d" % [
			_frames, x, _player.global_position.y,
			_player.is_on_floor(), _player.health])

	# Jump at a hole, and jump at a step he has stopped making progress against.
	# `is_on_wall` matters as much as `is_on_floor` here: landing short drops him
	# into a gap where he is pressed against the next step's face and never
	# touches the ground again, and the only way out is up.
	_jump_hold_left = maxf(_jump_hold_left - delta, 0.0)
	var can_launch: bool = _player.is_on_floor() or _player.is_on_wall()
	if can_launch and _jump_hold_left <= 0.0:
		if not _floor_ahead() or _stuck_frames > 40:
			Input.action_press("jump")
			_jump_hold_left = JUMP_HOLD
			_stuck_frames = 0
			_jumps += 1
	elif _jump_hold_left <= 0.0:
		Input.action_release("jump")

	var done := x >= TARGET_X or _frames >= 4000
	if done:
		print("frames=%d  x=%.2f (target %.1f)  health=%d/%d  food=%d  jumps=%d" % [
			_frames, x, TARGET_X, _player.health, _player.max_health,
			_player.food, _jumps])
		if x >= TARGET_X and _player.health >= 3:
			print("SMOKE TEST 3D PASS")
		else:
			print("SMOKE TEST 3D FAIL")
			return true
		return true
	return false
