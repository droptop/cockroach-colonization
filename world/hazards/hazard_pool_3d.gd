class_name HazardPool3D
extends Area3D

## A pool of something that hurts: acid dripping off a pipe, or Granny's
## insecticide settling where she sprayed it. ONE implementation for both —
## two near-identical hazards maintained side by side is exactly how a visible
## puddle and its hurtbox drift apart.
##
## The rule this class exists to enforce: the collision cylinder's radius and
## height are DERIVED from the visible mesh, in one function, every time either
## changes — including mid-animation. Nothing may be hurt by acid it cannot see.
## That is why spreading and fading are tweened through `_set_radius` rather
## than by scaling the MeshInstance, which would shrink the visual while leaving
## the hurtbox at full size.

@export var damage := 1
@export var tick_interval := 0.35
@export var start_radius := 0.42
@export var max_radius := 1.15
## Radius added each time another drop lands in this pool.
@export var growth_per_feed := 0.15
## Seconds the pool survives after it was last fed.
@export var lifetime := 5.0
## Thickness of the goo. Harry's body box is only 0.4 tall sitting on the
## floor, so a pool needs real height or he wades through it untouched — and
## that height has to be visible, not hidden in the collision shape.
@export var pool_height := 0.22
@export var color := Color(0.5, 0.95, 0.4)
## 0 disables. Insecticide slows whatever stands in it; acid does not.
@export var slow_factor := 0.0
@export var particle_count := 10

var radius := 0.42

## Where the radius is HEADED, which is not where it is. Feeds accumulate
## against this rather than against the live radius — otherwise several drops
## landing before the previous spread finished all retarget from the same
## value and collapse into a single increment.
var _target_radius := 0.42

var _life := 0.0
var _tick := 0.0
var _dying := false
var _shape: CollisionShape3D
var _cylinder: CylinderShape3D
var _disc: MeshInstance3D
var _disc_mesh: CylinderMesh
var _particles: CPUParticles3D
var _grow_tween: Tween


func _ready() -> void:
	collision_layer = 8 # hazard
	collision_mask = 2 # player
	monitorable = false
	_life = lifetime

	_cylinder = CylinderShape3D.new()
	_shape = CollisionShape3D.new()
	_shape.shape = _cylinder
	add_child(_shape)

	_disc_mesh = CylinderMesh.new()
	_disc_mesh.radial_segments = 14
	var mat := Block3D.flat_material(color)
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 1.6
	if color.a < 0.999:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc_mesh.material = mat
	_disc = MeshInstance3D.new()
	_disc.mesh = _disc_mesh
	add_child(_disc)

	if particle_count > 0:
		_build_particles()

	# Spread in from small, with collision following every step of the way.
	_set_radius(start_radius * 0.4)
	_grow_to(start_radius, 0.22)


## The single place radius is applied. Visual and hurtbox are set from the same
## number in the same call so they cannot disagree, ever.
func _set_radius(r: float) -> void:
	radius = clampf(r, 0.01, max_radius)
	_cylinder.radius = radius
	_cylinder.height = pool_height
	_shape.position.y = pool_height * 0.5
	_disc_mesh.top_radius = radius
	_disc_mesh.bottom_radius = radius
	_disc_mesh.height = pool_height
	_disc.position.y = pool_height * 0.5
	if _particles:
		_particles.emission_sphere_radius = radius


func _grow_to(target: float, duration: float) -> void:
	_target_radius = clampf(target, 0.01, max_radius)
	if _grow_tween:
		_grow_tween.kill()
	_grow_tween = create_tween()
	_grow_tween.tween_method(_set_radius, radius, _target_radius, duration)


## Another drop landed in this pool: it spreads a little and its clock resets.
## Capped, so a leak running forever cannot flood the level.
func feed() -> void:
	if _dying:
		return
	_life = lifetime
	if _target_radius < max_radius:
		_grow_to(_target_radius + growth_per_feed, 0.18)


func _physics_process(delta: float) -> void:
	if _dying:
		return
	_life -= delta
	_tick -= delta
	var tick_now := _tick <= 0.0
	if tick_now:
		_tick = tick_interval
	for body in get_overlapping_bodies():
		if slow_factor > 0.0 and body.has_method("apply_slow"):
			body.apply_slow(slow_factor)
		if tick_now and body.has_method("take_damage"):
			body.take_damage(damage, global_position)
	if _life <= 0.0:
		_begin_fade()


## Source stopped: shrink away. Still hurts while it is still visible, because
## the two are the same number.
func _begin_fade() -> void:
	_dying = true
	if _particles:
		_particles.emitting = false
	if _grow_tween:
		_grow_tween.kill()
	_target_radius = 0.02
	var fade := create_tween()
	fade.tween_method(_set_radius, radius, 0.02, 0.4)
	fade.tween_callback(queue_free)


func _build_particles() -> void:
	_particles = CPUParticles3D.new()
	_particles.amount = particle_count
	_particles.lifetime = 1.3
	_particles.preprocess = 1.3
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = radius
	_particles.direction = Vector3(0, 1, 0)
	_particles.spread = 18.0
	_particles.initial_velocity_min = 0.5
	_particles.initial_velocity_max = 1.0
	_particles.gravity = Vector3(0, 0.4, 0)
	_particles.scale_amount_min = 0.5
	_particles.scale_amount_max = 1.2
	var mesh := SphereMesh.new()
	mesh.radius = 0.09
	mesh.height = 0.18
	mesh.radial_segments = 6
	mesh.rings = 3
	# Decorative only — particles never carry collision, so nothing can be hurt
	# by a wisp that drifted outside the pool.
	mesh.material = Block3D.flat_material(Color(
		color.r * 0.5 + 0.25, color.g * 0.5 + 0.25, color.b * 0.5 + 0.25, 0.4))
	_particles.mesh = mesh
	_particles.position = Vector3(0, pool_height * 0.6, 0)
	add_child(_particles)
