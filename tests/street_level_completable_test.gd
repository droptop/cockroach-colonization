extends "res://tests/support/level_completable.gd"

## Can the STREET be finished? Mantis, then the door.
##
## The mantis is the "from WHERE" boss: a 150 degree guard cone across its face
## catches anything swung at it from the front, and it pivots to keep facing
## you, so mashing attack at its flank does NOTHING. Its own docstring offers
## two answers, and this takes the reliable one: get ABOVE it, where a
## down-attack comes in steeper than the guard can cover.
##
## Which makes this test worth more than the kitchen's. If the pogo ever stops
## clearing the guard, the mantis becomes unkillable, the street stops being
## completable, and every existing mantis test still passes because they all
## drive damage into it directly.
##
## Run with:
##   godot --headless --path . --script tests/street_level_completable_test.gd


func level_id() -> String:
	return "street_level"


func title() -> String:
	return "STREET"


func fight(_delta: float) -> void:
	# Over its head, falling, holding down. Anything else is a frontal hit.
	stand_above(boss)
	Input.action_press("move_down")
	mash_attack()
