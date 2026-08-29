extends "res://tests/support/level_completable.gd"

## Can MARS be finished? The War Tripod, then the colony.
##
## The tripod is the TOPPLE boss: the eye rides at 5.6 and can never be
## reached from the plane; the three knees ride at swing height. This harness
## breaks each knee with real presses, then swings on the fallen eye while it
## is down, and repeats - the tripod stands back up on repaired legs after
## three hits, so the finale takes more than one topple.


func level_id() -> String:
	return "mars_level"


func title() -> String:
	return "MARS"


func fight_timeout() -> float:
	return 90.0 # two full topples, on the tripod's own rise-and-repair clock


func fight(_delta: float) -> void:
	if boss.state == TripodBoss3D.State.CRASHED:
		stand_beside(boss, 1.6)
		swing()
		mash_attack()
		return
	var knee: Node = null
	for k in boss._knees:
		if is_instance_valid(k) and not k.buckled:
			knee = k
			break
	if knee != null and boss.state == TripodBoss3D.State.STRIDE:
		stand_beside(knee, 0.8)
		swing()
		mash_attack()
	else:
		Input.action_release("attack")
		player.velocity = Vector3.ZERO
