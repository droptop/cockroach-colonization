extends "res://tests/support/level_completable.gd"

## Can the COUNTER be finished? Wasp, then the door.
##
## The wasp is the "stand WHERE" boss. It hovers out of reach and is immune the
## whole time it is up there; the only opening in the fight is baiting a dive
## into one of the syrup patches, where it sticks fast and drops its immunity
## for a couple of seconds. It dives at wherever Harry IS, so the bait is
## literally standing in the honey and waiting to be dived at.
##
## Which is why this level is one of the two the summon audit flagged: adds that
## shove him off the syrup do not make the fight harder, they make it
## impossible, and nothing else would notice.
##
## Run with:
##   godot --headless --path . --script tests/counter_level_completable_test.gd


func level_id() -> String:
	return "counter_level"


func title() -> String:
	return "COUNTER"


func fight_timeout() -> float:
	return 90.0 # it has to be baited down once per hit, and it hovers between


func fight(_delta: float) -> void:
	# `immune_to_damage` is the opening itself: the wasp drops it only while
	# stuck in the syrup. Reading that rather than its FSM means this keeps
	# working if the states are renamed, and it is the exact flag that decides
	# whether the fight is winnable at all.
	if not boss.immune_to_damage:
		stand_beside(boss)
		mash_attack()
		return
	Input.action_release("attack")

	# THE WHOLE FIGHT IS TWO MOVES, and the second one is easy to miss:
	# `_impact` checks whether the dive HIT HIM before it checks the syrup, so a
	# dive that connects bounces off and never sticks. Standing in the honey and
	# staying there gets you hit forever and the wasp is never once vulnerable.
	# Bait it, THEN get out of the blast, and let it bury itself.
	if boss.state == WaspBoss3D.State.TELEGRAPH or boss.state == WaspBoss3D.State.DIVE:
		var aim: Vector3 = boss._aim
		player.global_position = Vector3(
			aim.x + boss.dive_radius + 1.4, aim.y + 0.5, 0.0)
		player.velocity = Vector3.ZERO
		return
	_bait()


## Stand in the honey so the telegraph aims THERE. The dive is committed to the
## spot it marked, so where he goes afterwards no longer changes where it lands.
func _bait() -> void:
	var pools: Array = boss._syrup
	if pools.is_empty():
		return # spilled deferred; not down yet
	var at: Vector3 = pools[pools.size() / 2]
	player.global_position = Vector3(at.x, at.y + 0.5, 0.0)
	player.velocity = Vector3.ZERO
