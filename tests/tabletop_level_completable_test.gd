extends "res://tests/support/level_completable.gd"

## Can the TABLETOP be finished? Cat, then the end of the game.
##
## The cat is the "WHAT to hit" boss. The cat itself is immune permanently; the
## only thing that forwards damage is its PAW, and only while the paw is down
## and `vulnerable`. The paw is also built fresh for every swipe and freed on
## the retract, so there is nothing to hold a reference to between attacks.
##
## This is the level the user could not finish, and the paw is exactly the kind
## of thing that breaks silently: it shipped once on a collision layer the
## player's bite area could not see, which made the cat unbeatable by any means
## while every cat test passed, because they all called `take_damage` on it
## directly. This one swings at it.
##
## Last in the chain, so there is no next scene to arrive in: finishing it
## completes the game instead.
##
## Run with:
##   godot --headless --path . --script tests/tabletop_level_completable_test.gd


func level_id() -> String:
	return "tabletop_level"


func title() -> String:
	return "TABLETOP"


func fight_timeout() -> float:
	return 90.0 # one opening per swipe, and the paw is only down for a moment


func fight(_delta: float) -> void:
	var paw = boss._paw
	if is_instance_valid(paw) and paw.vulnerable:
		# It came down on top of him, which is the point: the opening and the
		# danger are the same object.
		stand_beside(paw, 0.8)
		mash_attack()
		return
	Input.action_release("attack")
	# Stand under it and wait to be swiped at. The paw lands where he IS, so
	# staying put is what puts the target within reach.
	player.global_position = Vector3(
		boss.global_position.x - 2.0, player.global_position.y, 0.0)
	player.velocity = Vector3.ZERO
