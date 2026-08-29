class_name ToadBoss3D
extends BaseBoss3D

## THE TOAD, parked in front of the pantry door with no intention of moving.
##
## Its verb is what you FEED it. It cannot be hurt — not because it is armoured
## but because it does not care — and it will not move while it still has an
## appetite. The only thing it respects is food it did not have to reach for:
## drop a POO BOMB inside tongue range and it snaps the bomb up, swallows it,
## and the fuse does the rest from inside. Its health bar is its APPETITE, and
## every swallowed bomb takes a bite out of it; at zero it topples onto its
## back, too full to guard anything.
##
## The whole pantry loop closes through this fight: gorge to get heavy, bomb
## to feed the toad AND shed the weight — the boss is the gym.
##
## Seven bosses, seven questions:
##   rat = when to hit · Granny = don't be hit · cat = what to hit ·
##   Queen = hit something else first · mantis = from where · wasp = stand
##   where · toad = what you FEED it

enum State { LAZE, GUARD, GULP, TOPPLED }

@export_group("Encounter")
@export var notice_range := 12.0
## How far the tongue reaches — for bombs and for Harry alike.
@export var tongue_range := 4.2
@export var tongue_interval := 2.6
@export var tongue_damage := 1

var state := State.LAZE

var _tongue_timer := 1.5
var _gulp_timer := 0.0
var _target: Node3D
var _visual: Node3D
var _belly: MeshInstance3D
var _tongue: MeshInstance3D
var _idle_time := 0.0


func _ready() -> void:
	super()
	boss_rule = "Don't fight it - FEED it! Drop poo bombs (Z) in tongue reach."
	immune_to_damage = true # nothing hurts a toad that size; feeding is the way
	summon_count = 0 # a glutton shares its fight with nobody
	_visual = _build_toad()
	add_child(_visual)


func _physics_process(delta: float) -> void:
	if state == State.TOPPLED:
		return
	_idle_time += delta
	# A slow, contented breathing wobble, whatever else is happening.
	if is_instance_valid(_visual):
		_visual.scale.y = 1.0 + sin(_idle_time * 2.2) * 0.03
	if not _acquire_target():
		return
	if state == State.LAZE:
		if absf(_target.global_position.x - global_position.x) <= notice_range:
			state = State.GUARD
			engage()
		return
	if state == State.GULP:
		_gulp_timer -= delta
		if _gulp_timer <= 0.0:
			state = State.GUARD
		return
	_watch_for_bombs()
	_tongue_timer -= delta
	if _tongue_timer <= 0.0:
		_tongue_timer = tongue_interval
		if _target.global_position.distance_to(global_position) <= tongue_range:
			_snap_at(_target.global_position, true)


## Anything droppable within reach gets eaten the moment it lands. The bomb is
## consumed BEFORE its own fuse ends — it goes off inside, which is the point.
func _watch_for_bombs() -> void:
	for child in get_parent().get_children():
		if child is PooBomb3D and not child.is_queued_for_deletion() \
				and child.global_position.distance_to(global_position) <= tongue_range:
			_gulp(child)
			return


func _gulp(bomb: Node3D) -> void:
	state = State.GULP
	_gulp_timer = 0.9
	_snap_at(bomb.global_position, false)
	bomb.queue_free()
	Snd.sfx("splat", -2.0, 0.2)
	Fx.impact_text(get_parent(), global_position + Vector3(0, 2.4, 0),
		Color(0.9, 0.75, 0.4), "GULP!", 0.8)
	# The bulge, then the muffled boom from inside.
	if is_instance_valid(_belly):
		var swell := create_tween()
		swell.tween_property(_belly, "scale", Vector3(1.25, 1.2, 1.25), 0.25)
		swell.tween_property(_belly, "scale", Vector3.ONE, 0.4)
	await get_tree().create_timer(0.5).timeout
	if state == State.TOPPLED:
		return
	Snd.sfx("impact_heavy", -6.0, 0.1)
	_shudder()
	Fx.spark_burst(get_parent(), global_position + Vector3(0, 1.2, 0),
		Color(0.7, 0.5, 0.3))
	lose_health(1)


## The tongue: one pink cylinder scaled out to the mark and snapped back.
## `bites` only for the strike at Harry — a bomb is swallowed, not fought.
func _snap_at(at: Vector3, bites: bool) -> void:
	if not is_instance_valid(_tongue):
		return
	var from := global_position + Vector3(0, 1.0, 0)
	var out := at - from
	var reach := out.length()
	if reach < 0.01:
		return
	_tongue.visible = true
	_tongue.rotation.z = atan2(out.y, out.x) - PI / 2.0
	_tongue.scale = Vector3(1.0, 0.05, 1.0)
	Snd.sfx("whoosh", -3.0, 0.2)
	var tween := create_tween()
	tween.tween_property(_tongue, "scale", Vector3(1.0, reach, 1.0), 0.12)
	tween.tween_callback(func() -> void:
		if bites and is_instance_valid(_target) \
				and _target.global_position.distance_to(at) < 1.2 \
				and _target.has_method("take_damage"):
			_target.take_damage(tongue_damage, global_position, "toad"))
	tween.tween_property(_tongue, "scale", Vector3(1.0, 0.05, 1.0), 0.16)
	tween.tween_callback(func() -> void:
		if is_instance_valid(_tongue):
			_tongue.visible = false)


func _shudder() -> void:
	if not is_instance_valid(_visual):
		return
	var tween := create_tween()
	tween.tween_property(_visual, "rotation:z", 0.06, 0.06)
	tween.tween_property(_visual, "rotation:z", -0.06, 0.1)
	tween.tween_property(_visual, "rotation:z", 0.0, 0.08)


func _acquire_target() -> bool:
	if not is_instance_valid(_target):
		_target = null
		for node in get_tree().get_nodes_in_group("player"):
			_target = node
			break
	return _target != null


func _on_damage_shrugged(_amount: int, _from_position: Vector3) -> void:
	Fx.impact_text(get_parent(), global_position + Vector3(0, 2.6, 0),
		Color(0.9, 0.85, 0.6), "IT WANTS FEEDING!", 0.7)


## Too full to sit up. It rolls onto its back and the door behind it is yours.
func _on_defeated() -> void:
	state = State.TOPPLED
	Snd.sfx("impact_heavy", 2.0)
	Fx.impact_text(get_parent(), global_position + Vector3(0, 2.6, 0),
		Color(0.65, 0.95, 0.7), "STUFFED!", 1.0)
	if is_instance_valid(_tongue):
		_tongue.visible = false
	var tween := create_tween()
	tween.tween_property(_visual, "rotation:z", PI * 0.9, 0.7
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(self, "global_position:x",
		global_position.x + 2.2, 0.7)
	tween.parallel().tween_property(self, "global_position:y",
		global_position.y + 0.4, 0.35)


## Warty green bulk: body, paler belly, a head that is mostly mouth, two big
## eyes on top, four stub legs. The tongue hides until it strikes.
func _build_toad() -> Node3D:
	var root := Node3D.new()
	var hide := Block3D.textured_material(Color(0.36, 0.5, 0.22), "speckle", 1.8)
	var pale := Block3D.flat_material(Color(0.78, 0.8, 0.55))

	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 1.5
	body_mesh.height = 2.4
	body_mesh.material = hide
	body.mesh = body_mesh
	body.position = Vector3(0, 1.1, 0)
	root.add_child(body)

	_belly = MeshInstance3D.new()
	var belly_mesh := SphereMesh.new()
	belly_mesh.radius = 1.1
	belly_mesh.height = 1.7
	belly_mesh.material = pale
	_belly.mesh = belly_mesh
	_belly.position = Vector3(0.35, 0.85, 0)
	root.add_child(_belly)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.95
	head_mesh.height = 1.3
	head_mesh.material = hide
	head.mesh = head_mesh
	head.position = Vector3(0.85, 1.9, 0)
	root.add_child(head)

	# The mouth line: a dark slab across the front of the head.
	var mouth := MeshInstance3D.new()
	var mouth_mesh := BoxMesh.new()
	mouth_mesh.size = Vector3(1.5, 0.09, 1.3)
	mouth_mesh.material = Block3D.flat_material(Color(0.16, 0.2, 0.1))
	mouth.mesh = mouth_mesh
	mouth.position = Vector3(1.0, 1.7, 0)
	mouth.rotation.z = -0.12
	root.add_child(mouth)

	var eye_mat := Block3D.flat_material(Color(0.08, 0.07, 0.05))
	eye_mat.roughness = 0.2
	var glint_mat := Block3D.flat_material(Color(1.0, 0.95, 0.8))
	glint_mat.emission_enabled = true
	glint_mat.emission = Color(1.0, 0.9, 0.7)
	glint_mat.emission_energy_multiplier = 1.1
	for side in [-1.0, 1.0]:
		var socket := MeshInstance3D.new()
		var socket_mesh := SphereMesh.new()
		socket_mesh.radius = 0.36
		socket_mesh.height = 0.6
		socket_mesh.material = hide
		socket.mesh = socket_mesh
		socket.position = Vector3(0.85, 2.6, side * 0.42)
		root.add_child(socket)
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.2
		eye_mesh.height = 0.36
		eye_mesh.radial_segments = 8
		eye_mesh.rings = 4
		eye_mesh.material = eye_mat
		eye.mesh = eye_mesh
		eye.position = Vector3(1.0, 2.7, side * 0.42)
		root.add_child(eye)
		var glint := MeshInstance3D.new()
		var glint_mesh := SphereMesh.new()
		glint_mesh.radius = 0.06
		glint_mesh.height = 0.11
		glint_mesh.radial_segments = 5
		glint_mesh.rings = 3
		glint_mesh.material = glint_mat
		glint.mesh = glint_mesh
		glint.position = Vector3(1.14, 2.78, side * 0.36)
		root.add_child(glint)

	# Warts, batched: one MultiMesh, not a draw call per lump.
	var wart_mesh := SphereMesh.new()
	wart_mesh.radius = 0.11
	wart_mesh.height = 0.18
	wart_mesh.radial_segments = 5
	wart_mesh.rings = 3
	wart_mesh.material = Block3D.flat_material(Color(0.3, 0.42, 0.18))
	var warts := MultiMesh.new()
	warts.transform_format = MultiMesh.TRANSFORM_3D
	warts.mesh = wart_mesh
	warts.instance_count = 10
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 10:
		var a := rng.randf_range(-PI * 0.7, PI * 0.7)
		warts.set_instance_transform(i, Transform3D(Basis(),
			Vector3(-0.3 + cos(a) * 1.1, 1.5 + sin(a) * 0.9,
				rng.randf_range(-0.9, 0.9))))
	var wart_inst := MultiMeshInstance3D.new()
	wart_inst.multimesh = warts
	root.add_child(wart_inst)

	for side in [-1.0, 1.0]:
		for fore in [0.55, -0.85]:
			var leg := MeshInstance3D.new()
			var leg_mesh := SphereMesh.new()
			leg_mesh.radius = 0.4
			leg_mesh.height = 0.55
			leg_mesh.material = hide
			leg.mesh = leg_mesh
			leg.position = Vector3(fore, 0.25, side * 0.95)
			root.add_child(leg)

	# The tongue: built at unit height, scaled out along its own Y to strike.
	_tongue = MeshInstance3D.new()
	var tongue_mesh := CylinderMesh.new()
	tongue_mesh.top_radius = 0.1
	tongue_mesh.bottom_radius = 0.14
	tongue_mesh.height = 1.0
	tongue_mesh.radial_segments = 6
	tongue_mesh.center_offset = Vector3(0, 0.5, 0) # grows from the mouth end
	tongue_mesh.material = Block3D.flat_material(Color(0.9, 0.45, 0.5))
	_tongue.mesh = tongue_mesh
	_tongue.position = Vector3(0, 1.0, 0)
	_tongue.visible = false
	root.add_child(_tongue)
	return root
