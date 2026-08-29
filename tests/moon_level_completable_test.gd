extends "res://tests/support/level_completable.gd"

## Can the MOON be finished? The Dust Worm, then out the hatch.
##
## The worm is the UNBURY boss: buried it shrugs everything, and a hit on
## the mound throws it out flopping and mortal for a few seconds. This
## harness stands at the mound and swings through the whole cycle - the
## smack that exposes and the bites that land are the same button, which is
## exactly how a player fights it. Eruptions under our feet are survived by
## keep_alive; the test is about whether the cycle CLOSES, not tanking.


func level_id() -> String:
	return "moon_level"


func title() -> String:
	return "MOON"


func fight_timeout() -> float:
	return 75.0 # two expose windows on the worm's own clock, plus eruptions


func fight(_delta: float) -> void:
	stand_beside(boss, 1.2)
	swing()
	mash_attack()
