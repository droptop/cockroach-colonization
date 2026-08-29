extends Area3D

## 3D crumb: a dropped ICE CREAM CONE that bobs and spins slowly. Still called
## a crumb everywhere because it is the common small pickup, and every level
## scene instances it by that name.

@export var value := 1
## The wafer.
@export var crumb_color := Color(0.85, 0.68, 0.4)
## The scoops on top of it.
@export var scoop_color := Color(0.97, 0.72, 0.76)
## Eaten food grows back so the player can always refuel. 0 = never.
@export var respawn_seconds := 12.0

var _time := 0.0
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU # desync bobbing between crumbs
	body_entered.connect(_on_body_entered)
	# A dropped ICE CREAM CONE. It replaced a sheaf of wheat, which nobody was
	# reading as wheat.
	#
	# TWO draw calls, the same as everything this has been before. The crumb is
	# the pickup that appears most often in the game and there are enough of
	# them in a level that perf_budget_test failed on the tabletop the last time
	# this was built the obvious way. So: one cone, and BOTH scoops in a single
	# MultiMesh rather than a mesh each.
	var cone := MeshInstance3D.new()
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.11
	cone_mesh.bottom_radius = 0.0 # a cone is a cylinder that gives up
	cone_mesh.height = 0.3
	cone_mesh.radial_segments = 8
	# Checker at this density is the waffle pressing on the wafer.
	cone_mesh.material = Block3D.textured_material(crumb_color, "checker", 7.0)
	cone.mesh = cone_mesh
	cone.position = Vector3(0, -0.03, 0)
	add_child(cone)

	var scoop_mesh := SphereMesh.new()
	scoop_mesh.radius = 0.125
	scoop_mesh.height = 0.25
	scoop_mesh.radial_segments = 8
	scoop_mesh.rings = 5
	scoop_mesh.material = Block3D.flat_material(scoop_color)
	var scoops := MultiMesh.new()
	scoops.transform_format = MultiMesh.TRANSFORM_3D
	scoops.mesh = scoop_mesh
	scoops.instance_count = 2
	# Bottom scoop sat in the cone, a smaller one leaning off it.
	scoops.set_instance_transform(0, Transform3D(Basis(), Vector3(0, 0.16, 0)))
	scoops.set_instance_transform(1, Transform3D(
		Basis().scaled(Vector3.ONE * 0.74), Vector3(0.035, 0.3, -0.015)))
	var scoop_node := MultiMeshInstance3D.new()
	scoop_node.multimesh = scoops
	add_child(scoop_node)


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 3.0) * 0.06
	rotation.y += delta * 1.2


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("collect_food"):
		return
	body.collect_food(value)
	if body.has_method("add_wing_energy"):
		body.add_wing_energy(14.0) # crumbs top up the wing dial a little
	set_deferred("monitoring", false)
	Snd.sfx("yum", 0.0, 0.15)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.8, 0.12)
	tween.parallel().tween_property(self, "position:y", position.y + 0.3, 0.12)
	tween.tween_callback(_after_eaten)


func _after_eaten() -> void:
	if respawn_seconds <= 0.0:
		queue_free()
		return
	visible = false
	await get_tree().create_timer(respawn_seconds).timeout
	scale = Vector3.ONE
	position.y = _base_y
	visible = true
	set_deferred("monitoring", true)
