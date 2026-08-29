extends SceneTree

## Does the game teach its two COMBOS anywhere?
##
## Both are the ordinary attack with a direction already held, which is why they
## cost no new binding — and also why nobody finds them. Neither was mentioned
## anywhere in six levels:
##
##   MEGA SMASH     down-attack after falling further than `mega_smash_height`,
##                  so height you had to earn is worth something coming back
##                  down. +2 damage.
##   BACKFLIP KICK  attack while holding AWAY from your facing, on the floor.
##                  Hits BEHIND you and carries you out of there. +1 damage.
##
## A move nobody knows about is a move that is not in the game. The hint system
## already existed and already taught the plain bite, the pogo, flight, the wall
## climb and the dash; these two just fell through.
##
## The check is deliberately about the INPUTS rather than the words around them,
## so the copy can be rewritten freely and this still holds. It also enforces the
## two rules every world label in this project has: web-safe ASCII, because
## anything else renders as a box in the shipped build, and a length that fits
## the HUD line the hints are shown on.
##
## Run with:
##   godot --headless --path . --script tests/combos_taught_test.gd

const LEVELS := [
	"drain_level", "street_level", "kitchen_level",
	"counter_level", "granny_kitchen_level", "tabletop_level", "pantry_level", "roof_level",
	"roof_garden_level", "tree_level", "abduction_level", "moon_level", "ship_level",
]

## What has to be findable, and the words that count as teaching it.
const COMBOS := {
	"MEGA SMASH": ["SMASH"],
	"BACKFLIP KICK": ["BACK + X", "BACKFLIP"],
}
## Hints are shown on one HUD line, and the Queen's used to run past both screen
## edges at 66 characters before HintBubble3D started wrapping them.
const MAX_HINT := 80

var _index := 0
var _frames := 0
var _level: Node
var _taught := {}
var _hints := 0
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = "user://test_combos.cfg"
	SaveGame.clear()
	for combo in COMBOS:
		_taught[combo] = ""
	print("-- the combos are taught somewhere")


func _labels(node: Node, out: Array[Label3D]) -> void:
	if node is Label3D:
		out.append(node as Label3D)
	for child in node.get_children():
		_labels(child, out)


func _process(_delta: float) -> bool:
	if _index >= LEVELS.size():
		_check(_hints > 0, "found %d hints across %d levels" % [_hints, LEVELS.size()])
		for combo in COMBOS:
			var where: String = _taught[combo]
			_check(where != "", "%s is taught%s"
				% [combo, (" (" + where + ")") if where != "" else " - NOWHERE"])
		if _failures.is_empty():
			print("COMBOS TAUGHT TEST PASS")
		else:
			print("COMBOS TAUGHT TEST FAIL (%d): %s"
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
	var labels: Array[Label3D] = []
	var hints := _level.get_node_or_null("Hints")
	if hints:
		_labels(hints, labels)

	var too_long: Array[String] = []
	var not_ascii: Array[String] = []
	for label in labels:
		_hints += 1
		var text := label.text
		if text.length() > MAX_HINT:
			too_long.append("%s (%d)" % [label.name, text.length()])
		for i in text.length():
			if text.unicode_at(i) > 126 or text.unicode_at(i) < 32:
				not_ascii.append(label.name)
				break
		var upper := text.to_upper()
		for combo in COMBOS:
			if _taught[combo] != "":
				continue
			for phrase in COMBOS[combo]:
				if upper.contains(phrase):
					_taught[combo] = "%s / %s" % [name, label.name]
					break

	_check(too_long.is_empty(), "%s: %d hints fit the line%s"
		% [name, labels.size(), "" if too_long.is_empty()
			else " - TOO LONG: " + ", ".join(too_long)])
	_check(not_ascii.is_empty(), "%s: and are plain ASCII%s"
		% [name, "" if not_ascii.is_empty()
			else " - NOT ASCII: " + ", ".join(not_ascii)])

	# AND THE LEVEL HAS TO PICK THEM ALL UP. `_style_hints` does
	# get_node_or_null("Hints") and walks that ONE node's children, so a scene
	# that declares [node name="Hints"] twice silently orphans everything in the
	# second block. The street did exactly that: three hints in the file, ONE
	# collected, and the two lost were the dash and the mantis's frontal guard -
	# one of the four boss rules you cannot work out by playing.
	var collected: int = _level._hint_labels.size()
	_check(collected == labels.size(),
		"%s: and all %d reach the player%s"
			% [name, labels.size(), "" if collected == labels.size()
				else " - ONLY %d COLLECTED, %d ORPHANED"
					% [collected, labels.size() - collected]])

	_level.queue_free()
	_level = null
	_index += 1
	return false
