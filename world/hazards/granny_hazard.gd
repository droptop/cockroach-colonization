class_name GrannyHazard
extends Node3D

## "GRANNY IS COMING." Not a boss — an unpredictable environmental
## catastrophe (GAME.md §11). On a random interval, telegraphs and then
## fires one of two attacks at the player's current position: a fly-swatter
## slam, or a lingering insecticide cloud. Same spirit as DripEmitter3D —
## pure script, no .tscn, added via Level3D.decor_granny_hazard().

@export var min_interval := 8.0
@export var max_interval := 14.0
@export var telegraph_time := 1.3
@export var swatter_damage := 3
@export var swatter_radius := 1.3
@export var spray_damage := 1
@export var spray_duration := 6.0
@export var spray_tick := 1.0
@export var spray_radius := 1.6
@export var spray_slow_factor := 0.5

## Set by Level3D.decor_granny_hazard() right after construction.
var hud: CanvasLayer
var player: Player3D

var _timer := 0.0
var _clouds: Array[Dictionary] = []


func _ready() -> void:
	_timer = randf_range(min_interval, max_interval)


func _physics_process(delta: float) -> void:
	_update_clouds(delta)
	if player == null or not is_instance_valid(player) or player.is_dead:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(min_interval, max_interval)
		if randf() < 0.5:
			_start_swatter()
		else:
			_start_spray()


func _start_swatter() -> void:
	var target := player.global_position
	if hud:
		hud.show_message("GRANNY IS COMING!", telegraph_time)
	var shadow := MeshInstance3D.new()
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.1
	shadow_mesh.bottom_radius = 0.1
	shadow_mesh.height = 0.05
	shadow_mesh.radial_segments = 16
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0, 0, 0, 0.55)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mesh.material = shadow_mat
	shadow.mesh = shadow_mesh
	shadow.rotation.x = PI / 2
	add_child(shadow)
	shadow.global_position = target + Vector3(0, 0.05, 0)
	var tween := shadow.create_tween()
	tween.tween_property(shadow, "scale", Vector3.ONE * (swatter_radius / 0.1), telegraph_time)
	await get_tree().create_timer(telegraph_time).timeout
	shadow.queue_free()
	_slam(target)


func _slam(target: Vector3) -> void:
	var swatter := MeshInstance3D.new()
	var paddle := BoxMesh.new()
	paddle.size = Vector3(1.0, 0.08, 1.0)
	var mat := Block3D.flat_material(Color(0.85, 0.3, 0.25))
	paddle.material = mat
	swatter.mesh = paddle
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.05
	handle_mesh.bottom_radius = 0.05
	handle_mesh.height = 2.0
	handle_mesh.material = Block3D.flat_material(Color(0.6, 0.55, 0.5))
	handle.mesh = handle_mesh
	handle.position = Vector3(0, 1.0, 0)
	swatter.add_child(handle)
	add_child(swatter)
	swatter.global_position = target + Vector3(0, 9.0, 0)
	var tween := swatter.create_tween()
	tween.tween_property(swatter, "global_position", target, 0.1).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if is_instance_valid(player) and not player.is_dead \
				and player.global_position.distance_to(target) < swatter_radius:
			player.take_damage(swatter_damage, target)
		Fx.spark_burst(get_parent(), target + Vector3(0, 0.3, 0))
		Snd.sfx("thud", 4.0)
		var cam := player.get_node_or_null("Camera3D") if is_instance_valid(player) else null
		if cam and cam.has_method("shake"):
			cam.shake(0.5)
	)
	tween.tween_interval(0.35)
	tween.tween_callback(swatter.queue_free)


func _start_spray() -> void:
	var target := player.global_position
	if hud:
		hud.show_message("Insecticide!", telegraph_time * 0.6)
	await get_tree().create_timer(telegraph_time * 0.6).timeout
	Snd.sfx("sizzle", -3.0)
	var area := Area3D.new()
	area.collision_layer = 8
	area.collision_mask = 2
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = spray_radius
	cyl.height = 2.2
	shape.shape = cyl
	area.add_child(shape)
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(0.4, 0.85, 0.25, 0.5)
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var cloud_mesh := SphereMesh.new()
	cloud_mesh.radius = 0.14
	cloud_mesh.height = 0.28
	cloud_mesh.radial_segments = 6
	cloud_mesh.rings = 3
	cloud_mesh.material = cloud_mat
	var particles := CPUParticles3D.new()
	particles.amount = 26
	particles.lifetime = 1.6
	particles.preprocess = 1.6
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = spray_radius
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 180.0
	particles.initial_velocity_min = 0.1
	particles.initial_velocity_max = 0.4
	particles.gravity = Vector3(0, 0.15, 0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.3
	particles.mesh = cloud_mesh
	area.add_child(particles)
	add_child(area)
	area.global_position = target
	_clouds.append({"area": area, "particles": particles, "life": spray_duration, "tick": 0.0})


func _update_clouds(delta: float) -> void:
	for i in range(_clouds.size() - 1, -1, -1):
		var cloud: Dictionary = _clouds[i]
		var area: Area3D = cloud.area
		if not is_instance_valid(area):
			_clouds.remove_at(i)
			continue
		cloud.life -= delta
		cloud.tick -= delta
		var tick_now: bool = cloud.tick <= 0.0
		if tick_now:
			cloud.tick = spray_tick
		for body in area.get_overlapping_bodies():
			if body.has_method("apply_slow"):
				body.apply_slow(spray_slow_factor)
			if tick_now and body.has_method("take_damage"):
				body.take_damage(spray_damage, area.global_position)
		if cloud.life <= 0.0:
			var particles: CPUParticles3D = cloud.particles
			if is_instance_valid(particles):
				particles.emitting = false
			var tween := area.create_tween()
			tween.tween_property(area, "scale", Vector3(0.05, 0.05, 0.05), 0.4)
			tween.tween_callback(area.queue_free)
			_clouds.remove_at(i)
