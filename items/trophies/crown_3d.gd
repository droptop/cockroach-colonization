extends Area3D

## Dropped by the rat boss on defeat. Picking it up crowns Harry with the
## "THE KING OF COCKROACHES" achievement. Same gold/ruby palette as the
## rat's own crown (rat_visual_3d.gd) so the drop reads as *his* crown.

var _time := 0.0
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)
	var gold := Block3D.flat_material(Color(0.95, 0.78, 0.25))
	gold.metallic = 0.6
	gold.roughness = 0.35
	gold.emission_enabled = true
	gold.emission = Color(0.9, 0.7, 0.2)
	gold.emission_energy_multiplier = 0.5
	var band := MeshInstance3D.new()
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.24
	band_mesh.bottom_radius = 0.28
	band_mesh.height = 0.18
	band_mesh.radial_segments = 12
	band_mesh.material = gold
	band.mesh = band_mesh
	add_child(band)
	for k in 5:
		var spike := MeshInstance3D.new()
		var spike_mesh := CylinderMesh.new()
		spike_mesh.top_radius = 0.008
		spike_mesh.bottom_radius = 0.05
		spike_mesh.height = 0.16
		spike_mesh.material = gold
		spike.mesh = spike_mesh
		spike.position = Vector3((k - 2) * 0.12, 0.15, 0)
		add_child(spike)
	var jewel_mat := Block3D.flat_material(Color(0.85, 0.15, 0.2))
	jewel_mat.emission_enabled = true
	jewel_mat.emission = Color(0.85, 0.15, 0.2)
	jewel_mat.emission_energy_multiplier = 0.9
	var jewel := MeshInstance3D.new()
	var jewel_mesh := SphereMesh.new()
	jewel_mesh.radius = 0.06
	jewel_mesh.height = 0.12
	jewel_mesh.material = jewel_mat
	jewel.mesh = jewel_mesh
	jewel.position = Vector3(0, 0.02, 0.24)
	add_child(jewel)


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 2.2) * 0.09
	rotation.y += delta * 1.3


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	GameManager.unlock_achievement("king_of_cockroaches", "THE KING OF COCKROACHES")
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.8, 0.18)
	tween.parallel().tween_property(self, "position:y", position.y + 0.5, 0.18)
	tween.tween_callback(queue_free)
