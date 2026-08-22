extends SceneTree

## Can the Spider Queen's webs be reached BY JUMPING, with the wings dry?
##
## The webs are the only way into her fight: she is immune until every anchor is
## cut. They used to hang 3.4 m above the arena ledge with a cut window of y 9.5
## to 10.4, while a jump tops out at 1.49 m (8.8^2 / 2g). So the whole fight
## required hovering in a 0.9 m band on wing energy, six times over, on the FIRST
## boss in the game, and the report was "cant cut spider queen webs".
##
## `destructible_reachable_test` swings at an anchor for real, but it TELEPORTS
## him underneath one first, which proves the cut lands and says nothing about
## whether a player can get there. This asks the other half of the question.
##
## Wings are forced dry on purpose: flight should be a way to do this, not the
## only way.
##
## WHAT THIS DOES AND DOES NOT PROVE. It proves a web is cuttable from the floor
## without hovering. It does NOT prove the fight is comfortable: a headless test
## presses the button on the perfect frame every time, and the player reporting
## "cant cut spider queen webs" does not. The webs were lowered and their hitbox
## widened on 2026-08-22 for that reason, as a deliberate forgiveness change and
## not as a fix for a lockout: this test passed before the change as well.
## The jump budget below is a loose guard against the geometry drifting far
## enough that the ground stops being an option at all.
##
## Run with:
##   godot --headless --path . --script tests/spider_queen_webs_reachable_test.gd

var _f := 0
var _p: Player3D
var _q
var _anchor: Node3D
var _hp := 0
var _peak := 0.0
var _down := false
var _jumps := 0
var _grounded := false

## Loose. One is what both the old and the new geometry manage with perfect
## timing; this exists to fail if the webs ever drift out of jump range, not to
## measure how the fight feels.
const JUMP_BUDGET := 2

func _initialize() -> void:
	SaveGame.save_path = "user://test_webs_reachable.cfg"
	SaveGame.clear()
	var scene := (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	_p = scene.get_node("Player")
	_q = scene.get_node("SpiderQueen")

func _process(_d: float) -> bool:
	_f += 1
	if _f < 60:
		return false
	if _anchor == null:
		var list: Array = _q._anchors
		if list.is_empty():
			return false
		_anchor = list[list.size() / 2]
		_hp = _anchor.health
		# Stand him under it on the ledge, once.
		_p.global_position = Vector3(_anchor.global_position.x, 8.0, 0.0)
		_p.velocity = Vector3.ZERO
		print("-- the way into her fight is within reach on foot")
		print("       (anchor y %.2f, ledge 7.40, gap %.2f m, jump reaches %.2f m)"
			% [_anchor.global_position.y, _anchor.global_position.y - 7.4,
				_p.jump_velocity * _p.jump_velocity / 52.0])
	_p.health = _p.max_health
	_p._invincibility_timer = 999.0
	# WINGS OFF: this is about whether a jump alone reaches.
	_p.wing_energy = 0.0
	_p._wings_spent = true
	_peak = maxf(_peak, _p.global_position.y)

	# Count LAUNCHES, not frames spent standing. Incrementing every grounded
	# frame counted the wait, not the jump, and reported 2 or 3 for the same
	# run depending on how the frames happened to fall.
	if _p.is_on_floor():
		_grounded = true
		Input.action_press("jump")
	else:
		if _grounded:
			_grounded = false
			_jumps += 1
		if _p.velocity.y < 0.0:
			Input.action_release("jump")
	Input.action_press("move_up")
	_down = not _down
	if _down:
		Input.action_press("attack")
	else:
		Input.action_release("attack")

	if not is_instance_valid(_anchor) or _anchor.health < _hp:
		var thrifty := _jumps <= JUMP_BUDGET
		print(("  ok   " if thrifty else "  FAIL ")
			+ "a web is cut in %d jump(s) of %d allowed, wings dry (peak y %.2f)"
				% [_jumps, JUMP_BUDGET, _peak])
		print("SPIDER QUEEN WEBS REACHABLE TEST "
			+ ("PASS" if thrifty else "FAIL"))
		quit(0 if thrifty else 1)
		return true
	if _f >= 2500:
		print("  FAIL a web cannot be reached without hovering: peak y %.2f, anchor y %.2f, %d jumps"
			% [_peak, _anchor.global_position.y, _jumps])
		print("SPIDER QUEEN WEBS REACHABLE TEST FAIL")
		quit(1)
		return true
	return false
