class_name WeaponVisuals
extends RefCounted

## Shared procedural mesh builder for weapons and shields — static, no
## instance state, same spirit as Block3D.flat_material/Fx. Used by BOTH the
## ground pickups (items/weapons/*_pickup_3d.gd) and the player's held/worn
## visuals (player/player_3d.gd), so what's lying on the floor is exactly
## what Harry ends up holding, just scaled up when held.

static func build_weapon(id: String) -> Node3D:
	var root := Node3D.new()
	match id:
		"fork":
			_build_fork(root)
		"knife":
			_build_knife(root)
		"broken_bottle":
			_build_broken_bottle(root)
		"rubber_band":
			_build_rubber_band(root)
		"spoon":
			_build_spoon(root)
		"straw":
			_build_straw(root)
		"pebble":
			_build_pebble(root)
		_:
			_build_rusty_nail(root)
	return root


static func build_shield(kind: String) -> Node3D:
	var root := Node3D.new()
	if kind == "pan":
		_build_pan(root)
	else:
		_build_cap(root)
	return root


## Rust-pitted nail: flat struck head, tapered shaft, blunt point. The old
## rounded-headed pin read as a sewing pin; a nail wants a hard flat head.
static func _build_rusty_nail(root: Node3D) -> void:
	var rust := Block3D.flat_material(Color(0.46, 0.33, 0.26))
	rust.roughness = 0.95
	var steel := Block3D.flat_material(Color(0.56, 0.55, 0.57))
	steel.roughness = 0.8

	# A CUT nail: square in section and tapering on two faces only, with a
	# broad forged head. radial_segments 4 is what squares the shaft off; the
	# old one was an 8 sided spike, which read as a dart.
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.062
	shaft_mesh.bottom_radius = 0.016
	shaft_mesh.height = 0.56
	shaft_mesh.radial_segments = 4
	shaft_mesh.material = steel
	shaft.mesh = shaft_mesh
	shaft.rotation.z = 0.45
	shaft.rotation.y = PI * 0.25 # a flat face to camera, not an edge
	shaft.scale = Vector3(1.0, 1.0, 0.6) # flattened, the way a cut nail is
	root.add_child(shaft)

	# Chisel point rather than a needle.
	var tip := MeshInstance3D.new()
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.016
	tip_mesh.bottom_radius = 0.0
	tip_mesh.height = 0.1
	tip_mesh.radial_segments = 4
	tip_mesh.material = steel
	tip.mesh = tip_mesh
	tip.position = Vector3(0.14, -0.31, 0)
	tip.rotation.z = 0.45
	tip.rotation.y = PI * 0.25
	tip.scale = Vector3(1.0, 1.0, 0.45)
	root.add_child(tip)

	# Wide flat head, sitting slightly proud and off-square like a forged one.
	var head := MeshInstance3D.new()
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.125
	head_mesh.bottom_radius = 0.108
	head_mesh.height = 0.05
	head_mesh.radial_segments = 6
	head_mesh.material = rust
	head.mesh = head_mesh
	head.position = Vector3(-0.12, 0.26, 0)
	head.rotation.z = 0.45
	head.scale = Vector3(1.0, 1.0, 0.75)
	root.add_child(head)


## A perished elastic band, folded over. Doubles as the projectile mesh, so
## what you fire is visibly the thing you were holding.
static func _build_rubber_band(root: Node3D) -> void:
	var rubber := Block3D.flat_material(Color(0.82, 0.42, 0.48))
	rubber.roughness = 0.9
	for side in [-1.0, 1.0]:
		var strand := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.035
		mesh.bottom_radius = 0.035
		mesh.height = 0.42
		mesh.radial_segments = 6
		mesh.material = rubber
		strand.mesh = mesh
		strand.position = Vector3(0, 0, side * 0.09)
		strand.rotation.z = side * 0.22
		root.add_child(strand)
	for end in [-0.21, 0.21]:
		var loop := MeshInstance3D.new()
		var loop_mesh := SphereMesh.new()
		loop_mesh.radius = 0.075
		loop_mesh.height = 0.14
		loop_mesh.radial_segments = 6
		loop_mesh.rings = 3
		loop_mesh.material = rubber
		loop.mesh = loop_mesh
		loop.position = Vector3(0, end, 0)
		root.add_child(loop)


## A teaspoon: handle and a shallow bowl. The bowl is the business end, so it
## is the part that reads at a glance.
static func _build_spoon(root: Node3D) -> void:
	var steel := Block3D.flat_material(Color(0.82, 0.84, 0.88))
	steel.metallic = 0.4
	steel.roughness = 0.35
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.07, 0.42, 0.04)
	handle_mesh.material = steel
	handle.mesh = handle_mesh
	handle.position = Vector3(0, -0.1, 0)
	root.add_child(handle)
	var bowl := MeshInstance3D.new()
	var bowl_mesh := SphereMesh.new()
	bowl_mesh.radius = 0.15
	bowl_mesh.height = 0.26
	bowl_mesh.radial_segments = 10
	bowl_mesh.rings = 5
	bowl_mesh.material = steel
	bowl.mesh = bowl_mesh
	bowl.scale = Vector3(0.85, 1.0, 0.4)
	bowl.position = Vector3(0, 0.2, 0)
	root.add_child(bowl)


## A bent drinking straw. Long, hollow and almost weightless — the silhouette
## is all length, which is exactly what the weapon is for.
static func _build_straw(root: Node3D) -> void:
	var plastic := Block3D.flat_material(Color(0.92, 0.45, 0.5))
	for part in [[0.0, 0.44, 0.0], [0.16, 0.22, -0.5]]:
		var seg := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.045
		mesh.bottom_radius = 0.05
		mesh.height = part[1]
		mesh.radial_segments = 6
		mesh.material = plastic
		seg.mesh = mesh
		seg.position = Vector3(0, part[0] + part[1] * 0.5 - 0.22, 0)
		seg.rotation.z = part[2]
		root.add_child(seg)
	# The ribbed elbow, so it reads as a bendy straw rather than a rod.
	for i in 3:
		var rib := MeshInstance3D.new()
		var rib_mesh := TorusMesh.new()
		rib_mesh.inner_radius = 0.048
		rib_mesh.outer_radius = 0.068
		rib_mesh.rings = 6
		rib_mesh.ring_segments = 4
		rib_mesh.material = plastic
		rib.mesh = rib_mesh
		rib.rotation.x = PI / 2
		rib.position = Vector3(0, 0.02 + i * 0.05, 0)
		root.add_child(rib)


## A chip of grit. Doubles as the thing that gets thrown.
static func _build_pebble(root: Node3D) -> void:
	var stone := Block3D.textured_material(Color(0.55, 0.55, 0.58), "concrete", 3.0)
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.13
	mesh.height = 0.22
	mesh.radial_segments = 5
	mesh.rings = 3
	mesh.material = stone
	rock.mesh = mesh
	rock.scale = Vector3(1.0, 0.8, 0.9)
	root.add_child(rock)
	var chip := MeshInstance3D.new()
	var chip_mesh := SphereMesh.new()
	chip_mesh.radius = 0.07
	chip_mesh.height = 0.12
	chip_mesh.radial_segments = 4
	chip_mesh.rings = 2
	chip_mesh.material = stone
	chip.mesh = chip_mesh
	chip.position = Vector3(0.09, -0.06, 0.04)
	root.add_child(chip)


static func _build_fork(root: Node3D) -> void:
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.36, 0.06, 0.06)
	handle_mesh.material = Block3D.flat_material(Color(0.8, 0.82, 0.86))
	handle.mesh = handle_mesh
	root.add_child(handle)
	for offset in [-0.09, 0.0, 0.09]:
		var tine := MeshInstance3D.new()
		var tine_mesh := BoxMesh.new()
		tine_mesh.size = Vector3(0.18, 0.03, 0.03)
		tine_mesh.material = Block3D.flat_material(Color(0.85, 0.87, 0.9))
		tine.mesh = tine_mesh
		tine.position = Vector3(0.26, 0.0, offset)
		root.add_child(tine)


static func _build_knife(root: Node3D) -> void:
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.18, 0.06, 0.07)
	handle_mesh.material = Block3D.flat_material(Color(0.4, 0.28, 0.18))
	handle.mesh = handle_mesh
	handle.position = Vector3(-0.16, 0, 0)
	root.add_child(handle)
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.32, 0.09, 0.02)
	blade_mesh.material = Block3D.flat_material(Color(0.85, 0.87, 0.9))
	blade.mesh = blade_mesh
	blade.position = Vector3(0.1, 0, 0)
	root.add_child(blade)


## A snapped-off bottle neck — jagged glass teeth around the broken rim.
static func _build_broken_bottle(root: Node3D) -> void:
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.3, 0.5, 0.32, 0.55)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.emission_enabled = true
	glass_mat.emission = Color(0.55, 0.85, 0.6)
	glass_mat.emission_energy_multiplier = 0.4

	# Held by the NECK, broken across the body, so the jagged end is the wide
	# end and points away from his hand. The old one was a plain neck cylinder
	# with four matchstick shards, which read as a bud vase.
	const TILT := 0.42
	var pivot := Node3D.new()
	pivot.rotation.z = TILT
	root.add_child(pivot)

	# Lip ring at the very bottom of the grip, the way a bottle mouth flares.
	var lip := MeshInstance3D.new()
	var lip_mesh := TorusMesh.new()
	lip_mesh.inner_radius = 0.045
	lip_mesh.outer_radius = 0.07
	lip_mesh.rings = 8
	lip_mesh.ring_segments = 6
	lip_mesh.material = glass_mat
	lip.mesh = lip_mesh
	lip.position = Vector3(0, -0.3, 0)
	lip.rotation.x = PI / 2.0
	pivot.add_child(lip)

	var neck := MeshInstance3D.new()
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.058
	neck_mesh.bottom_radius = 0.052
	neck_mesh.height = 0.2
	neck_mesh.radial_segments = 8
	neck_mesh.material = glass_mat
	neck.mesh = neck_mesh
	neck.position = Vector3(0, -0.2, 0)
	pivot.add_child(neck)

	# The shoulder flaring out to the body.
	var shoulder := MeshInstance3D.new()
	var shoulder_mesh := CylinderMesh.new()
	shoulder_mesh.top_radius = 0.13
	shoulder_mesh.bottom_radius = 0.058
	shoulder_mesh.height = 0.16
	shoulder_mesh.radial_segments = 8
	shoulder_mesh.material = glass_mat
	shoulder.mesh = shoulder_mesh
	shoulder.position = Vector3(0, -0.02, 0)
	pivot.add_child(shoulder)

	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.13
	body_mesh.bottom_radius = 0.13
	body_mesh.height = 0.17
	body_mesh.radial_segments = 8
	body_mesh.material = glass_mat
	body.mesh = body_mesh
	body.position = Vector3(0, 0.14, 0)
	pivot.add_child(body)

	# The break: uneven fangs around the rim, two long ones and the rest
	# stubs, because an even crown reads as a machined part rather than glass
	# someone smashed.
	const FANGS := [0.20, 0.07, 0.13, 0.05, 0.22, 0.06, 0.11, 0.05]
	for i in FANGS.size():
		var a: float = TAU * i / float(FANGS.size())
		var h: float = FANGS[i]
		var fang := MeshInstance3D.new()
		var fang_mesh := CylinderMesh.new()
		fang_mesh.top_radius = 0.0
		fang_mesh.bottom_radius = 0.042
		fang_mesh.height = h
		fang_mesh.radial_segments = 3
		fang_mesh.material = glass_mat
		fang.mesh = fang_mesh
		fang.position = Vector3(cos(a) * 0.1, 0.225 + h * 0.5, sin(a) * 0.1)
		fang.rotation.z = -cos(a) * 0.3
		fang.rotation.x = sin(a) * 0.3
		pivot.add_child(fang)


## The bottle cap worn like a halo — a gold ring, not a solid disc.
static func _build_cap(root: Node3D) -> void:
	var gold := Block3D.flat_material(Color(0.85, 0.2, 0.2))
	gold.emission_enabled = true
	gold.emission = Color(0.9, 0.3, 0.25)
	gold.emission_energy_multiplier = 0.4
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.14
	ring_mesh.outer_radius = 0.24
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 10
	ring_mesh.material = gold
	ring.mesh = ring_mesh
	root.add_child(ring)
	var rim := MeshInstance3D.new()
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.16
	rim_mesh.outer_radius = 0.2
	rim_mesh.rings = 24
	rim_mesh.ring_segments = 6
	rim_mesh.material = Block3D.flat_material(Color(0.92, 0.85, 0.7))
	rim.mesh = rim_mesh
	rim.position.y = 0.02
	root.add_child(rim)


## A frying pan held up like a shield: round body + rim + a handle to one side.
static func _build_pan(root: Node3D) -> void:
	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.24
	body_mesh.bottom_radius = 0.22
	body_mesh.height = 0.06
	body_mesh.radial_segments = 16
	body_mesh.material = Block3D.flat_material(Color(0.18, 0.18, 0.2))
	body.mesh = body_mesh
	root.add_child(body)
	var rim := MeshInstance3D.new()
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.2
	rim_mesh.outer_radius = 0.25
	rim_mesh.rings = 20
	rim_mesh.ring_segments = 6
	rim_mesh.material = Block3D.flat_material(Color(0.3, 0.3, 0.33))
	rim.mesh = rim_mesh
	root.add_child(rim)
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.025
	handle_mesh.bottom_radius = 0.03
	handle_mesh.height = 0.32
	handle_mesh.material = Block3D.flat_material(Color(0.25, 0.16, 0.1))
	handle.mesh = handle_mesh
	handle.position = Vector3(0.34, 0, 0)
	handle.rotation.z = PI / 2
	root.add_child(handle)
