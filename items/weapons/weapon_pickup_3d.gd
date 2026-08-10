extends Area3D

## A weapon lying around a level (rusty pin in the drain, fork/knife in the
## kitchen). Bobs and spins like food, but is a one-time pickup — no respawn,
## it joins the player's weapon cycle for good (well, until they die).

@export var weapon_id := "pin"

var _time := 0.0
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)
	match weapon_id:
		"fork":
			_build_fork()
		"knife":
			_build_knife()
		_:
			_build_pin()


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 2.6) * 0.07
	rotation.y += delta * 1.0


func _build_pin() -> void:
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.02
	shaft_mesh.bottom_radius = 0.035
	shaft_mesh.height = 0.5
	shaft_mesh.material = Block3D.flat_material(Color(0.55, 0.35, 0.22))
	shaft.mesh = shaft_mesh
	shaft.rotation.z = 0.45
	add_child(shaft)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.07
	head_mesh.height = 0.14
	head_mesh.material = Block3D.flat_material(Color(0.7, 0.45, 0.3))
	head.mesh = head_mesh
	head.position = Vector3(-0.2, 0.22, 0)
	add_child(head)


func _build_fork() -> void:
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.36, 0.06, 0.06)
	handle_mesh.material = Block3D.flat_material(Color(0.8, 0.82, 0.86))
	handle.mesh = handle_mesh
	add_child(handle)
	for offset in [-0.09, 0.0, 0.09]:
		var tine := MeshInstance3D.new()
		var tine_mesh := BoxMesh.new()
		tine_mesh.size = Vector3(0.18, 0.03, 0.03)
		tine_mesh.material = Block3D.flat_material(Color(0.85, 0.87, 0.9))
		tine.mesh = tine_mesh
		tine.position = Vector3(0.26, 0.0, offset)
		add_child(tine)


func _build_knife() -> void:
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.18, 0.06, 0.07)
	handle_mesh.material = Block3D.flat_material(Color(0.4, 0.28, 0.18))
	handle.mesh = handle_mesh
	handle.position = Vector3(-0.16, 0, 0)
	add_child(handle)
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.32, 0.09, 0.02)
	blade_mesh.material = Block3D.flat_material(Color(0.85, 0.87, 0.9))
	blade.mesh = blade_mesh
	blade.position = Vector3(0.1, 0, 0)
	add_child(blade)


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("collect_weapon"):
		return
	body.collect_weapon(weapon_id)
	Snd.sfx("crumb")
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.6, 0.12)
	tween.parallel().tween_property(self, "position:y", position.y + 0.3, 0.12)
	tween.tween_callback(queue_free)
