class_name DrainFlush3D
extends Node3D

## Somebody upstairs empties a bucket down the drain.
##
## A slug of water drops out of the grate, hits whatever is below it, then runs
## along that surface until it runs out of floor and drops again — down and down
## until it reaches the standing water at the bottom of the chamber. Anything it
## catches gets shoved along with it, which over an open chamber usually means
## into the water, and the water is the DeathZone.
##
## It does no damage at all. Being washed off the ledge is the threat, and a
## hazard that also chipped health would make that read as unfair rather than
## as bad luck about where you were standing.
##
## Fair warning first, always: the grate rattles and drips for `warning_time`
## before anything falls, on the same principle as the acid drip's hang. An
## unsignalled shove that kills is a cheat.

@export var interval := 11.0
@export var interval_jitter := 5.0
@export var warning_time := 1.3
@export var fall_speed := 13.0
@export var run_speed := 9.0
## How far it will run along one surface before it gives up and soaks away.
@export var run_distance := 22.0
@export var width := 1.1
## How hard it throws what it catches.
@export var shove := 11.0
@export var shove_lift := 3.4
## Below this it has reached the bottom and is done.
@export var kill_y := -6.0
@export var water_color := Color(0.55, 0.85, 1.0, 0.62)

var _timer := 0.0
var _warned := false
var _grate: MeshInstance3D


func _ready() -> void:
	_timer = randf_range(interval * 0.4, interval)
	_build_grate()


## The mouth it comes out of, so the warning has something to happen ON.
func _build_grate() -> void:
	_grate = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width * 1.8, 0.22, 1.6)
	var mat := Block3D.flat_material(Color(0.3, 0.34, 0.36))
	mesh.material = mat
	_grate.mesh = mesh
	add_child(_grate)


func _process(delta: float) -> void:
	_timer -= delta
	if not _warned and _timer <= warning_time:
		_warned = true
		_warn()
	if _timer <= 0.0:
		_timer = interval + randf_range(0.0, interval_jitter)
		_warned = false
		_release()


func _warn() -> void:
	# A metallic tick on the grate, quiet, a beat before it lets go.
	Snd.sfx("impact_light", -14.0, 0.4)
	Fx.spark_burst(get_parent(), global_position + Vector3(0, -0.4, 0),
		Color(0.6, 0.85, 1.0))
	if _grate:
		var tween := create_tween()
		tween.set_loops(3)
		tween.tween_property(_grate, "position:y", 0.06, 0.12)
		tween.tween_property(_grate, "position:y", 0.0, 0.12)


func _release() -> void:
	var flush := FlushHead.new()
	flush.setup(self)
	get_parent().add_child(flush)
	flush.global_position = global_position + Vector3(0, -0.4, 0)
	Snd.sfx("water_splash", 0.0, 0.15)


## The slug itself. An inner class because nothing else ever needs one, and it
## has to reach back to the emitter for its tuning.
class FlushHead:
	extends Area3D

	var fall_speed := 13.0
	var run_speed := 9.0
	var run_distance := 22.0
	var width := 1.1
	var shove := 11.0
	var shove_lift := 3.4
	var kill_y := -6.0
	var water_color := Color(0.55, 0.85, 1.0, 0.62)

	## World geometry only: it runs on the level, not on Harry or an enemy.
	## Declared HERE because an inner class does not see the outer class's
	## constants in GDScript.
	const WORLD_LAYER := 1

	var _dir := 0.0
	var _run_left := 0.0
	var _trail: Array[MeshInstance3D] = []
	var _body: MeshInstance3D

	func setup(from: DrainFlush3D) -> void:
		fall_speed = from.fall_speed
		run_speed = from.run_speed
		run_distance = from.run_distance
		width = from.width
		shove = from.shove
		shove_lift = from.shove_lift
		kill_y = from.kill_y
		water_color = from.water_color

	func _ready() -> void:
		collision_layer = 8 # hazard
		collision_mask = 2 | 4 # player and enemies both get washed
		monitorable = false
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width, width * 1.4, 1.6)
		shape.shape = box
		add_child(shape)

		var mat := Block3D.flat_material(water_color)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.5, 0.8, 1.0)
		mat.emission_energy_multiplier = 0.5
		_body = MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width, width * 1.5, 1.5)
		mesh.material = mat
		_body.mesh = mesh
		add_child(_body)
		# The tail, dragging behind: this is what makes it read as a run of
		# water rather than a floating cube.
		for i in 4:
			var seg := MeshInstance3D.new()
			var seg_mesh := BoxMesh.new()
			var k := 1.0 - float(i) * 0.2
			seg_mesh.size = Vector3(width * k, width * 1.2 * k, 1.3 * k)
			seg_mesh.material = mat
			seg.mesh = seg_mesh
			add_child(seg)
			_trail.append(seg)

	## Is there floor directly under `at`, within `reach`?
	func _floor_under(at: Vector3, reach: float) -> Dictionary:
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
			at, at + Vector3(0, -reach, 0), WORLD_LAYER)
		return space.intersect_ray(query)

	func _physics_process(delta: float) -> void:
		if global_position.y < kill_y:
			Fx.spark_burst(get_parent(), global_position, Color(0.6, 0.9, 1.0))
			queue_free()
			return

		if _dir == 0.0:
			# Falling. Look a step ahead so it lands ON the surface rather than
			# inside it.
			var step := fall_speed * delta
			var hit := _floor_under(global_position, step + width)
			if hit.is_empty():
				global_position.y -= step
			else:
				global_position.y = (hit.position as Vector3).y + width * 0.7
				# Left or right, chosen by where there is more room to run.
				_dir = -1.0 if randf() < 0.5 else 1.0
				_run_left = run_distance
				Snd.sfx("water_splash", -6.0, 0.2)
				Fx.spark_burst(get_parent(), global_position, Color(0.65, 0.9, 1.0))
		else:
			# Running along the surface until the floor runs out under its nose.
			var step := run_speed * delta
			global_position.x += _dir * step
			_run_left -= step
			var nose := global_position + Vector3(_dir * width * 0.6, 0.2, 0)
			if _floor_under(nose, width * 1.6).is_empty():
				_dir = 0.0 # over the edge, and down again
			elif _run_left <= 0.0:
				queue_free()
				return

		_drag_trail(delta)
		_wash()

	## Segments chase the head, each lagging a little more than the last.
	func _drag_trail(delta: float) -> void:
		var ahead := global_position
		for i in _trail.size():
			var seg := _trail[i]
			var lag: float = 1.0 - exp(-delta * (26.0 - float(i) * 4.0))
			seg.global_position = seg.global_position.lerp(ahead, lag)
			ahead = seg.global_position

	## Everything it catches goes with it.
	func _wash() -> void:
		for body in get_overlapping_bodies():
			if not (body is CharacterBody3D):
				continue
			var victim := body as CharacterBody3D
			var push := _dir if _dir != 0.0 else signf(
				victim.global_position.x - global_position.x)
			if push == 0.0:
				push = 1.0
			victim.velocity.x = push * shove
			victim.velocity.y = maxf(victim.velocity.y, shove_lift)
			if victim.has_method("apply_slow"):
				victim.apply_slow(0.45)
