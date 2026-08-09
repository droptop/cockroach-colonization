class_name Fx
extends Object

## Shared one-shot combat/juice effects: comic impact text, spark bursts,
## floating death ghosts. All spawn, animate, and free themselves.

const IMPACT_WORDS := ["POW!", "CRACK!", "BONK!", "SPLAT!", "WHAM!"]


static func impact_text(parent: Node, pos: Vector3, color := Color(1.0, 0.9, 0.3)) -> void:
	var label := Label3D.new()
	label.text = IMPACT_WORDS[randi() % IMPACT_WORDS.size()]
	label.font_size = 96
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.outline_size = 22
	label.no_depth_test = true
	parent.add_child(label)
	label.global_position = pos + Vector3(randf_range(-0.2, 0.2), 0.5, 0.5)
	label.scale = Vector3.ONE * 0.2
	label.rotation.z = randf_range(-0.18, 0.18)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE * 1.25, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3.ONE, 0.06)
	tween.tween_interval(0.18)
	tween.tween_property(label, "modulate:a", 0.0, 0.22)
	tween.parallel().tween_property(label, "position:y", label.position.y + 0.7, 0.22)
	tween.tween_callback(label.queue_free)


static func spark_burst(parent: Node, pos: Vector3, color := Color(1.0, 0.95, 0.6)) -> void:
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 10
	sparks.lifetime = 0.35
	sparks.spread = 180.0
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 4.5
	sparks.gravity = Vector3(0, -8, 0)
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.045
	mesh.height = 0.09
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mesh.material = mat
	sparks.mesh = mesh
	parent.add_child(sparks)
	sparks.global_position = pos
	sparks.emitting = true
	var tween := sparks.create_tween()
	tween.tween_interval(0.8)
	tween.tween_callback(sparks.queue_free)


## Little white spirit that twirls up out of a defeated creature and fades.
static func ghost(parent: Node, pos: Vector3, size := 1.0) -> void:
	var spirit := Node3D.new()
	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.28 * size
	body_mesh.height = 0.62 * size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.95, 1.0)
	mat.emission_energy_multiplier = 0.6
	body_mesh.material = mat
	body.mesh = body_mesh
	spirit.add_child(body)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.05, 0.05, 0.1, 0.85)
	eye_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.05 * size
		eye_mesh.height = 0.12 * size
		eye_mesh.material = eye_mat
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.09 * size, 0.08 * size, 0.22 * size)
		spirit.add_child(eye)
	parent.add_child(spirit)
	spirit.global_position = pos + Vector3(0, 0.2, 0)
	var tween := spirit.create_tween()
	tween.tween_property(spirit, "position:y", spirit.position.y + 2.4, 1.3).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(spirit, "rotation:y", TAU * 1.5, 1.3)
	tween.parallel().tween_property(spirit, "scale", Vector3.ONE * 0.1, 1.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(spirit.queue_free)
