extends SceneTree

## Does every script in the game actually COMPILE?
##
## This exists because the Mars dust hopper never did. One line,
## `var dir := [-1.0, 1.0][randi() % 2] * 0.5`, cannot infer a type from an
## array element, so the whole script failed to parse. Godot's answer to that
## is an error in a log nobody reads and a node with NO script: both hoppers
## shipped as inert boxes that never hopped, never bit and could not be hurt,
## and stayed that way for five weeks. `--import` does not compile scripts, and
## no suite happened to load that one, so everything was green.
##
## The claim is the dull, generic one: every .gd under the project loads and
## can be instantiated, and every .tscn loads. Staging folders are skipped
## because they are excluded from the export too.
##
## Run with:
##   godot --headless --path . --script tests/scripts_load_test.gd

const SKIP := ["res://.godot", "res://build", "res://user_added_images",
	"res://Roach Game SFX", "res://iron-dice-font "]

var _done := false
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


## On the first frame, not in _initialize: scripts that name an autoload only
## compile once the autoloads exist.
func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	print("-- every script compiles and every scene loads")
	var scripts := 0
	var scenes := 0
	var broken: Array[String] = []
	var stack: Array[String] = ["res://"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			var path := dir.path_join(sub)
			if not SKIP.has(path):
				stack.append(path)
		for file in DirAccess.get_files_at(dir):
			var path := dir.path_join(file)
			if file.ends_with(".gd"):
				scripts += 1
				var script := load(path) as GDScript
				if script == null or not script.can_instantiate():
					broken.append(path)
			elif file.ends_with(".tscn"):
				scenes += 1
				if load(path) == null:
					broken.append(path)
	_check(scripts > 100 and scenes > 30, "found the project (%d scripts, %d scenes)" % [scripts, scenes])
	_check(broken.is_empty(), "all of them load%s" % (
		"" if broken.is_empty() else ": BROKEN " + ", ".join(broken)))
	if _failures.is_empty():
		print("SCRIPTS LOAD TEST PASS")
	else:
		print("SCRIPTS LOAD TEST FAIL (%d)" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
	return true
