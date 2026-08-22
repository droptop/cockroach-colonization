extends "res://tests/support/level_completable.gd"

## Can the KITCHEN be finished? Rat, then the door.
##
## The rat is the one boss with no damage gate at all: his question is WHEN, not
## where or what, and the answer is his recovery window. So the fight here is
## the plainest of the five - stand at his flank and swing on the cooldown - and
## if THIS one cannot be won by pressing the attack button then nothing else in
## the level matters.
##
## Run with:
##   godot --headless --path . --script tests/kitchen_level_completable_test.gd


func level_id() -> String:
	return "kitchen_level"


func title() -> String:
	return "KITCHEN"


func fight(_delta: float) -> void:
	stand_beside(boss)
	mash_attack()
