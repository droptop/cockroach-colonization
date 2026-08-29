extends SceneTree

## THE WALKER (BACKLOG item 10): every level, spawn to boss arena, on his own
## six legs. The completability suites teleport to the fights, so the middle
## of every level — where the player actually lives — was proven by nothing:
## a platform an inch too high would pass all 57 suites and strand every real
## player at the same spot.
##
## The bot uses ONLY real inputs: it holds run, rays ahead for missing floor
## and jumps, holds into walls to climb, dashes long gaps, and flies when
## stuck. No teleports, ever. It succeeds when its x crosses the boss arena's
## near edge; it fails naming the exact x where progress died.
##
## What made the 2026-08-22 attempt unshippable was flakiness, and each of
## its causes has a specific answer here:
##   - enemies knocked the bot around  -> it is harness-funded: health,
##     invincibility and WINGS topped every frame. The question is geometry,
##     not combat; the fights have their own suites. (So this proves
##     "reachable with the player's full toolkit", flight included.)
##   - frame-count holds               -> every hold is in REAL seconds
##   - fixed timeouts                  -> a STALL clock that only runs while
##     no forward progress is made (and pauses while webbed), driving a
##     DETERMINISTIC escalation ladder: jump -> climb -> fly -> retreat
##     further and fly again, with the retreat growing each round
##
## Run with:
##   godot --headless --path . --script tests/levels_walkable_test.gd

const LEVELS := [
	"drain_level", "street_level", "kitchen_level",
	"counter_level", "granny_kitchen_level", "tabletop_level", "pantry_level", "roof_level",
	"roof_garden_level", "tree_level",
]

## Real seconds a level gets before the walk counts as failed.
const TIME_BUDGET := 150.0
## How far ahead the bot looks for floor, and how far down floor may be.
const LOOK_AHEAD := 1.3
const LONG_LOOK := 3.2
const DROP_TOLERANCE := 1.8
const WORLD_LAYER := 1

var _index := 0
var _level: Node
var _player: Node
var _boss: Node
var _target_x := 0.0
var _t := 0.0
var _stall := 0.0
var _best_x := -999.0
var _escalations := 0
var _jump_hold := 0.0
var _dash_delay := -1.0
var _fly_hold := 0.0
var _retreat_hold := 0.0
## Which rung of the escalation ladder this stall window has already tried:
## 0 = nothing yet, 1 = climbed, 2 = flew. Progress resets it. Without this
## the cheap rungs re-arm forever and the ladder never climbs — exactly how
## the first run sat under the drain's capped shaft for 150s re-gripping the
## same wall (the known BACKLOG item 9 trap, faithfully reproduced).
var _rung := 0
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = "user://test_levels_walkable.cfg"
	SaveGame.clear()
	SaveGame.set_babies_banked(0)
	print("-- every level is walkable from its spawn to its boss arena")


func _floor_ahead(distance: float) -> bool:
	var from: Vector3 = _player.global_position + Vector3(distance, 0.4, 0.0)
	var to := from + Vector3(0.0, -(DROP_TOLERANCE + 0.4), 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = WORLD_LAYER
	query.exclude = [_player.get_rid()]
	return not _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _release_all() -> void:
	for action in ["move_left", "move_right", "move_up", "jump", "dash", "attack"]:
		Input.action_release(action)


func _start_level() -> void:
	_level = (load("res://world/levels/%s.tscn" % LEVELS[_index])
		as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node_or_null("Player")
	_boss = _level.get_node_or_null(_level.boss_path) \
		if not _level.boss_path.is_empty() else null
	_t = 0.0
	_stall = 0.0
	_escalations = 0
	_jump_hold = 0.0
	_dash_delay = -1.0
	_fly_hold = 0.0
	_retreat_hold = 0.0
	_best_x = -999.0


func _finish_level(passed: bool, detail: String) -> void:
	_release_all()
	_check(passed, "%s: %s" % [LEVELS[_index], detail])
	_level.queue_free()
	_level = null
	_index += 1


func _process(delta: float) -> bool:
	if _index >= LEVELS.size():
		if _failures.is_empty():
			print("LEVELS WALKABLE TEST PASS")
		else:
			print("LEVELS WALKABLE TEST FAIL (%d): %s"
				% [_failures.size(), ", ".join(_failures)])
		quit(0 if _failures.is_empty() else 1)
		return true

	if _level == null:
		_start_level()
		return false

	_t += delta
	if _t < 1.0:
		return false
	if _player == null or _boss == null:
		_finish_level(false, "no player or boss to walk between")
		return false
	if _best_x < -900.0:
		_best_x = _player.global_position.x
		var bounds: Vector2 = _boss.arena_bounds() if _boss.has_method("arena_bounds") \
			else Vector2((_boss as Node3D).global_position.x - 4.0, 0.0)
		_target_x = bounds.x + 0.6

	# Harness-funded: the walk is about geometry, so nothing may end it.
	_player.health = _player.max_health
	_player._invincibility_timer = 9999.0
	_player.wing_energy = _player.max_wing_energy
	_player._wings_spent = false

	var x: float = _player.global_position.x
	if x >= _target_x:
		_finish_level(true, "walked spawn to arena (x %.1f in %.0fs, %d escalations)"
			% [x, _t, _escalations])
		return false
	if _t > TIME_BUDGET:
		_finish_level(false, "STUCK: best x %.1f of %.1f after %.0fs (%d escalations, now at %.1f, %.1f)"
			% [_best_x, _target_x, _t, _escalations,
				x, _player.global_position.y])
		return false

	# Progress and the stall clock. Webbed time is not stalled time.
	if x > _best_x + 0.05:
		_best_x = x
		_stall = 0.0
		_rung = 0
	elif not (_player.has_method("is_wrapped") and _player.is_wrapped()):
		_stall += delta

	# --- the drive -----------------------------------------------------------
	Input.action_press("move_right")

	# Timed holds burn down first.
	_jump_hold = maxf(_jump_hold - delta, 0.0)
	_fly_hold = maxf(_fly_hold - delta, 0.0)
	if _retreat_hold > 0.0:
		_retreat_hold -= delta
		Input.action_press("move_left")
		Input.action_release("move_right")
		Input.action_release("jump")
		# Retreating with jump HELD, so a pit's back wall is climbed out of,
		# not leaned against.
		Input.action_press("jump")
		if _retreat_hold <= 0.0:
			# Retreat done: come back flying, higher for longer each round —
			# and with a FRESH ladder, or a bot in a pit spends its climb and
			# fly once and then stands inert forever (the street's gutter
			# proved it: nine growing retreats, zero climbs).
			_fly_hold = 2.2 + 0.6 * minf(float(_escalations), 5.0)
			_stall = 0.0
			_rung = 0
		return false
	Input.action_release("move_left")

	if _dash_delay >= 0.0:
		_dash_delay -= delta
		if _dash_delay < 0.0:
			Input.action_press("dash")
	else:
		Input.action_release("dash")

	if _fly_hold > 0.0 or _jump_hold > 0.0:
		Input.action_press("jump")
		return false
	Input.action_release("jump")

	# The ladder, HARDEST RUNG FIRST — the first version checked climb first
	# and returned early, so a bot on a wall re-gripped it forever and the
	# stall rungs below were unreachable.
	#
	# Truly stuck: this needs a run-up from further back — retreat and return
	# airborne. The drain's shaft is the archetype: the route is the pipes,
	# reached by backing off and climbing the air, not by hugging the wall.
	if _stall > 8.0:
		_escalations += 1
		_retreat_hold = minf(1.2 + 1.2 * float(_escalations), 4.8)
		_stall = 0.0
		return false
	# Climbed and it wasn't enough: fly over whatever it is. Once per window —
	# flight is neutered while climbing (holding into a wall + jump climbs),
	# so re-firing it against a wall would just burn the clock.
	if _stall > 4.0 and _rung < 2:
		_rung = 2
		_fly_hold = 2.2
		return false
	var grounded: bool = _player.is_on_floor()
	# A short gap: hop it. A long one: hop and DASH off the apex, the move the
	# street's gutter teaches.
	if grounded and not _floor_ahead(LOOK_AHEAD):
		_jump_hold = 0.9
		if not _floor_ahead(LONG_LOOK):
			_dash_delay = 0.22
		return false
	# Pressed against something: climb it (hold into the wall + jump).
	if _player.is_on_wall() and _stall > 0.6 and _rung < 1:
		_rung = 1
		_jump_hold = 2.6
		return false
	return false
