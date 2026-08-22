extends "res://tests/support/level_completable.gd"

## Can the DRAIN be finished? Spider Queen, then the outfall.
##
## The Queen is the "hit something ELSE first" boss. She hangs out of reach and
## is immune while she hangs; the fight is cutting the WEB ANCHORS holding her
## up, one at a time, with up-attacks. Only when the last one goes does she drop,
## and only then does she become hittable at all.
##
## Two separate things have shipped broken in this one fight. The anchors were
## StaticBody3D, which an Area3D does not report, so no attack volume in the
## game could see them; and the Queen herself sat on collision_layer 0, which
## meant that even after the webs were cut she could not be hit by anything,
## ever. Both passed every Queen test, because they all drove damage into her
## directly. This test cuts the webs and then swings at her.
##
## Run with:
##   godot --headless --path . --script tests/drain_level_completable_test.gd


func level_id() -> String:
	return "drain_level"


func title() -> String:
	return "DRAIN"


func fight_timeout() -> float:
	return 90.0 # several anchors to cut before the fight even opens


func fight(_delta: float) -> void:
	var anchors: Array = boss._anchors
	if not anchors.is_empty():
		_cut(anchors[0])
		return
	# Webs gone, so she is down and hittable. If she is still immune here the
	# fight has no ending and the drain cannot be left.
	Input.action_release("move_up")
	stand_beside(boss)
	mash_attack()


## Under the knot, holding up, swinging. Same geometry the up-attack needs.
func _cut(anchor: Node3D) -> void:
	if not is_instance_valid(anchor):
		return
	player.global_position = anchor.global_position + Vector3(0, -0.9, 0)
	player.global_position.z = 0.0
	player.velocity = Vector3.ZERO
	Input.action_press("move_up")
	mash_attack()
