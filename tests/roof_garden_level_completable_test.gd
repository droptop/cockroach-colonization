extends "res://tests/support/level_completable.gd"

## Can the ROOF GARDEN be finished? The Snail, then over the trellis.
##
## The Snail is the "FLIP it" boss: the shell shrugs every attack, but the
## FORK's launch rocks it, two launches inside the window turn it over, and
## the soft side takes real damage until it rights itself. The fight is the
## fork's launch stat finally made load-bearing, so this test EQUIPS the fork
## (the level places one on the route for humans) and simply fights with it:
## the same swings both tip and, once it is over, hurt.


func level_id() -> String:
	return "roof_garden_level"


func title() -> String:
	return "ROOF GARDEN"


func fight_timeout() -> float:
	return 90.0 # flip windows come and go with the righting rhythm


func pre_fight_checks() -> void:
	# The fork must actually be ON the route, or the fight is unwinnable for
	# a human who cannot call collect_weapon.
	check(level.get_node_or_null("Fork1") != null, "a fork is placed on the route")
	player.collect_weapon("fork")
	while player.active_weapon != "fork":
		player._weapon_index = (player._weapon_index + 1) % player.collected_weapons.size()


func fight(_delta: float) -> void:
	# Stand at the shell ON THE FLOOR and keep forking: launches tip it, the
	# flip drops its immunity, and the same mashing hurts the soft side.
	# Not stand_beside: that matches the boss's height, and a snail mid-tip
	# would drag the player into the air with it — spoils spawn at the
	# player's floor, so a floating player begets floating spoils.
	var side := -1.0 if boss.global_position.x >= player.global_position.x else 1.0
	player.global_position = Vector3(boss.global_position.x + side * 1.3, 0.6, 0.0)
	player.velocity = Vector3.ZERO
	player.facing = int(-side)
	mash_attack()
