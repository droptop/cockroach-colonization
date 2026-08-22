extends SceneTree

## Shared harness for "can this level actually be FINISHED?".
##
## NOT a test itself. It lives under tests/support/ so the suite's `tests/*.gd`
## glob does not try to run it.
##
## `granny_level_completable_test` proved the shape and then found four
## lockouts that every boss test had passed straight through. The difference is
## that a boss test pokes the boss and this plays the level: it beats the boss
## the way a player has to, WALKS to the exit under its own power, and waits for
## the next scene to actually load. Each of those three has been separately
## broken:
##
##   - the Spider Queen sat on collision_layer 0 and could not be hit at all
##   - the arena's invisible collider was never freed, so the gate lifted and a
##     wall stayed behind it and the door could not be reached on foot
##   - `body_entered` fires on the way IN and never again, so beating a boss
##     while stood in the exit opened a door with nothing left to trigger it
##
## A subclass supplies the level, and the choreography for its own boss:
##
##   func level_id() -> String      which level
##   func title() -> String         what to print
##   func fight(delta) -> void      drive INPUT until the boss is defeated
##   func pre_fight_checks() -> void        optional, runs once before the fight
##   func fight_timeout() -> float          how long to allow
##
## `fight()` must press the attack button where a player would. Calling
## `take_damage()` on the boss proves nothing about whether it can be hit, which
## is exactly how the Queen and the cat's paw shipped unhittable.

var _phase := 0
var _t := 0.0
var _step := 0.0

var level: Node
var player: Node3D
var boss: Node

var _exit_x := 0.0
var _walked := 0.0
var _walk_dir := 1.0
var _arrived: Node3D
var _completed := false
var _defeated := false
var _unlocked := false
var _start_health := 0
## Where the boss WAS. The rat frees itself shortly after dying, so nothing
## after the fight can rely on the node still being there.
var _boss_x := 0.0

## Big enough to hide a doorway. Granny's pantry was 3.2 x 3.0.
const DOOR_BLOCKER_WIDTH := 2.0
const DOOR_BLOCKER_HEIGHT := 1.5
var _failures: Array[String] = []


# --- subclass contract -------------------------------------------------------

func level_id() -> String:
	return ""


func title() -> String:
	return level_id().to_upper().replace("_", " ")


## Drive INPUT to beat the boss. Called every frame of the fight phase.
func fight(_delta: float) -> void:
	pass


## Optional assertions before the fight starts.
func pre_fight_checks() -> void:
	pass


func fight_timeout() -> float:
	return 60.0


# --- harness -----------------------------------------------------------------

func check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _next(phase: int) -> void:
	_phase = phase
	_step = 0.0


## Keeps him upright so the test measures whether the level can be finished, not
## whether this particular scripted fight out-damages the boss.
func keep_alive() -> void:
	if player == null:
		return
	player.health = player.max_health
	player._invincibility_timer = 9999.0


## Attacks land on a cooldown; a test that just holds the button swings once.
func swing() -> void:
	if player:
		player._bite_cooldown_timer = 0.0


var _attack_down := false


## HOLDING the button swings exactly once: the attack fires on
## `is_action_just_pressed`. So it has to be released and pressed again, and the
## cooldown cleared, or a test "mashing attack" lands one hit and then waits out
## the fight doing nothing.
func mash_attack() -> void:
	_attack_down = not _attack_down
	if _attack_down:
		Input.action_press("attack")
	else:
		Input.action_release("attack")


## Park him at arm's length on one side of a target, facing it, standing still.
## Positioning by hand rather than walking him in: this test is about whether
## the thing can be HIT and the level LEFT, not about pathfinding.
func stand_beside(target: Node3D, offset := 1.1, height := 0.0) -> void:
	if player == null or target == null or not is_instance_valid(target):
		return
	var side := -1.0 if target.global_position.x >= player.global_position.x else 1.0
	player.global_position = target.global_position \
		+ Vector3(side * offset, height, 0.0)
	player.global_position.z = 0.0
	player.velocity = Vector3.ZERO
	player.facing = int(-side)


## Directly OVER a target and falling, which is what a down-attack needs: it
## only counts in the air, and `is_on_floor()` has to be false for the swing to
## read as downward at all.
func stand_above(target: Node3D, height := 1.5) -> void:
	if player == null or target == null or not is_instance_valid(target):
		return
	player.global_position = target.global_position + Vector3(0.0, height, 0.0)
	player.global_position.z = 0.0
	player.velocity = Vector3(0.0, -2.0, 0.0)


func _initialize() -> void:
	# Beating a boss is PERSISTED. Without a scratch save that is wiped first,
	# the level removes the boss before the second run and the test fails in the
	# suite while passing on its own.
	SaveGame.save_path = "user://test_%s_completable.cfg" % level_id()
	SaveGame.clear()
	Settings.settings_path = "user://test_%s_settings.cfg" % level_id()
	level = (load("res://world/levels/%s.tscn" % level_id()) as PackedScene).instantiate()
	root.add_child(level)
	player = level.get_node_or_null("Player")


func _process(delta: float) -> bool:
	_t += delta
	_step += delta
	if _t > fight_timeout() + 90.0:
		print("%s FAIL: stalled in phase %d" % [title(), _phase])
		quit(1)
		return true

	if _phase >= 1 and _phase <= 2:
		keep_alive()

	match _phase:
		0:
			if _step < 1.0:
				return false
			print("-- %s: beat the boss, walk out, arrive somewhere" % title())
			check(player != null, "the level has a player")
			if player == null:
				_next(9)
				return false
			if level.boss_path != NodePath(""):
				boss = level.get_node_or_null(level.boss_path)
			check(boss != null, "the boss is there (%s)" % level.boss_path)
			if boss == null:
				_next(9)
				return false
			check(level.exit_state == Level3D.ExitState.LOCKED,
				"the way out starts locked")
			_start_health = boss.health
			boss.defeated.connect(func() -> void: _defeated = true)
			level.exit_state_changed.connect(func(st: int) -> void:
				if st == Level3D.ExitState.UNLOCKED:
					_unlocked = true)
			pre_fight_checks()
			_next(1)
		1:
			# THE FIGHT, played rather than poked.
			fight(delta)
			if is_instance_valid(boss):
				_boss_x = boss.global_position.x
			if not _defeated and _step < fight_timeout():
				return false
			_release_all()
			check(_defeated, "it can be beaten by playing (%d -> %d health in %.0fs)"
				% [_start_health,
					boss.health if is_instance_valid(boss) else 0, _step])
			if not _defeated:
				_next(6)
				return false
			_next(2)
		2:
			if not _unlocked and _step < 12.0:
				return false
			check(_unlocked, "beating it opens the way out")

			# Anything it drops has to be REACHABLE. Everything a boss drops is
			# positioned relative to the boss, and Granny stands six metres up a
			# counter: her spoils and her pantry payoff both spawned in mid-air.
			var floor_y: float = player.global_position.y
			var high: Array[String] = []
			var rewards := 0
			for child in level.get_children():
				if child is RewardPickup3D:
					rewards += 1
					var dy: float = (child as Node3D).global_position.y - floor_y
					if dy > 2.5 or dy < -2.5:
						high.append("%.1f m off the floor" % dy)
			check(high.is_empty(), "its %d spoils are within reach%s"
				% [rewards, "" if high.is_empty()
					else " - UNREACHABLE: " + ", ".join(high)])

			var zone: Area3D = level.get_node_or_null("ExitZone")
			check(zone != null, "the level has an exit")
			if zone == null:
				_next(6)
				return false
			_exit_x = zone.global_position.x
			check(_blocking(zone).is_empty(), "and nothing is parked on it%s"
				% ("" if _blocking(zone).is_empty()
					else " - BLOCKING: " + ", ".join(_blocking(zone))))

			# Back to the boss, on his own feet, and make him WALK.
			player.global_position = Vector3(
				_boss_x, player.global_position.y, 0.0)
			player.velocity = Vector3.ZERO
			_walk_dir = signf(_exit_x - player.global_position.x)
			if is_zero_approx(_walk_dir):
				_walk_dir = 1.0
			_next(3)
		3:
			# WALK there. Teleporting into the exit is what hid the arena
			# collider that stayed up after its gate came down: he had beaten
			# the boss and still could not reach the door, and every teleporting
			# test passed the whole time.
			keep_alive()
			Input.action_press("move_right" if _walk_dir > 0.0 else "move_left")
			# Levels are not flat. A hop clears the lip of a platform without
			# turning this into a pathfinder.
			if _step > 1.0 and fmod(_step, 0.8) < delta * 2.0:
				Input.action_press("jump")
			else:
				Input.action_release("jump")
			_walked = maxf(_walked, absf(player.global_position.x - _boss_x))
			if level.exit_state != Level3D.ExitState.TRANSITION and _step < 30.0:
				return false
			_release_all()
			check(level.exit_state == Level3D.ExitState.TRANSITION,
				"and he can WALK from the boss to the door (got to x %.1f, door at %.1f)"
					% [player.global_position.x, _exit_x])
			_next(4)
		4:
			# THE THING THAT ACTUALLY MATTERS. TRANSITION only means the level
			# agreed to leave. The report was that it never arrives anywhere.
			if level.next_scene == "":
				# Last level: nothing to load, so completion is the signal.
				var gm := root.get_node_or_null("GameManager")
				if gm and not _completed:
					_completed = true
				if _step < 3.0:
					return false
				check(level.exit_state == Level3D.ExitState.TRANSITION,
					"the last level completes rather than chaining on")
				_next(5)
				return false
			for child in root.get_children():
				if child != level and child is Node3D and child.name != "GameManager":
					_arrived = child
			if _arrived == null and _step < 14.0:
				return false
			check(_arrived != null, "and the next level actually loads (%s)"
				% (_arrived.name if _arrived else "NOTHING - stuck in this level"))
			_next(5)
		5:
			if _failures.is_empty():
				print("%s COMPLETABLE TEST PASS" % title())
			else:
				print("%s COMPLETABLE TEST FAIL (%d): %s"
					% [title(), _failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
			return true
		6:
			print("%s COMPLETABLE TEST FAIL (%d): %s"
				% [title(), _failures.size(), ", ".join(_failures)])
			quit(1)
			return true
		9:
			print("%s COMPLETABLE TEST FAIL: nothing to fight" % title())
			quit(1)
			return true
	return false


func _release_all() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down",
			"attack", "jump", "dash"]:
		Input.action_release(action)


## Bulky, script-less geometry standing at the door, at DOOR height. Comparing x
## alone flagged a foreground pipe eleven metres up; ignoring bulk flagged the
## grout lines in the floor.
func _blocking(zone: Area3D) -> Array[String]:
	var out: Array[String] = []
	for child in level.get_children():
		if not (child is MeshInstance3D) or child.get_script() != null:
			continue
		var at: Vector3 = (child as Node3D).global_position
		if absf(at.x - _exit_x) >= 1.6 or absf(at.y - zone.global_position.y) >= 2.5:
			continue
		var span := _extent((child as MeshInstance3D).mesh)
		if span.x > DOOR_BLOCKER_WIDTH and span.y > DOOR_BLOCKER_HEIGHT:
			out.append("%s at %.1f (%.1f x %.1f)" % [child.name, at.x, span.x, span.y])
	return out


## Width and height of a mesh, so "is this parked on the door" is a question
## about SIZE. Treating every non-box as bulky flagged the sugar bowl that IS
## the counter's finale and a 0.4 m glow marking the kitchen's exit, neither of
## which hides anything: Granny's pantry, the thing this check exists for, was
## 3.2 m across and 3 m tall.
func _extent(mesh: Mesh) -> Vector2:
	if mesh is BoxMesh:
		var size := (mesh as BoxMesh).size
		return Vector2(size.x, size.y)
	if mesh is CylinderMesh:
		var cyl := mesh as CylinderMesh
		return Vector2(maxf(cyl.top_radius, cyl.bottom_radius) * 2.0, cyl.height)
	if mesh is SphereMesh:
		var sph := mesh as SphereMesh
		return Vector2(sph.radius * 2.0, sph.height)
	if mesh is PrismMesh:
		var pri := mesh as PrismMesh
		return Vector2(pri.size.x, pri.size.y)
	if mesh == null:
		return Vector2.ZERO
	return Vector2(99.0, 99.0) # something unrecognised and possibly enormous
