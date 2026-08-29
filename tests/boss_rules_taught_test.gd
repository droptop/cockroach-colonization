extends SceneTree

## Does the game ever TELL you how to beat each boss?
##
## Four of the six have a rule you cannot discover by playing. The cat is immune
## everywhere except its paw. The mantis blocks a 150 degree cone across its
## face. The Queen cannot be touched until every web is cut. The wasp has to be
## baited into the syrup and then DODGED, because `_impact` checks whether the
## dive hit HIM before it checks the syrup, so a dive that connects bounces off
## and the wasp is never vulnerable at all.
##
## None of that was said anywhere. The player reported the cat level as
## unfinishable twice, and the wasp cost a completability test ninety seconds of
## failing against a boss that turns out to be beatable in three.
##
## The Label3D hints do carry some of it, but they live at a fixed point in the
## level with a 7 m radius: the cat's sits at x 44 with the cat at x 52, so it
## has faded out before the fight it explains begins.
##
## So this checks the rule exists, fits a HUD line, is web-safe ASCII, and
## ACTUALLY REACHES THE HUD when the fight starts. That last one is the point:
## a string sitting on an export that nothing displays would pass every other
## check here and tell the player nothing, which is the shape of mistake that
## has come up all day. What it cannot check is whether the WORDING helps, which
## is a question for a person.
##
## Run with:
##   godot --headless --path . --script tests/boss_rules_taught_test.gd

const LEVELS := [
	"drain_level", "street_level", "kitchen_level",
	"counter_level", "granny_kitchen_level", "tabletop_level", "pantry_level", "roof_level",
	"roof_garden_level", "tree_level", "abduction_level", "moon_level", "ship_level", "mars_level",
]

## Long enough to say something, short enough to cross a HUD line at speed.
const MAX_RULE := 72

var _index := 0
var _frames := 0
var _level: Node
var _seen := 0
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = "user://test_boss_rules.cfg"
	SaveGame.clear()
	print("-- every boss says what it wants")


func _process(_delta: float) -> bool:
	if _index >= LEVELS.size():
		_check(_seen == LEVELS.size(), "all %d bosses carry a rule" % LEVELS.size())
		if _failures.is_empty():
			print("BOSS RULES TAUGHT TEST PASS")
		else:
			print("BOSS RULES TAUGHT TEST FAIL (%d): %s"
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
		_check(false, "%s: no boss" % name)
		_advance()
		return false

	var rule: String = boss.boss_rule
	var ok := rule.strip_edges() != ""
	if ok:
		_seen += 1
	_check(ok, "%s: %s says how to beat it%s"
		% [name, boss.boss_name, "" if ok else " - SILENT"])
	if ok:
		_check(rule.length() <= MAX_RULE,
			"%s: and it fits a HUD line (%d chars, max %d)"
				% [name, rule.length(), MAX_RULE])
		# Web-safe ASCII only, same rule as every other world and HUD label:
		# anything else renders as a box in the shipped build.
		var clean := true
		for i in rule.length():
			if rule.unicode_at(i) > 126 or rule.unicode_at(i) < 32:
				clean = false
				break
		_check(clean, "%s: and it is plain ASCII" % name)
		print("       \"%s\"" % rule)

	# AND IT HAS TO ARRIVE. Start the fight and read the HUD back.
	var hud := _find_hud(_level)
	if hud == null:
		_check(false, "%s: no HUD to speak to" % name)
	else:
		boss.engage()
		var shown: String = hud._message_label.text
		_check(shown == rule,
			"%s: and the HUD says it when the fight starts%s"
				% [name, "" if shown == rule else " - SHOWED \"%s\"" % shown])

	_advance()
	return false


func _find_hud(node: Node) -> Node:
	if node.has_method("show_message") and "_message_label" in node:
		return node
	for child in node.get_children():
		var found := _find_hud(child)
		if found:
			return found
	return null


func _advance() -> void:
	_level.queue_free()
	_level = null
	_index += 1
