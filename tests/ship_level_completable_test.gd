extends "res://tests/support/level_completable.gd"

## Can the SHIP be finished? The Janitor-Bot, then through the bridge door.
##
## The bot is the CLOG boss: its running fan shrugs every direct hit, slow
## junk gets eaten, and only a can SMACKED into the intake jams it mortal.
## This harness plays the whole loop with real presses: stand at a drifting
## can and swing (the smack), then stand at the choking bot and swing (the
## damage). Reading boss state and the junk list is positioning only - every
## hit that matters goes through the attack button.


func level_id() -> String:
	return "ship_level"


func title() -> String:
	return "SHIP"


func fight_timeout() -> float:
	return 75.0 # several clog cycles on the bot's own restock clock


func fight(_delta: float) -> void:
	if boss.state == JanitorBoss3D.State.CLOGGED:
		stand_beside(boss, 1.5)
		swing()
		mash_attack()
		return
	var can: Node3D = null
	for c in boss._junk:
		if is_instance_valid(c) and not c.smacked:
			can = c
			break
	if can:
		stand_beside(can, 0.8)
		swing()
		mash_attack()
	else:
		Input.action_release("attack")
		player.velocity = Vector3.ZERO
