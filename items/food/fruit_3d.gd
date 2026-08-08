extends Area3D

## A juicy berry — the premium wing fuel. Restores a big chunk of the wing
## dial and counts as food.

@export var food_value := 1
@export var wing_energy_value := 45.0
@export var fruit_color := Color(0.85, 0.2, 0.25)

var _time := 0.0
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)
	var berry := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.24
	mesh.height = 0.44
	mesh.material = Block3D.flat_material(fruit_color)
	berry.mesh = mesh
	add_child(berry)
	var shine := MeshInstance3D.new()
	var shine_mesh := SphereMesh.new()
	shine_mesh.radius = 0.07
	shine_mesh.height = 0.14
	shine_mesh.material = Block3D.flat_material(fruit_color.lightened(0.45))
	shine.mesh = shine_mesh
	shine.position = Vector3(-0.09, 0.12, 0.12)
	add_child(shine)
	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.02
	stem_mesh.bottom_radius = 0.03
	stem_mesh.height = 0.14
	stem_mesh.material = Block3D.flat_material(Color(0.35, 0.5, 0.25))
	stem.mesh = stem_mesh
	stem.position = Vector3(0, 0.26, 0)
	stem.rotation.z = 0.3
	add_child(stem)
	var leaf := MeshInstance3D.new()
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = 0.09
	leaf_mesh.height = 0.18
	leaf_mesh.material = Block3D.flat_material(Color(0.4, 0.62, 0.3))
	leaf.mesh = leaf_mesh
	leaf.position = Vector3(0.08, 0.28, 0)
	leaf.scale = Vector3(1.4, 0.3, 0.8)
	add_child(leaf)


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 2.2) * 0.09
	rotation.y += delta * 0.9


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("collect_food"):
		return
	body.collect_food(food_value)
	if body.has_method("add_wing_energy"):
		body.add_wing_energy(wing_energy_value)
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.9, 0.14)
	tween.parallel().tween_property(self, "position:y", position.y + 0.4, 0.14)
	tween.tween_callback(queue_free)
