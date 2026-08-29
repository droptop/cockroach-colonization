extends "res://tests/support/level_completable.gd"

## Can the ROOF be finished? The Magpie, then out under the gable coping.
##
## The Magpie is the "punish the GLOAT" boss: untouchable on the wing, it
## swoops to STEAL coins and then lands to crow over them — the openings are
## the gloat (after a successful theft) and the tumble (after a dodged
## swoop). This fight lets it steal: the harness keeps the purse topped so
## every swoop earns a gloat, stands beside the strutting thief, and mashes.


func level_id() -> String:
	return "roof_level"


func title() -> String:
	return "ROOF"


func fight_timeout() -> float:
	return 90.0 # gloat windows come on the swoop rhythm, not on demand


func fight(_delta: float) -> void:
	# Keep the bait shiny: a broke player only gets pecked, never a gloat.
	if SaveGame.coins() < 3:
		SaveGame.add_coins(6)
	match boss.state:
		MagpieBoss3D.State.GLOAT, MagpieBoss3D.State.CRASH:
			stand_beside(boss)
			mash_attack()
		_:
			Input.action_release("attack")
			# Stand out in the open at gloat height so swoops find him and
			# the steal lands - being stolen from IS the strategy here.
			if player.global_position.distance_to(
					Vector3(56.0, 1.0, 0.0)) > 3.0:
				player.global_position = Vector3(56.0, 1.0, 0.0)
				player.velocity = Vector3.ZERO
