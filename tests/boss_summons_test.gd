extends SceneTree

## When a boss calls for help, can the help actually JOIN THE FIGHT?
##
## Summons were added to all six bosses on 2026-08-20, and the immediate result
## was that Granny became mathematically unbeatable: her patience drained when
## she MISSED, so dodging well summoned the ants that then stopped you dodging.
## She was set to summon_count = 0 and the rest were never audited.
##
## This is that audit, as geometry rather than as opinion. Every boss drops its
## adds from its OWN position, and bosses do not stand where the player does:
## the cat sits at z -6, six metres behind the play plane, so all nine of its
## ants landed somewhere Harry can neither reach nor be reached from. That is
## the same trap the food burst in the same file fell into, a few lines away.
##
## So: force each boss's wave and check where it lands. On the plane he runs on,
## inside the arena the walls seal, and above the floor rather than under it.
##
## Run with:
##   godot --headless --path . --script tests/boss_summons_test.gd

const LEVELS := [
	"drain_level", "street_level", "kitchen_level",
	"counter_level", "granny_kitchen_level", "tabletop_level",
]

## Gameplay is locked to this plane. An add off it is an add out of the fight.
const PLAY_Z := 0.0
## Half a body's slack, no more.
const Z_TOLERANCE := 0.6

var _index := 0
var _frames := 0
var _level: Node
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = "user://test_boss_summons.cfg"
	SaveGame.clear()
	print("-- summoned help lands where the fight is")


func _process(_delta: float) -> bool:
	if _index >= LEVELS.size():
		if _failures.is_empty():
			print("BOSS SUMMONS TEST PASS")
		else:
			print("BOSS SUMMONS TEST FAIL (%d): %s"
				% [_failures.size(), ", ".join(_failures)])
		quit(0 if _failures.is_empty() else 1)
		return true

	if _level == null:
		_level = (load("res://world/levels/%s.tscn" % LEVELS[_index])
			as PackedScene).instantiate()
		root.add_child(_level)
		_frames = 0
		return false
	if _frames < 20:
		_frames += 1
		return false

	var name: String = LEVELS[_index]
	var boss: Node = null
	if _level.boss_path != NodePath(""):
		boss = _level.get_node_or_null(_level.boss_path)
	if boss == null:
		_check(false, "%s: no boss to audit" % name)
		_advance()
		return false

	if boss.summon_count <= 0:
		# Granny, deliberately. Her whole fight is "do not be hit", and adds
		# attack the one thing it is built around.
		_check(true, "%s: %s never calls for help, by design"
			% [name, boss.boss_name])
		_advance()
		return false

	var before := _enemies()
	boss._summon_wave()
	var arrivals: Array[Node3D] = []
	for node in _enemies():
		if not before.has(node):
			arrivals.append(node)

	_check(arrivals.size() == boss.summon_count,
		"%s: %s calls %d and %d arrive"
			% [name, boss.boss_name, boss.summon_count, arrivals.size()])

	var bounds: Vector2 = boss.arena_bounds()
	var off_plane: Array[String] = []
	var outside: Array[String] = []
	for add in arrivals:
		var at := add.global_position
		if absf(at.z - PLAY_Z) > Z_TOLERANCE:
			off_plane.append("%.1f m off the plane" % (at.z - PLAY_Z))
		if at.x < bounds.x or at.x > bounds.y:
			outside.append("x %.1f outside %.1f..%.1f" % [at.x, bounds.x, bounds.y])
	_check(off_plane.is_empty(), "%s: and they land on the play plane%s"
		% [name, "" if off_plane.is_empty()
			else " - STRANDED: " + ", ".join(off_plane)])
	_check(outside.is_empty(), "%s: and inside the arena walls%s"
		% [name, "" if outside.is_empty()
			else " - SEALED OUT: " + ", ".join(outside)])

	# Nine ants is the default across every boss: three waves of three. Printed
	# rather than asserted, because how hard a fight should be is a design call
	# and this test is about whether the adds can take part at all.
	print("       (%s: %d waves of %d, %d ants over the fight)"
		% [boss.boss_name, boss.summon_at.size(), boss.summon_count,
			boss.summon_at.size() * boss.summon_count])
	_advance()
	return false


func _advance() -> void:
	_level.queue_free()
	_level = null
	_index += 1


## Every BODY that could join the fight. Deliberately not "things that answer
## stagger()": the mantis summons NYMPHS, which are MantisBoss3D instances, and
## bosses in this game deliberately do not implement stagger at all. Counting by
## that method reported the mantis calling three and none arriving, when what
## had actually happened was the test looking for the wrong kind of thing.
func _enemies() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for child in _level.get_children():
		if child is CharacterBody3D:
			out.append(child as Node3D)
	return out
