extends SceneTree

## Is Harry ever standing INSIDE the scenery?
##
## This exists because Mars buried him twice. The rolling dunes are squashed
## spheres up to 17 m across; the first live report ("Harry vanished behind
## sand") was answered by moving their CENTRES behind the play plane, which
## left every one of them still bulging through it, because a 7 m radius does
## not care about a 3.5 m offset. He spawned inside a dune and stayed invisible
## for the first dozen metres, in the shipped build, with every suite green.
##
## `depth_layers_test` asks whether anything is in front of him at all. This
## asks the opposite: nothing solid-looking and bigger than he is may CONTAIN
## the spot he stands on. Checked as geometry, exactly (boxes and ellipsoids),
## along the whole walkable floor of every level.
##
## Run with:
##   godot --headless --path . --script tests/play_plane_clear_test.gd

const LEVELS := [
	"drain_level", "street_level", "kitchen_level",
	"counter_level", "granny_kitchen_level", "tabletop_level", "pantry_level", "roof_level",
	"roof_garden_level", "tree_level", "abduction_level", "moon_level", "ship_level", "mars_level",
]

## His centre, and his front face: decor reaching either one is drawn over him.
const PROBE_Z := [0.0, 0.3]
## Chest height above whatever he is standing on.
const PROBE_UP := 0.3
const STEP_X := 0.5
## Only scenery big enough to swallow him. Pebbles and crumbs on the floor
## are meant to be walked through.
const MIN_WIDTH := 1.5
const MIN_HEIGHT := 0.6
## Stacked platforms under one x, and how far above the spawn still counts as
## somewhere he goes (the lid over every level does not).
const MAX_SURFACES := 8
const REACH_UP := 14.0

var _index := -1
var _level: Node3D
var _wait := 0
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	SaveGame.save_path = "user://test_play_plane_clear.cfg"
	SaveGame.clear()
	print("-- nothing bigger than Harry contains the floor he walks on")


func _physics_process(_delta: float) -> bool:
	if _level == null:
		_index += 1
		if _index >= LEVELS.size():
			if _failures.is_empty():
				print("PLAY PLANE CLEAR TEST PASS")
			else:
				print("PLAY PLANE CLEAR TEST FAIL (%d)" % _failures.size())
			quit(0 if _failures.is_empty() else 1)
			return true
		_level = (load("res://world/levels/%s.tscn" % LEVELS[_index]) as PackedScene).instantiate()
		root.add_child(_level)
		_wait = 4 # decor is built in _ready; colliders need a step to register
		return false
	_wait -= 1
	if _wait > 0:
		return false
	_survey()
	_level.free()
	_level = null
	return false


func _survey() -> void:
	var decor: Array[MeshInstance3D] = []
	_collect(_level, decor)
	var spawn := _level.get_node_or_null("SpawnPoint") as Node3D
	var exit_zone := _level.get_node_or_null("ExitZone") as Node3D
	if spawn == null or exit_zone == null:
		_check(false, "%s: has a SpawnPoint and an ExitZone to walk between" % LEVELS[_index])
		return
	var from_x := minf(spawn.global_position.x, exit_zone.global_position.x)
	var to_x := maxf(spawn.global_position.x, exit_zone.global_position.x)
	var space := _level.get_world_3d().direct_space_state
	var buried := {}
	var probes := 0
	var x := from_x
	while x <= to_x:
		# EVERY surface under this x, not just the first: levels carry a lid
		# far overhead, and a ray that stops there surveys the ceiling.
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(x, 60.0, 0.0), Vector3(x, -20.0, 0.0), 1)
		var skip: Array[RID] = []
		for _layer in MAX_SURFACES:
			query.exclude = skip
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				break
			skip.append(hit.rid)
			if hit.position.y > spawn.global_position.y + REACH_UP:
				continue
			for z in PROBE_Z:
				probes += 1
				var at := Vector3(x, hit.position.y + PROBE_UP, z)
				for inst in decor:
					if _contains(inst, at):
						var key := "%s at %s" % [inst.mesh.get_class(), inst.global_position.snappedf(0.1)]
						if not buried.has(key):
							buried[key] = x
		x += STEP_X
	var detail := ""
	for key in buried:
		detail += "\n         %s swallows him from x %.1f" % [key, buried[key]]
	_check(probes > 0 and buried.is_empty(), "%s: %d floor probes clear of %d big decor meshes%s" % [
		LEVELS[_index], probes, decor.size(), detail])


## Scenery only: anything under a body or an area is gameplay and has its own
## tests, and see-through meshes (shafts, glows, glass) do not hide anything.
func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is CollisionObject3D or node is CanvasLayer:
		return
	if node is MeshInstance3D and node.visible and node.mesh != null:
		var inst := node as MeshInstance3D
		if (inst.mesh is BoxMesh or inst.mesh is SphereMesh) and not _see_through(inst):
			var size := inst.mesh.get_aabb().size * inst.global_transform.basis.get_scale().abs()
			if size.x >= MIN_WIDTH and size.y >= MIN_HEIGHT:
				out.append(inst)
	for child in node.get_children():
		_collect(child, out)


func _see_through(inst: MeshInstance3D) -> bool:
	var mat := inst.get_active_material(0) as BaseMaterial3D
	return mat != null and (mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		or mat.albedo_color.a < 0.99)


func _contains(inst: MeshInstance3D, at: Vector3) -> bool:
	var local := inst.global_transform.affine_inverse() * at
	if inst.mesh is SphereMesh:
		var sphere := inst.mesh as SphereMesh
		var half_h := sphere.height * 0.5
		if sphere.radius <= 0.0 or half_h <= 0.0:
			return false
		return (local.x * local.x + local.z * local.z) / (sphere.radius * sphere.radius) \
			+ (local.y * local.y) / (half_h * half_h) < 1.0
	return inst.mesh.get_aabb().has_point(local)
