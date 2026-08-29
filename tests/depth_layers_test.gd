extends SceneTree

## Does every level have anything IN FRONT of Harry?
##
## This exists because three of them did not. Gameplay is locked to the play
## plane at z 0 and the camera sits out at z +8.5, so every mesh at a negative z
## is behind him. The drain and the tabletop were built with a deliberate
## foreground layer of near-black silhouettes out at z 3.2; street, kitchen and
## counter between them had seventeen meshes past z 0.8 and NOTHING beyond
## z 1.4, so Harry was drawn on top of the entire level, everywhere he went.
##
## It reads to a player as the depth sorting being broken. Nothing errors, no
## test that checks positions or reachability notices, and it is invisible in a
## screenshot of any single frame — you only see it in motion, as the picture
## refusing to have any depth.
##
## Checked as geometry rather than by eye: count what is far enough in front of
## the plane to actually occlude him, and require at least one thing out at the
## depth the layer is meant to live at.
##
## Run with:
##   godot --headless --path . --script tests/depth_layers_test.gd

const LEVELS := [
	"drain_level", "street_level", "kitchen_level",
	"counter_level", "granny_kitchen_level", "tabletop_level", "pantry_level", "roof_level",
	"roof_garden_level", "tree_level", "abduction_level", "moon_level", "ship_level", "mars_level",
]

## Where gameplay happens. Everything is locked to this plane.
const PLAY_Z := 0.0
## He is not a point. Anything nearer than his own front face cannot occlude
## him, so props nudged a few centimetres forward do not count as foreground.
const BODY_HALF_DEPTH := 0.25
## Clear of him by a margin that reads on screen rather than by a hair.
const FOREGROUND_Z := PLAY_Z + BODY_HALF_DEPTH + 0.5
## A real near layer, out where the drain and tabletop put theirs. A level can
## pass the count above with a handful of knobs and handles on the play plane
## and still be flat, which is exactly how this shipped.
const NEAR_LAYER_Z := 2.0
## Sparse is the brief — these sweep past the camera, they never sit on a fight.
## Below this a level has decoration in front of the plane, not a layer.
const MIN_FOREGROUND := 5

var _index := 0
var _frames := 0
var _level: Node
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _all(node: Node, out: Array[Node]) -> void:
	out.append(node)
	for child in node.get_children():
		_all(child, out)


func _initialize() -> void:
	# HERMETIC: the player reads bought upgrades off the save on spawn now,
	# so a test without a scratch save measures whatever was last played.
	SaveGame.save_path = "user://test_depth_layers_scratch.cfg"
	SaveGame.clear()
	print("-- every level has a layer in front of the play plane")


func _process(_delta: float) -> bool:
	if _index >= LEVELS.size():
		if _failures.is_empty():
			print("DEPTH LAYERS TEST PASS")
		else:
			print("DEPTH LAYERS TEST FAIL (%d): %s"
				% [_failures.size(), ", ".join(_failures)])
		quit(0 if _failures.is_empty() else 1)
		return true

	if _level == null:
		var path := "res://world/levels/%s.tscn" % LEVELS[_index]
		_level = (load(path) as PackedScene).instantiate()
		root.add_child(_level)
		_frames = 0
		return false
	# Decor is built in _ready and some of it lands deferred.
	if _frames < 20:
		_frames += 1
		return false

	var name: String = LEVELS[_index]
	var nodes: Array[Node] = []
	_all(_level, nodes)

	var in_front := 0
	var deepest := -999.0
	for node in nodes:
		if not (node is MeshInstance3D or node is MultiMeshInstance3D):
			continue
		var z: float = (node as Node3D).global_position.z
		if z >= FOREGROUND_Z:
			in_front += 1
			deepest = maxf(deepest, z)

	# The whole check rests on him running at z 0. If that ever stops being
	# true, everything below is measuring the wrong thing.
	var player_z := 0.0
	var found_player := false
	for node in nodes:
		if node.is_in_group("player") and node is Node3D:
			player_z = (node as Node3D).global_position.z
			found_player = true
			break
	_check(not found_player or absf(player_z - PLAY_Z) < 0.01,
		"%s: he runs on the play plane (z %.2f)" % [name, player_z])

	_check(in_front >= MIN_FOREGROUND,
		"%s: %d meshes in front of him (>= %d)" % [name, in_front, MIN_FOREGROUND])
	_check(deepest >= NEAR_LAYER_Z,
		"%s: a near layer out at z %.1f (>= %.1f)"
			% [name, maxf(deepest, 0.0), NEAR_LAYER_Z])

	_level.queue_free()
	_level = null
	_index += 1
	return false
