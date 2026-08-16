class_name Encounter

## Encounter fairness rules, shared by enemies that deliberately have no common
## base class. Static, like Fx and Snd, so nothing needs an autoload and the
## headless test harness can call straight into it.
##
## Two rules, both from the brief's "limit simultaneous attackers; no attacks
## from off-camera":
##
## 1. **Nothing commits from off-camera.** The camera sits 8.5 back at 50 deg
##    fov, so a little over 7 units either side of Harry is the whole visible
##    world. An attack launched from outside that arrives with no warning,
##    which is not difficulty — it is a cheap shot. This is not hypothetical:
##    the fly's `spit_range` is 13, so until this landed a fly could shoot him
##    from a screen and a half away, off-screen, with nothing to react to.
##
## 2. **Only so many things commit at once.** Three enemies lunging together is
##    not harder than one, it is unreadable — the player cannot tell which
##    telegraph belongs to which, so there is no read to make and it becomes a
##    coin flip. Everyone else keeps chasing and posturing; they just wait for a
##    turn, which is what makes a crowd feel like a crowd rather than a wall.
##
## The token count is a scene-tree GROUP rather than a counter, on purpose:
## a freed or queue_free'd enemy leaves its groups automatically, so an enemy
## killed mid-lunge cannot leak its token and silently throttle the level for
## the rest of the run. There is no bookkeeping to get wrong.

## Enemies currently committed to an attack.
const ATTACKING := "attacking"

## Half-width of the visible world, in metres, measured off the real camera:
## 8.5 back, 50 deg vertical fov, 16:9 gives ~7.05. Rounded down, because an
## attack starting exactly at the screen edge is technically visible and
## practically still a surprise.
const ON_SCREEN_X := 6.5

## How many enemies may be mid-attack at once.
const MAX_ATTACKERS := 2


## Can `enemy` be seen right now? The camera is parented to the player and
## centred on him, so distance-to-Harry IS distance-to-screen-centre — which is
## also why this works headless, where there is no viewport to ask.
static func on_screen(enemy: Node3D, target: Node3D) -> bool:
	if not is_instance_valid(enemy) or not is_instance_valid(target):
		return false
	return absf(enemy.global_position.x - target.global_position.x) <= ON_SCREEN_X


## Everything currently committed to an attack.
static func attackers(of: Node) -> int:
	if not is_instance_valid(of) or of.get_tree() == null:
		return 0
	return of.get_tree().get_nodes_in_group(ATTACKING).size()


## The gate every enemy asks before committing. Bosses are exempt from both
## rules by design: a boss is the fight, so it does not queue behind its own
## adds, and its arena keeps it on screen anyway.
static func may_commit(enemy: Node3D, target: Node3D) -> bool:
	if enemy is BaseBoss3D:
		return true
	if not on_screen(enemy, target):
		return false
	# Already holding a token: re-asking mid-attack must not fail, or an enemy
	# that checks every frame would abort its own lunge.
	if enemy.is_in_group(ATTACKING):
		return true
	return attackers(enemy) < MAX_ATTACKERS


## Take a token. Safe to call twice.
static func commit(enemy: Node) -> void:
	if is_instance_valid(enemy) and not enemy.is_in_group(ATTACKING):
		enemy.add_to_group(ATTACKING)


## Give it back. Safe to call when not holding one, so every path out of an
## attack state can call it unconditionally.
static func release(enemy: Node) -> void:
	if is_instance_valid(enemy) and enemy.is_in_group(ATTACKING):
		enemy.remove_from_group(ATTACKING)
