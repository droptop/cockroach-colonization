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


func _ready() -> void:
	_timer = randf_range(min_interval, max_interval)


func _physics_process(delta: float) -> void:
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
		Snd.sfx("impact_heavy", 4.0)
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
	# Same volume the acid puddles use. The cloud is deliberately a visible
	# body rather than particles alone: whatever it can hurt, it has to show.
	var cloud := HazardPool3D.new()
	cloud.damage = spray_damage
	cloud.tick_interval = spray_tick
	cloud.lifetime = spray_duration
	cloud.slow_factor = spray_slow_factor
	cloud.start_radius = spray_radius
	cloud.max_radius = spray_radius
	cloud.growth_per_feed = 0.0
	cloud.pool_height = 2.2
	cloud.color = Color(0.4, 0.85, 0.25, 0.28)
	cloud.particle_count = 26
	add_child(cloud)
	cloud.global_position = target
