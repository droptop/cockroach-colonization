extends "res://tests/support/level_completable.gd"

## Can the ABDUCTION be finished? The Probe, then INTO the boarding light.
##
## The Probe is the REFLECT boss: its shimmer field shrugs every earthly hit,
## and only its own zap batted home with the SPOON gets through. This harness
## parks at mid-range with the spoon out and swings through every bolt's
## approach — the reflect check runs on the press, which is exactly the timing
## game a player plays. Nothing here calls take_damage: if the returned bolt
## cannot physically reach the probe's body, this fails, which is the point.


func level_id() -> String:
	return "abduction_level"


func title() -> String:
	return "ABDUCTION"


func fight_timeout() -> float:
	return 75.0 # five reflected hits on the probe's own 2.2 s firing clock


func pre_fight_checks() -> void:
	player.collect_weapon("spoon")
	check(player.active_weapon == "spoon", "the spoon can be carried")


func fight(_delta: float) -> void:
	# Hold mid-range ON THE FLOOR — stand_beside would height-match him to the
	# hovering probe, and spoils_origin reads the player's floor at the kill,
	# which is exactly how Granny's and the cat's spoils shipped in mid-air.
	# Face it and swing constantly: any zap arriving during a press returns.
	if is_instance_valid(boss):
		player.global_position = Vector3(boss.global_position.x - 3.0, 0.6, 0.0)
		player.velocity = Vector3.ZERO
		player.facing = 1
	swing()
	mash_attack()
