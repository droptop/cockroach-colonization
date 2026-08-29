class_name Wind3D
extends Node3D

## THE WIND (BACKLOG item 40): the roof's antagonist. Level-scoped like
## GrannyHazard, never a boss — it cannot be beaten, only read.
##
## It breathes in a cycle: CALM, a RISING telegraph (streaks, a lean in the
## air, a low rush of sound), then the GUST — a horizontal shove that is
## strongest mid-air, which is exactly where a roof's gaps want you. Standing
## in the LEE of a chimney (solid geometry between you and the weather)
## shelters you completely: the roof teaches cover the way the drain taught
## climbing.
##
## Deterministic: gust directions come from a seeded pattern, so a run's wind
## is the same every time and the walker's verdicts are repeatable. The push
## reaches the player through the same per-frame duck-typed contract as
## `apply_slow`: `apply_wind(force)` must be re-applied every physics frame
## or it stops, so a freed or broken wind system fails SAFE, to still air.

enum Phase { CALM, RISING, GUST }

@export var calm_time_min := 4.5
@export var calm_time_max := 7.5
@export var rising_time := 1.2
@export var gust_time := 2.4
## Horizontal acceleration while airborne; grounded traction resists most of
## it (the player-side contract applies the difference).
@export var gust_force := 7.0
## How close upwind geometry must be to count as shelter.
@export var shelter_range := 3.5
@export var pattern_seed := 11

var phase := Phase.CALM
var direction := 1.0

var _timer := 2.5
var _rng := RandomNumberGenerator.new()
var _player: Node3D
var _streaks: CPUParticles3D
var _told := false


func _ready() -> void:
	_rng.seed = pattern_seed
	_streaks = CPUParticles3D.new()
	_streaks.amount = 40
	_streaks.lifetime = 1.1
	_streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_streaks.emission_box_extents = Vector3(30.0, 6.0, 2.0)
	_streaks.direction = Vector3(1, -0.05, 0)
	_streaks.spread = 4.0
	_streaks.initial_velocity_min = 16.0
	_streaks.initial_velocity_max = 24.0
	_streaks.gravity = Vector3.ZERO
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.9, 0.03, 0.03)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.88, 0.95, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	_streaks.mesh = mesh
	_streaks.emitting = false
	_streaks.position = Vector3(0, 4.0, 0)
	add_child(_streaks)


func _physics_process(delta: float) -> void:
	_timer -= delta
	match phase:
		Phase.CALM:
			if _timer <= 0.0:
				phase = Phase.RISING
				_timer = rising_time
				direction = 1.0 if _rng.randf() < 0.5 else -1.0
				_streaks.direction = Vector3(direction, -0.05, 0)
				_streaks.emitting = true
				Snd.sfx("whoosh", -8.0, 0.1)
		Phase.RISING:
			if _timer <= 0.0:
				phase = Phase.GUST
				_timer = gust_time
				Snd.sfx("whoosh", 0.0, 0.05)
				if not _told and _acquire_player():
					_told = true
					Fx.impact_text(get_parent(),
						_player.global_position + Vector3(0, 1.4, 0),
						Color(0.85, 0.9, 1.0), "THE WIND!", 0.9)
		Phase.GUST:
			if _timer <= 0.0:
				phase = Phase.CALM
				_timer = _rng.randf_range(calm_time_min, calm_time_max)
				_streaks.emitting = false
			elif _acquire_player() and not _sheltered():
				_player.apply_wind(direction * gust_force)


func _acquire_player() -> bool:
	if not is_instance_valid(_player):
		_player = null
		for node in get_tree().get_nodes_in_group("player"):
			_player = node
			break
	return _player != null


## Anything solid within reach on the UPWIND side is a windbreak. One ray at
## chest height: a chimney qualifies, a ridge tile behind him does not.
func _sheltered() -> bool:
	var from: Vector3 = _player.global_position + Vector3(0, 0.5, 0)
	var to := from + Vector3(-direction * shelter_range, 0.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [_player.get_rid()]
	return not _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
