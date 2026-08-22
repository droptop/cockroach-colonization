extends Area3D

## A juicy berry — the premium wing fuel. Restores a big chunk of the wing
## dial and counts as food.

## Which fruit this is. They differ in what they are worth, not just in colour:
## a berry is a quick top-up, a grape is the same fruit twice over, and an apple
## core is a full tank you have to go out of your way for.
@export_enum("berry", "grape", "apple_core", "corn", "watermelon") var variety := "berry":
	set(value):
		variety = value
		_apply_variety()

@export var food_value := 1
@export var wing_energy_value := 45.0
@export var fruit_color := Color(0.85, 0.2, 0.25)
## Fruit grows back so the player can always refuel. 0 = never.
@export var respawn_seconds := 9.0

const VARIETIES := {
	"berry": {"food": 1, "wings": 45.0, "color": Color(0.85, 0.2, 0.25), "scale": 1.0},
	"grape": {"food": 2, "wings": 70.0, "color": Color(0.46, 0.26, 0.55), "scale": 1.0},
	"apple_core": {"food": 3, "wings": 100.0, "color": Color(0.92, 0.86, 0.62), "scale": 1.3},
	# The two big ones. More fullness as well as more wing energy, which is the
	# trade the whole food economy runs on: a melon is a tankful and a waistline.
	"corn": {"food": 3, "wings": 85.0, "color": Color(0.95, 0.79, 0.26), "scale": 1.0},
	"watermelon": {"food": 4, "wings": 120.0, "color": Color(0.88, 0.24, 0.29), "scale": 1.0},
}

var _time := 0.0
var _base_y := 0.0


## Applied on set so the editor shows the right thing, and again on ready so a
## scene that never touches the property still gets its defaults.
func _apply_variety() -> void:
	var spec: Dictionary = VARIETIES.get(variety, VARIETIES["berry"])
	food_value = spec.food
	wing_energy_value = spec.wings
	fruit_color = spec.color


func _ready() -> void:
	_apply_variety()
	_base_y = position.y
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)
	var spec: Dictionary = VARIETIES.get(variety, VARIETIES["berry"])
	match variety:
		"grape":
			_build_grapes()
		"corn":
			_build_corn()
		"watermelon":
			_build_watermelon()
		_:
			_build_berry(spec.scale)


## Berry, grape-that-was, apple core: one round thing with a shine and a leaf.
func _build_berry(size: float) -> void:
	var berry := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.24 * size
	mesh.height = 0.44 * size
	# An apple core is pinched in the middle.
	if variety == "apple_core":
		berry.scale = Vector3(0.72, 1.25, 0.72)
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


## A proper BUNCH, tilted off vertical, on a woody stem with one pointed leaf.
## A grape used to be "a berry but fatter", which is to say a purple ball.
##
## Three draw calls: every grape in one MultiMesh, then the stem and the leaf.
## Low segment counts on purpose — the facets are the look.
func _build_grapes() -> void:
	var bunch := Node3D.new()
	bunch.rotation.z = 0.3 # tilted to the side, and it spins on Y as it bobs
	add_child(bunch)

	# Widest at the shoulders, tapering to a single grape at the point.
	const CLUSTER := [
		Vector3(-0.105, 0.0, 0.02), Vector3(0.105, -0.01, -0.02),
		Vector3(0.0, 0.03, 0.105), Vector3(0.0, -0.02, -0.105),
		Vector3(-0.085, -0.15, 0.06), Vector3(0.09, -0.15, -0.04),
		Vector3(0.0, -0.16, 0.085), Vector3(-0.005, -0.14, -0.09),
		Vector3(-0.065, -0.285, -0.02), Vector3(0.07, -0.29, 0.03),
		Vector3(0.0, -0.41, 0.0),
	]
	var grape_mesh := SphereMesh.new()
	grape_mesh.radius = 0.1
	grape_mesh.height = 0.2
	grape_mesh.radial_segments = 7
	grape_mesh.rings = 4
	grape_mesh.material = Block3D.flat_material(fruit_color)
	var grapes := MultiMesh.new()
	grapes.transform_format = MultiMesh.TRANSFORM_3D
	grapes.mesh = grape_mesh
	grapes.instance_count = CLUSTER.size()
	for i in CLUSTER.size():
		# Size and spin varied per grape so the bunch is not a lattice.
		var size := 0.86 + float(i % 4) * 0.06
		grapes.set_instance_transform(i, Transform3D(
			Basis.from_euler(Vector3(0, float(i) * 0.7, float(i) * 0.4)).scaled(
				Vector3.ONE * size),
			CLUSTER[i]))
	var grape_node := MultiMeshInstance3D.new()
	grape_node.multimesh = grapes
	bunch.add_child(grape_node)

	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.017
	stem_mesh.bottom_radius = 0.028
	stem_mesh.height = 0.26
	stem_mesh.radial_segments = 5
	stem_mesh.material = Block3D.flat_material(Color(0.42, 0.28, 0.16))
	stem.mesh = stem_mesh
	stem.position = Vector3(0.035, 0.19, 0)
	stem.rotation.z = -0.3
	bunch.add_child(stem)

	# Pointed, not a blob: a prism has the leaf shape built in.
	var leaf := MeshInstance3D.new()
	var leaf_mesh := PrismMesh.new()
	leaf_mesh.size = Vector3(0.16, 0.24, 0.02)
	leaf_mesh.material = Block3D.flat_material(Color(0.36, 0.63, 0.26))
	leaf.mesh = leaf_mesh
	leaf.position = Vector3(0.15, 0.32, 0)
	leaf.rotation = Vector3(0, 0, -1.05)
	bunch.add_child(leaf)


## CORN ON THE COB: a capsule of a cob with kernels dimpled over it and husk
## leaves peeling off the bottom. Three draw calls — the kernels are one
## MultiMesh and so are the husks.
func _build_corn() -> void:
	var cob_node := Node3D.new()
	cob_node.rotation.z = 0.34
	add_child(cob_node)

	var cob := MeshInstance3D.new()
	var cob_mesh := CapsuleMesh.new()
	cob_mesh.radius = 0.115
	cob_mesh.height = 0.62
	cob_mesh.radial_segments = 10
	cob_mesh.rings = 4
	cob_mesh.material = Block3D.flat_material(fruit_color)
	cob.mesh = cob_mesh
	cob_node.add_child(cob)

	# Kernels sat ON the barrel of the capsule, in staggered rows the way they
	# actually grow. Slightly proud and slightly darker, so they catch the flat
	# lighting as bumps rather than as a printed pattern.
	const ROWS := 7
	const PER_ROW := 9
	var kernel_mesh := SphereMesh.new()
	kernel_mesh.radius = 0.032
	kernel_mesh.height = 0.064
	kernel_mesh.radial_segments = 5
	kernel_mesh.rings = 3
	kernel_mesh.material = Block3D.flat_material(fruit_color.darkened(0.16))
	var kernels := MultiMesh.new()
	kernels.transform_format = MultiMesh.TRANSFORM_3D
	kernels.mesh = kernel_mesh
	kernels.instance_count = ROWS * PER_ROW
	var n := 0
	for row in ROWS:
		var y := -0.18 + float(row) * 0.06
		for col in PER_ROW:
			var angle := float(col) * TAU / float(PER_ROW) + float(row) * 0.32
			kernels.set_instance_transform(n, Transform3D(Basis(), Vector3(
				sin(angle) * 0.105, y, cos(angle) * 0.105)))
			n += 1
	var kernel_node := MultiMeshInstance3D.new()
	kernel_node.multimesh = kernels
	cob_node.add_child(kernel_node)

	var husk_mesh := PrismMesh.new()
	husk_mesh.size = Vector3(0.2, 0.26, 0.03)
	husk_mesh.material = Block3D.flat_material(Color(0.55, 0.68, 0.3))
	var husks := MultiMesh.new()
	husks.transform_format = MultiMesh.TRANSFORM_3D
	husks.mesh = husk_mesh
	husks.instance_count = 3
	# Peeled back and hanging down, so they point the opposite way to the cob.
	const HUSKS := [
		{"pos": Vector3(-0.075, -0.26, 0.06), "rot": Vector3(0, 0, 2.95)},
		{"pos": Vector3(0.075, -0.27, -0.04), "rot": Vector3(0, 0, -2.95)},
		{"pos": Vector3(0.0, -0.29, 0.09), "rot": Vector3(0.35, 0, 3.14)},
	]
	for i in HUSKS.size():
		var h: Dictionary = HUSKS[i]
		husks.set_instance_transform(i, Transform3D(
			Basis.from_euler(h["rot"]), h["pos"]))
	var husk_node := MultiMeshInstance3D.new()
	husk_node.multimesh = husks
	cob_node.add_child(husk_node)


## WATERMELON, as a slice rather than as a whole one: a whole melon at this poly
## count is a green ball, and a roach could not carry one anyway. Prism for the
## flesh with the point DOWN, a green rind capping it, the pale pith between
## them, and pips on both faces. Four draw calls.
func _build_watermelon() -> void:
	var slice := Node3D.new()
	slice.rotation.z = 0.22
	add_child(slice)

	var flesh := MeshInstance3D.new()
	var flesh_mesh := PrismMesh.new()
	flesh_mesh.size = Vector3(0.5, 0.42, 0.13)
	flesh_mesh.material = Block3D.flat_material(fruit_color)
	flesh.mesh = flesh_mesh
	flesh.rotation.z = PI # apex down: that is the shape of a cut slice
	slice.add_child(flesh)

	var pith := MeshInstance3D.new()
	var pith_mesh := BoxMesh.new()
	pith_mesh.size = Vector3(0.5, 0.035, 0.134)
	pith_mesh.material = Block3D.flat_material(Color(0.93, 0.95, 0.86))
	pith.mesh = pith_mesh
	pith.position = Vector3(0, 0.2, 0)
	slice.add_child(pith)

	var rind := MeshInstance3D.new()
	var rind_mesh := BoxMesh.new()
	rind_mesh.size = Vector3(0.52, 0.075, 0.15)
	rind_mesh.material = Block3D.flat_material(Color(0.24, 0.52, 0.25))
	rind.mesh = rind_mesh
	rind.position = Vector3(0, 0.245, 0)
	slice.add_child(rind)

	const PIPS := [
		Vector3(-0.1, 0.06, 0.0), Vector3(0.1, 0.06, 0.0), Vector3(0.0, 0.02, 0.0),
		Vector3(-0.05, -0.09, 0.0), Vector3(0.06, -0.09, 0.0),
	]
	var pip_mesh := SphereMesh.new()
	pip_mesh.radius = 0.022
	pip_mesh.height = 0.044
	pip_mesh.radial_segments = 5
	pip_mesh.rings = 3
	pip_mesh.material = Block3D.flat_material(Color(0.17, 0.11, 0.09))
	var pips := MultiMesh.new()
	pips.transform_format = MultiMesh.TRANSFORM_3D
	pips.mesh = pip_mesh
	pips.instance_count = PIPS.size() * 2
	for i in PIPS.size():
		# Both faces, so it still reads once it has spun half a turn.
		var flat := Basis().scaled(Vector3(1.0, 1.0, 0.5))
		pips.set_instance_transform(i, Transform3D(flat,
			PIPS[i] + Vector3(0, 0, 0.064)))
		pips.set_instance_transform(i + PIPS.size(), Transform3D(flat,
			PIPS[i] + Vector3(0, 0, -0.064)))
	var pip_node := MultiMeshInstance3D.new()
	pip_node.multimesh = pips
	slice.add_child(pip_node)


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 2.2) * 0.09
	rotation.y += delta * 0.9


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("collect_food"):
		return
	if body.has_method("collect_fruit"):
		body.collect_fruit(food_value)
	else:
		body.collect_food(food_value)
	if body.has_method("add_wing_energy"):
		body.add_wing_energy(wing_energy_value)
	set_deferred("monitoring", false)
	Snd.sfx("fruit")
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.9, 0.14)
	tween.parallel().tween_property(self, "position:y", position.y + 0.4, 0.14)
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
