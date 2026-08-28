extends SceneTree

## Hazards must never hurt what they don't show.
##
## The bug this guards against was real: the old puddle had a 1.1 x 0.5 x 1.0
## BoxShape3D offset +0.2 in Y behind a 0.09-tall disc of radius 0.55, so it
## damaged the player roughly 0.45 m above the acid and out to the box corners.
## Parity is checked DURING the spread animation too, because scaling a mesh
## while leaving the shape alone is the obvious way to reintroduce it.
##
## Run with:
##   godot --headless --path . --script tests/hazard_parity_test.gd

var _phase := 0
var _frames := 0
var _elapsed := 0.0
var _pool: HazardPool3D
var _level: Node
var _worst_overhang := 0.0
var _samples := 0
var _failures: Array[String] = []


func _check(passed: bool, label: String) -> void:
	print(("  ok   " if passed else "  FAIL ") + label)
	if not passed:
		_failures.append(label)


func _initialize() -> void:
	# HERMETIC: the player reads bought upgrades off the save on spawn now,
	# so a test without a scratch save measures whatever was last played.
	SaveGame.save_path = "user://test_hazard_parity_scratch.cfg"
	SaveGame.clear()
	print("-- pool geometry")
	_pool = HazardPool3D.new()
	_pool.lifetime = 1.0
	_pool.start_radius = 0.5
	_pool.max_radius = 0.9
	root.add_child(_pool)


## How far the hurtbox reaches beyond the visible goo. Must never exceed 0.
func _overhang() -> float:
	var visible_r: float = (_pool._disc_mesh as CylinderMesh).top_radius
	var collision_r: float = (_pool._cylinder as CylinderShape3D).radius
	return collision_r - visible_r


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	if _frames > 100000:
		print("HAZARD PARITY TEST FAIL: stalled in phase %d" % _phase)
		quit(1)
		return true

	# Sample parity on every single frame, spread animation included.
	if _pool != null and is_instance_valid(_pool):
		_samples += 1
		_worst_overhang = maxf(_worst_overhang, _overhang())

	match _phase:
		0:
			if _frames < 3:
				return false
			var mesh: CylinderMesh = _pool._disc_mesh
			var shape: CylinderShape3D = _pool._cylinder
			_check(is_equal_approx(shape.radius, mesh.top_radius),
				"collision radius equals the visible radius")
			_check(is_equal_approx(mesh.top_radius, mesh.bottom_radius),
				"the disc has no taper, so 'the radius' is unambiguous")
			_check(is_equal_approx(shape.height, mesh.height),
				"collision height equals the visible height")
			_check(is_equal_approx(_pool._shape.position.y, _pool._disc.position.y),
				"collision and visual sit at the same height off the floor")
			_check(mesh.height >= 0.2,
				"the pool is thick enough to touch Harry's 0.4-tall body box")
			_check(is_equal_approx(_pool._disc.scale.x, 1.0),
				"the disc is never scaled — radius is the only size control")
			_phase = 1
		1:
			print("-- growth")
			var before := _pool.radius
			_pool.feed()
			_pool.feed()
			_elapsed = 0.0
			_check(_pool.radius >= before, "feeding spreads the pool")
			_phase = 2
		2:
			if _elapsed < 0.5:
				return false
			_check(_pool.radius <= _pool.max_radius + 0.001,
				"growth stops at the cap (%.2f <= %.2f)" % [_pool.radius, _pool.max_radius])
			for i in 30:
				_pool.feed()
			_elapsed = 0.0
			_phase = 3
		3:
			if _elapsed < 0.5:
				return false
			_check(is_equal_approx(_pool.radius, _pool.max_radius),
				"a leak running forever cannot flood the level")
			_check(_worst_overhang <= 0.0001,
				"hurtbox NEVER exceeded the visible pool (worst %.4f over %d frames)"
					% [_worst_overhang, _samples])
			_elapsed = 0.0
			_phase = 4
		4:
			# Left unfed, it should shrink away and free itself.
			if _elapsed < 3.0:
				return false
			_check(not is_instance_valid(_pool), "an unfed pool fades and frees itself")
			_pool = null
			print("-- both hazards share the one implementation")
			_level = (load("res://world/levels/drain_level.tscn") as PackedScene).instantiate()
			root.add_child(_level)
			_phase = 5
		5:
			if _frames < 400:
				return false
			var emitter: DripEmitter3D = null
			for child in _level.get_children():
				if child is DripEmitter3D:
					emitter = child
					break
			_check(emitter != null, "the drain still has its drip emitters")
			if emitter:
				var at := emitter.global_position - Vector3(0, 6, 0)
				emitter._spawn_puddle(at)
				var made := _count_pools(emitter)
				_check(made == 1, "a landing drop makes one pool")
				emitter._spawn_puddle(at)
				_check(_count_pools(emitter) == 1,
					"a second drop in the same spot feeds that pool, not a new one")
				emitter._spawn_puddle(at + Vector3(4.0, 0, 0))
				_check(_count_pools(emitter) == 2, "a drop landing elsewhere makes its own")
			_check(GrannyHazard.new().get_script() != null, "GrannyHazard still loads")
			_phase = 6
		6:
			if _failures.is_empty():
				print("HAZARD PARITY TEST PASS")
			else:
				print("HAZARD PARITY TEST FAIL (%d): %s"
					% [_failures.size(), ", ".join(_failures)])
			quit(0 if _failures.is_empty() else 1)
	return false


func _count_pools(node: Node) -> int:
	var n := 0
	for child in node.get_children():
		if child is HazardPool3D:
			n += 1
	return n
