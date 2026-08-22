extends SceneTree

## What does one banked baby COST to draw?
##
## Babies follow you into every level for the rest of the run, and they are all
## on screen at once, clustered on the player, exactly where the camera is
## pointed. So their cost is not spread over the level the way scenery is: it
## lands entirely on the frame you are looking at.
##
## They used to wear `roach_visual_3d.gd`, the full player model at 0.4 scale:
## 21 visible meshes each, including glints eight millimetres across. Eight
## banked babies added 184 draw calls and took the tabletop from 6.19 draws/m to
## 11.94 against a ceiling of 6.5, so the game got heavier the better you had
## played. `perf_budget_test` never saw it, because it measured whatever the
## local save happened to hold, which on this machine was one baby or none.
##
## This measures the marginal cost directly: the same level loaded with none and
## with a full complement, differenced.
##
## Run with:
##   godot --headless --path . --script tests/baby_cost_test.gd

## Dense, small, and the level you reach with the most babies banked.
const LEVEL := "res://world/levels/tabletop_level.tscn"
const BABIES := 8
## A baby is a background character a fifth of Harry's size. The cheap visual
## costs FIVE: a shell and a head as meshes, then eyes, antennae and legs as one
## MultiMesh each. The player model it used to borrow cost 21. Six leaves room
## for one more part without leaving room for someone to re-attach the whole
## roach, which is the regression this exists to catch.
const MAX_DRAWS_PER_BABY := 6.0

var _phase := 0
var _frames := 0
var _level: Node
var _baseline := 0
var _loaded := 0
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = "user://test_baby_cost.cfg"
	SaveGame.clear()
	SaveGame.set_babies_banked(0)
	print("-- what a following baby costs to draw")


func _drawn(node: Node) -> int:
	var n := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		n += 1
	elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
		n += 1
	for child in node.get_children():
		n += _drawn(child)
	return n


func _process(_delta: float) -> bool:
	if _level == null and _phase < 2:
		SaveGame.set_babies_banked(0 if _phase == 0 else BABIES)
		_level = (load(LEVEL) as PackedScene).instantiate()
		root.add_child(_level)
		_frames = 0
		return false
	if _phase < 2 and _frames < 30:
		_frames += 1
		return false

	match _phase:
		0:
			_baseline = _drawn(_level)
			print("       (%d drawn with no babies)" % _baseline)
			_level.queue_free()
			_level = null
			_phase = 1
		1:
			_loaded = _drawn(_level)
			var extra := _loaded - _baseline
			var per := float(extra) / float(BABIES)
			print("       (%d drawn with %d babies: %d more, %.1f each)"
				% [_loaded, BABIES, extra, per])
			_check(extra > 0, "banked babies actually turn up (%d more)" % extra)
			_check(per <= MAX_DRAWS_PER_BABY,
				"and each costs %.1f draws, budget %.1f" % [per, MAX_DRAWS_PER_BABY])
			_level.queue_free()
			_level = null
			_phase = 2
		2:
			if _failures.is_empty():
				print("BABY COST TEST PASS")
			else:
				print("BABY COST TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
			return true
	return false
