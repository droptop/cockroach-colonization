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


var _on_ledge := false


func fight(_delta: float) -> void:
	var anchors: Array = boss._anchors
	if not anchors.is_empty():
		_cut(anchors[0])
		return
	# Webs gone, so she is down and hittable. If she is still immune here the
	# fight has no ending and the drain cannot be left.
	for action in ["move_up", "jump", "move_left", "move_right"]:
		Input.action_release(action)
	stand_beside(boss)
	mash_attack()


## FLIES to each anchor from the arena ledge, with real inputs. The previous
## version teleport-pinned him in mid-air 0.9 m under the knot every frame,
## which proved the anchor hittable and nothing about whether a player can BE
## there — and under it the fight shipped with no wing refill in the arena, so
## an empty bar made the webs unreachable and the live report was "cutting the
## webs is not possible", for the second time. Position is EARNED here: one
## placement on the ledge, then run, fly and swing.
##
## The wing bar is topped up like health is: keeping the bot fed is fight
## choreography this harness does not owe. The arena's respawning crumbs and
## the boss rule ("Eat crumbs to refly!") carry the economy for humans.
func _cut(anchor: Node3D) -> void:
	if not is_instance_valid(anchor):
		return
	if not _on_ledge:
		_on_ledge = true
		player.global_position = Vector3(38.5, 8.2, 0.0)
		player.velocity = Vector3.ZERO
	player.wing_energy = player.max_wing_energy
	var dx: float = anchor.global_position.x - player.global_position.x
	if absf(dx) > 0.4:
		Input.action_press("move_right" if dx > 0.0 else "move_left")
		Input.action_release("move_left" if dx > 0.0 else "move_right")
	else:
		Input.action_release("move_right")
		Input.action_release("move_left")
	Input.action_press("jump")
	Input.action_press("move_up")
	if player.global_position.distance_to(anchor.global_position) < 2.0:
		mash_attack()
