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
	var rust := Block3D.flat_material(Color(0.5, 0.31, 0.19))
	rust.roughness = 0.95
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.038
	shaft_mesh.bottom_radius = 0.008 # tapers to the point
	shaft_mesh.height = 0.52
	shaft_mesh.radial_segments = 8
	shaft_mesh.material = rust
	shaft.mesh = shaft_mesh
	shaft.rotation.z = 0.45
	root.add_child(shaft)
	var head := MeshInstance3D.new()
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.085
	head_mesh.bottom_radius = 0.085
	head_mesh.height = 0.045
	head_mesh.radial_segments = 8
	head_mesh.material = Block3D.flat_material(Color(0.58, 0.38, 0.24))
	head.mesh = head_mesh
	head.position = Vector3(-0.11, 0.24, 0)
	head.rotation.z = 0.45
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
	var neck := MeshInstance3D.new()
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.05
	neck_mesh.bottom_radius = 0.1
	neck_mesh.height = 0.38
	neck_mesh.radial_segments = 10
	neck_mesh.material = glass_mat
	neck.mesh = neck_mesh
	neck.rotation.z = 0.3
	root.add_child(neck)
	var shards := [
		{"pos": Vector3(0.14, 0.16, 0.02), "rot": 0.5},
		{"pos": Vector3(0.09, 0.2, -0.03), "rot": -0.3},
		{"pos": Vector3(0.02, 0.22, 0.03), "rot": 0.9},
		{"pos": Vector3(-0.04, 0.18, -0.02), "rot": -0.7},
	]
	for s in shards:
		var shard := MeshInstance3D.new()
		var shard_mesh := BoxMesh.new()
		shard_mesh.size = Vector3(0.03, 0.13, 0.02)
		shard_mesh.material = glass_mat
		shard.mesh = shard_mesh
		shard.position = s.pos
		shard.rotation.z = s.rot
		root.add_child(shard)


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
