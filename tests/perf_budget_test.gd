extends SceneTree

## Rendering budget, per level.
##
## This project's whole strategy — Compatibility renderer, shadows off, 0.75
## render scale, procedural textures — exists because software-GL browsers
## dropped under 1 fps with shadow maps. Content has been added hard since
## anyone last checked what that costs, so this counts it.
##
## In the Compatibility renderer a MeshInstance3D with one surface is roughly
## one draw call, which is the number that actually matters on the web target.
## MultiMesh collapses many into one, and that is the whole reason to use it.
##
## Thresholds are advisory, not pass/fail on style — the test only fails if a
## level is genuinely over budget.
##
## Run with:
##   godot --headless --path . --script tests/perf_budget_test.gd

const LEVELS := [
	"drain_level", "street_level", "kitchen_level",
	"counter_level", "granny_kitchen_level", "tabletop_level", "pantry_level", "roof_level",
	"roof_garden_level", "tree_level",
]
## DENSITY, not total. This counted every surface in the whole level against a
## flat ceiling, which measures how much CONTENT a level has rather than what it
## costs to draw. Godot frustum-culls: a level twice as long is not twice as
## expensive, because the far end is never on screen with the near end. Making
## the drain longer tripped a flat 260 while actually LOWERING its density.
##
## So the budget is per metre of level, which is roughly what the camera sees at
## once. Calibrated above every existing level, so nothing regresses.
## 6.5 rather than 6.0: tabletop is the genuinely densest level at 5.97/m (a
## small crowded arena, which is exactly what this should be strictest about),
## and a threshold half a percent above the worst real case fails on any edit.
const DRAWS_PER_METRE := 6.5
## And a backstop on the raw total, well clear of any real level, so that a
## pathological scene still fails rather than being excused by its own size.
const DRAW_CALL_CEILING := 700
## Real-time lights are expensive even unshadowed.
const LIGHT_BUDGET := 12
## Transparent surfaces overdraw, which is what actually kills fill-rate.
const TRANSPARENT_BUDGET := 90

var _index := 0
var _frames := 0
var _level: Node
var _worst_draws := 0
var _worst_name := ""
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	# HERMETIC, or the numbers drift with whatever was last played. This reads
	# `user://save.cfg` through Level3D, which spawns one follower per banked
	# baby into every level: a dev machine with 1 banked baby measured the
	# tabletop 23 draws heavier than a clean one, and nobody could tell why the
	# budget moved. Zero here is the BASELINE; `baby_cost_test` covers the load.
	SaveGame.save_path = "user://test_perf_budget.cfg"
	SaveGame.clear()
	SaveGame.set_babies_banked(0)
	print("level                 draws  multi(inst)  lights  particles(max)  transp  nodes")
	print("-------------------------------------------------------------------------------")


func _tally(node: Node, out: Dictionary) -> void:
	out.nodes += 1
	if node is MultiMeshInstance3D:
		out.multi += 1
		var mm := (node as MultiMeshInstance3D).multimesh
		if mm:
			out.instances += mm.instance_count
	elif node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		out.draws += maxi(mesh_inst.mesh.get_surface_count() if mesh_inst.mesh else 0, 1)
		var mat := mesh_inst.mesh.surface_get_material(0) if mesh_inst.mesh \
			and mesh_inst.mesh.get_surface_count() > 0 else null
		if mat == null and mesh_inst.mesh is PrimitiveMesh:
			mat = (mesh_inst.mesh as PrimitiveMesh).material
		if mat is BaseMaterial3D \
				and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			out.transparent += 1
	elif node is Light3D:
		out.lights += 1
		if (node as Light3D).shadow_enabled:
			out.shadowed += 1
	elif node is CPUParticles3D:
		out.emitters += 1
		out.particles += (node as CPUParticles3D).amount
	for child in node.get_children():
		_tally(child, out)


func _process(_delta: float) -> bool:
	_frames += 1
	if _level == null:
		if _index >= LEVELS.size():
			_report()
			return true
		_level = (load("res://world/levels/%s.tscn" % LEVELS[_index]) as PackedScene).instantiate()
		root.add_child(_level)
		_frames = 0
		return false
	# Levels build their decor in _ready and some of it lands deferred.
	if _frames < 20:
		return false

	var out := {"draws": 0, "multi": 0, "instances": 0, "lights": 0, "shadowed": 0,
		"emitters": 0, "particles": 0, "transparent": 0, "nodes": 0}
	_tally(_level, out)
	var name: String = LEVELS[_index]
	print("%-20s %6d  %4d(%4d)  %6d  %6d(%5d)  %6d  %5d" % [
		name, out.draws, out.multi, out.instances, out.lights,
		out.emitters, out.particles, out.transparent, out.nodes])

	var span := _level_span(_level)
	var density: float = out.draws / maxf(span, 1.0)
	_check(density <= DRAWS_PER_METRE,
		"%s draw density %.2f/m <= %.2f  (%d draws over %.0f m)"
			% [name, density, DRAWS_PER_METRE, out.draws, span])
	_check(out.draws <= DRAW_CALL_CEILING,
		"%s total draws %d <= %d" % [name, out.draws, DRAW_CALL_CEILING])
	_check(out.lights <= LIGHT_BUDGET,
		"%s lights %d <= %d" % [name, out.lights, LIGHT_BUDGET])
	_check(out.shadowed == 0,
		"%s casts no shadows (%d shadowed lights)" % [name, out.shadowed])
	_check(out.transparent <= TRANSPARENT_BUDGET,
		"%s transparent surfaces %d <= %d" % [name, out.transparent, TRANSPARENT_BUDGET])
	if out.draws > _worst_draws:
		_worst_draws = out.draws
		_worst_name = name

	_level.free()
	_level = null
	_index += 1
	return false


func _report() -> void:
	print("-------------------------------------------------------------------------------")
	print("heaviest level: %s at %d draw calls (ceiling %d, density %.1f/m)"
		% [_worst_name, _worst_draws, DRAW_CALL_CEILING, DRAWS_PER_METRE])
	print("")
	print("-- shared texture cache")
	var styles := ["speckle", "grain", "checker", "brick", "asphalt", "concrete"]
	for style in styles:
		var tex := Block3D.surface_texture(style)
		var img := tex.get_image()
		print("  %-9s %dx%d  mipmaps=%s" % [style, img.get_width(), img.get_height(),
			img.has_mipmaps()])
	_check(true, "procedural textures are cached and shared across every surface")

	if _failures.is_empty():
		print("PERF BUDGET TEST PASS")
	else:
		print("PERF BUDGET TEST FAIL (%d): %s" % [_failures.size(), ", ".join(_failures)])
	quit(0 if _failures.is_empty() else 1)


## How wide the level is in X, from its collidable geometry. Decor is ignored on
## purpose: a backdrop or a water plane can be far wider than the playable run
## and would flatter the density.
func _level_span(level: Node) -> float:
	var low := INF
	var high := -INF
	for node in _all_nodes(level):
		if not (node is StaticBody3D or node is AnimatableBody3D):
			continue
		var x: float = (node as Node3D).global_position.x
		low = minf(low, x)
		high = maxf(high, x)
	if low == INF:
		return 1.0
	return maxf(high - low, 1.0)


func _all_nodes(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children():
		out.append_array(_all_nodes(child))
	return out
