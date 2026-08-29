extends "res://tests/support/level_completable.gd"

## Can the TREE be finished? The Owl, then out at the crown.
##
## The Owl is the "FREEZE" boss: no armour at all, but it strikes at any
## MOVEMENT under its stare - walking, flying, or swinging. The fight is
## played on its clock: this harness creeps and strikes only while the head
## is away or turning, and turns to stone the moment the eyes burn. Swinging
## while watched draws the swoop, so even the mash respects the stare.


func level_id() -> String:
	return "tree_level"


func title() -> String:
	return "TREE"


func fight_timeout() -> float:
	return 90.0 # the away windows come on the owl's clock, not ours


func fight(_delta: float) -> void:
	match boss.state:
		OwlBoss3D.State.AWAY, OwlBoss3D.State.TURNING, OwlBoss3D.State.ROOST:
			stand_beside(boss, 1.2)
			mash_attack()
		_:
			# The eyes are on, or it is mid-swoop: STONE. Velocity is what it
			# reads, and a teleported stand is a stand at rest.
			Input.action_release("attack")
			player.velocity = Vector3.ZERO
