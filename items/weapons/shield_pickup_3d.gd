extends Area3D

## The bottle cap: found in the street level, worn on the head afterward.
## One-time pickup like the weapons, not a respawning food source.

var _time := 0.0
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.22
	cap_mesh.bottom_radius = 0.22
	cap_mesh.height = 0.08
	cap_mesh.radial_segments = 14
	cap_mesh.material = Block3D.flat_material(Color(0.75, 0.15, 0.15))
	cap.mesh = cap_mesh
	add_child(cap)
	var rim := MeshInstance3D.new()
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = 0.15
	rim_mesh.bottom_radius = 0.15
	rim_mesh.height = 0.09
	rim_mesh.radial_segments = 14
	rim_mesh.material = Block3D.flat_material(Color(0.92, 0.85, 0.7))
	rim.mesh = rim_mesh
	add_child(rim)


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 2.6) * 0.07
	rotation.y += delta * 1.0


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("collect_shield"):
		return
	body.collect_shield()
	Snd.sfx("crumb")
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.6, 0.12)
	tween.parallel().tween_property(self, "position:y", position.y + 0.3, 0.12)
	tween.tween_callback(queue_free)
