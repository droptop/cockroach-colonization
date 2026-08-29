extends SceneTree

## Is anything PARKED on a checkpoint or an exit?
##
## Granny's pantry payoff was built 3.2 m wide at x 52 with the door at x 53, so
## the reward for beating her stood squarely on the way out: the exit was behind
## it and nothing said so. That check now lives in the completability harness,
## but only for the boss's own door on the level being played.
##
## Every level has an exit and most have two checkpoints, and any of them can be
## buried by decor at any time, because decor is authored in code by position
## and nothing has ever cross-checked the two. A checkpoint you cannot see is a
## checkpoint you do not use, and you find out where it was after you die.
##
## THERE ARE TWO QUESTIONS HERE and three wrong versions of this test conflated
## them before it settled:
##
##   an EXIT sits on the play plane at z 0, and is blocked by bulk standing in
##   the player's way at z 0. That is the Granny pantry case exactly.
##
##   a CHECKPOINT SIGN sits forward at z 1.2 to 1.4 so it reads against the
##   wall, which puts it IN FRONT of the level's props. It can only be hidden by
##   something further forward still. Judging signs by the play plane reported
##   every crate and worktop in the game, none of which is in front of anything.
##
## Also: a prop whose top is below the landmark hides nothing, which is what the
## drain's floor slabs at y -1.2 were doing in the results.
##
## SIZE is the other half. An earlier version flagged anything tall and
## caught a 0.4 m glow box MARKING the kitchen exit and the sugar bowl that IS
## the counter's finale, neither of which hides anything. So it asks for
## something big enough to actually stand in the way: wider than the door and
## taller than Harry.
##
## Run with:
##   godot --headless --path . --script tests/landmarks_clear_test.gd

const LEVELS := [
	"drain_level", "street_level", "kitchen_level",
	"counter_level", "granny_kitchen_level", "tabletop_level", "pantry_level",
]

## Granny's pantry was 3.2 x 3.0. Below this a prop is dressing, not a wall.
const BLOCKER_WIDTH := 2.0
const BLOCKER_HEIGHT := 1.5
## How far off the play plane a prop can be and still be in the way.
const PLANE_SLACK := 1.5
## Above this z a landmark is a sign facing the camera, not a doorway.
const FORWARD_SIGN_Z := 0.5
## How close in x counts as "on" the landmark, and how far in y still hides it.
const NEAR_X := 1.6
const NEAR_Y := 2.5

var _index := 0
var _frames := 0
var _level: Node
var _checked := 0
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = "user://test_landmarks.cfg"
	SaveGame.clear()
	SaveGame.set_babies_banked(0)
	print("-- nothing is parked on a checkpoint or an exit")


func _all(node: Node, out: Array[Node]) -> void:
	out.append(node)
	for child in node.get_children():
		_all(child, out)


## Width and height of a mesh, so "could this hide a doorway" is a question
## about size rather than about what kind of primitive it happens to be.
func _extent(mesh: Mesh) -> Vector2:
	if mesh is BoxMesh:
		var b := (mesh as BoxMesh).size
		return Vector2(b.x, b.y)
	if mesh is CylinderMesh:
		var c := mesh as CylinderMesh
		return Vector2(maxf(c.top_radius, c.bottom_radius) * 2.0, c.height)
	if mesh is SphereMesh:
		var s := mesh as SphereMesh
		return Vector2((s as SphereMesh).radius * 2.0, (s as SphereMesh).height)
	if mesh is PrismMesh:
		var p := (mesh as PrismMesh).size
		return Vector2(p.x, p.y)
	if mesh == null:
		return Vector2.ZERO
	return Vector2(99.0, 99.0) # unrecognised and possibly enormous


## Transparent, so it obscures nothing however big it is.
func _see_through(mesh: Mesh) -> bool:
	if mesh == null or mesh.get_surface_count() == 0:
		return false
	var mat := mesh.surface_get_material(0)
	if mat is StandardMaterial3D:
		var std := mat as StandardMaterial3D
		return std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
			or std.albedo_color.a < 0.9
	return false


func _blockers(nodes: Array[Node], at: Vector3) -> Array[String]:
	var out: Array[String] = []
	for node in nodes:
		if not (node is MeshInstance3D) or node.get_script() != null:
			continue
		var pos: Vector3 = (node as Node3D).global_position
		if absf(pos.x - at.x) >= NEAR_X or absf(pos.y - at.y) >= NEAR_Y:
			continue
		if at.z > FORWARD_SIGN_Z:
			# A forward-facing sign: only things nearer the camera can hide it.
			if pos.z <= at.z + 0.1:
				continue
		elif absf(pos.z) > PLANE_SLACK:
			# A doorway on the play plane: only bulk on that plane is in the
			# way. Backdrop sits at z -5, foreground silhouettes at z +3.2.
			continue
		# You can see straight through a light shaft. Its beam is a script-less
		# child of LightShaft3D, so it looks exactly like loose decor from here,
		# and the drain hangs one 0.7 m in front of its own exit.
		if _see_through((node as MeshInstance3D).mesh):
			continue
		var span := _extent((node as MeshInstance3D).mesh)
		# Its top is under the landmark, so it is floor rather than wall.
		if pos.y + span.y * 0.5 < at.y:
			continue
		if span.x > BLOCKER_WIDTH and span.y > BLOCKER_HEIGHT:
			out.append("%s (%.1f x %.1f) at x %.1f y %.1f z %.1f" % [
				node.name, span.x, span.y, pos.x, pos.y, pos.z])
	return out


func _process(_delta: float) -> bool:
	if _index >= LEVELS.size():
		_check(_checked > 0, "found %d landmarks across %d levels"
			% [_checked, LEVELS.size()])
		if _failures.is_empty():
			print("LANDMARKS CLEAR TEST PASS")
		else:
			print("LANDMARKS CLEAR TEST FAIL (%d): %s"
				% [_failures.size(), ", ".join(_failures)])
		quit(0 if _failures.is_empty() else 1)
		return true

	if _level == null:
		_level = (load("res://world/levels/%s.tscn" % LEVELS[_index])
			as PackedScene).instantiate()
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

	var landmarks: Array = []
	for node in nodes:
		if node is Checkpoint3D:
			landmarks.append(["checkpoint", node as Node3D])
	var zone := _level.get_node_or_null("ExitZone")
	if zone is Node3D:
		landmarks.append(["exit", zone as Node3D])

	var buried: Array[String] = []
	for entry in landmarks:
		_checked += 1
		var at: Vector3 = (entry[1] as Node3D).global_position
		var found := _blockers(nodes, at)
		if not found.is_empty():
			buried.append("%s at x %.1f behind %s"
				% [entry[0], at.x, ", ".join(found)])
	_check(buried.is_empty(), "%s: %d landmarks clear%s"
		% [name, landmarks.size(), "" if buried.is_empty()
			else " - BURIED: " + "; ".join(buried)])

	_level.queue_free()
	_level = null
	_index += 1
	return false
