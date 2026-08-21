extends Area3D

## 3D crumb: a little sheaf of wheat that bobs and spins slowly.

@export var value := 1
@export var crumb_color := Color(0.85, 0.68, 0.4)
## Eaten food grows back so the player can always refuel. 0 = never.
@export var respawn_seconds := 12.0

var _time := 0.0
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU # desync bobbing between crumbs
	body_entered.connect(_on_body_entered)
	# A little SHEAF of wheat rather than a lump. Two beige spheres read as a
	# pebble, and the crumb is the thing he picks up most often in the game.
	#
	# TWO draw calls, the same as the lump it replaces. Built the obvious way
	# (a node per stalk, a node per ear cluster, a tie) it was seven, and there
	# are enough crumbs in a level that perf_budget_test failed on the tabletop
	# immediately. Everything is batched: one MultiMesh of stalks, one of grains,
	# with the lean folded into the grain positions by hand.
	const LEANS := [-0.28, 0.0, 0.28]
	var straw := Block3D.flat_material(crumb_color.darkened(0.25))
	var grain := Block3D.flat_material(crumb_color)

	var stalks := MultiMesh.new()
	stalks.transform_format = MultiMesh.TRANSFORM_3D
	var stalk_mesh := CylinderMesh.new()
	stalk_mesh.top_radius = 0.014
	stalk_mesh.bottom_radius = 0.022
	stalk_mesh.height = 0.26
	stalk_mesh.radial_segments = 4
	stalk_mesh.material = straw
	stalks.mesh = stalk_mesh
	stalks.instance_count = LEANS.size()
	for i in LEANS.size():
		var lean: float = LEANS[i]
		stalks.set_instance_transform(i, Transform3D(
			Basis.from_euler(Vector3(0, 0, -lean)),
			Vector3(lean * 0.32, -0.02, 0)))
	var stalk_node := MultiMeshInstance3D.new()
	stalk_node.multimesh = stalks
	add_child(stalk_node)

	var ears := MultiMesh.new()
	ears.transform_format = MultiMesh.TRANSFORM_3D
	var ear_mesh := SphereMesh.new()
	ear_mesh.radius = 0.036
	ear_mesh.height = 0.075
	ear_mesh.radial_segments = 5
	ear_mesh.rings = 3
	ear_mesh.material = grain
	ears.mesh = ear_mesh
	ears.instance_count = LEANS.size() * 7
	var n := 0
	for i in LEANS.size():
		var lean: float = LEANS[i]
		for k in 7:
			var up: float = 0.09 + float(k) * 0.028
			var side: float = 0.026 if k % 2 == 0 else -0.026
			ears.set_instance_transform(n, Transform3D(Basis(),
				Vector3(lean * 0.32 - sin(lean) * up + side, up, 0.0)))
			n += 1
	var ear_node := MultiMeshInstance3D.new()
	ear_node.multimesh = ears
	add_child(ear_node)


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
	Snd.sfx("crumb")
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
