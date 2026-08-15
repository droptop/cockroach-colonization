class_name CatBoss3D
extends BaseBoss3D

## THE CAT. Enormous relative to a cockroach — expressed through a head, paws
## and shadows rather than by standing a whole cat on a table, which at this
## scale would not fit on screen.
##
## Its own mechanic, distinct from the other two bosses:
##   - the rat is hittable anywhere, and you learn WHEN to hit;
##   - Granny cannot be hit at all, and you win by not being hit;
##   - the cat can only be hurt on a PAW it leaves behind after a swipe.
## Hitting the cat itself does nothing. Punishing the paw during its recovery
## window is the whole fight, so the player has to bait a swipe on purpose and
## then be somewhere they can reach the paw.

enum State { WAITING, TELEGRAPH, PAW_DOWN, POUNCE, SHAKE, RETREATING, GONE }

@export_group("Encounter")
@export var notice_range := 14.0
@export var attack_interval := 2.4
@export var telegraph_time := 1.0

@export_group("Attacks")
@export var swipe_radius := 2.2
@export var swipe_damage := 2
## How long the paw stays down and hittable. The entire fight lives in here.
@export var paw_recovery := 1.8
@export var pounce_radius := 3.4
@export var pounce_damage := 3
@export var shake_damage := 1
@export var shake_impulse := 7.0

var state := State.WAITING

var _timer := 0.0
var _attack_index := 0
var _target: Node3D
var _paw: CatPaw3D
var _visual: Node3D
var _eyes: Array[MeshInstance3D] = []

## Fixed order, so the player can learn to bait the swipe they need.
const ROTATION := ["swipe", "shake", "swipe", "pounce"]


func _ready() -> void:
	super()
	immune_to_damage = true # only the paw counts
	_visual = _build_cat()
	add_child(_visual)


func _physics_process(delta: float) -> void:
	if state == State.GONE:
		return
	_timer -= delta
	# Eyes track him the whole time, which is most of the menace.
	if _acquire_target():
		for eye in _eyes:
			var dx: float = clampf((_target.global_position.x - global_position.x) * 0.02, -0.22, 0.22)
			eye.position.x = lerpf(eye.position.x, eye.get_meta("base_x", 0.0) + dx, 0.08)
	match state:
		State.WAITING:
			if _timer <= 0.0 and _acquire_target() \
					and absf(_target.global_position.x - global_position.x) < notice_range:
				engage()
				_begin_attack()
		State.PAW_DOWN:
			if _timer <= 0.0:
				_retract_paw()
		State.RETREATING:
			if _timer <= 0.0:
				state = State.GONE


func _begin_attack() -> void:
	var kind: String = ROTATION[_attack_index % ROTATION.size()]
	_attack_index += 1
	match kind:
		"swipe":
			_swipe()
		"pounce":
			_pounce()
		"shake":
			_shake()


## Marks the floor, waits, then hands the SAME radius to the strike — the rule
## the acid puddle taught us, applied from the start here.
func _mark(aim: Vector3, radius: float, tint: Color) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.03
	disc.radial_segments = 20
	var mat := Block3D.flat_material(Color(tint.r, tint.g, tint.b, 0.32))
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 0.9
	disc.material = mat
	marker.mesh = disc
	get_parent().add_child(marker)
	marker.global_position = aim + Vector3(0, 0.05, 0)
	marker.scale = Vector3(0.15, 1.0, 0.15)
	var tween := marker.create_tween()
	tween.tween_property(marker, "scale", Vector3.ONE, telegraph_time)
	return marker


func _hits(aim: Vector3, radius: float) -> bool:
	return is_instance_valid(_target) and not _target.is_dead \
		and _target.global_position.distance_to(aim) <= radius


func _swipe() -> void:
	state = State.TELEGRAPH
	var aim := _target.global_position
	var marker := _mark(aim, swipe_radius, Color(1.0, 0.6, 0.35))
	await get_tree().create_timer(telegraph_time).timeout
	if state == State.GONE or is_defeated:
		marker.queue_free()
		return
	marker.queue_free()
	_paw = CatPaw3D.new()
	_paw.boss = self
	get_parent().add_child(_paw)
	_paw.global_position = aim + Vector3(0, 7.0, 0)
	var tween := _paw.create_tween()
	tween.tween_property(_paw, "global_position", aim, 0.11).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if _hits(aim, swipe_radius):
			_target.take_damage(swipe_damage, aim, "paw")
		Snd.sfx("thud", 3.0)
		Fx.spark_burst(get_parent(), aim + Vector3(0, 0.3, 0), Color(1.0, 0.8, 0.6))
		_shake_camera(0.5)
		# Down, heavy, and briefly yours.
		if is_instance_valid(_paw):
			_paw.set_vulnerable(true))
	state = State.PAW_DOWN
	_timer = paw_recovery


func _retract_paw() -> void:
	if is_instance_valid(_paw):
		_paw.set_vulnerable(false)
		var paw := _paw
		var tween := paw.create_tween()
		tween.tween_property(paw, "global_position",
			paw.global_position + Vector3(0, 7.0, 0), 0.35).set_ease(Tween.EASE_IN)
		tween.tween_callback(paw.queue_free)
	_paw = null
	state = State.WAITING
	_timer = attack_interval


## Head comes down across a wide stretch. No weak point — pure dodge, so the
## swipe stays the only way in.
func _pounce() -> void:
	state = State.TELEGRAPH
	var aim := _target.global_position
	var marker := _mark(aim, pounce_radius, Color(1.0, 0.35, 0.35))
	await get_tree().create_timer(telegraph_time * 1.3).timeout
	if state == State.GONE or is_defeated:
		marker.queue_free()
		return
	marker.queue_free()
	state = State.POUNCE
	var head := _visual.duplicate() as Node3D
	get_parent().add_child(head)
	head.scale = Vector3.ONE * 0.9
	head.global_position = aim + Vector3(0, 10.0, 0)
	var tween := head.create_tween()
	tween.tween_property(head, "global_position", aim + Vector3(0, 1.6, 0), 0.16
		).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if _hits(aim, pounce_radius):
			_target.take_damage(pounce_damage, aim, "pounce")
		Snd.sfx("thud", 6.0)
		_shake_camera(0.85))
	tween.tween_interval(0.4)
	tween.tween_property(head, "global_position", aim + Vector3(0, 11.0, 0), 0.5)
	tween.tween_callback(head.queue_free)
	state = State.WAITING
	_timer = attack_interval + 0.6


## It leans on the table. Everything jolts, and anything not braced gets thrown
## — a table-wide attack there is no dodging, only surviving.
func _shake() -> void:
	state = State.SHAKE
	Snd.sfx("thud", -2.0, 0.3)
	var tween := create_tween()
	for i in 5:
		tween.tween_property(_visual, "position:x", 0.35 if i % 2 == 0 else -0.35, 0.07)
	tween.tween_property(_visual, "position:x", 0.0, 0.08)
	_shake_camera(0.9)
	if is_instance_valid(_target) and not _target.is_dead:
		_target.take_damage(shake_damage, global_position, "shake")
		var away := signf(_target.global_position.x - global_position.x)
		if away == 0.0:
			away = -1.0
		_target.velocity += Vector3(away * shake_impulse, 4.0, 0.0)
	state = State.WAITING
	_timer = attack_interval


func _shake_camera(strength: float) -> void:
	if not is_instance_valid(_target):
		return
	var cam := _target.get_node_or_null("Camera3D")
	if cam and cam.has_method("shake"):
		cam.shake(strength)


## Knocked off the table on its way out.
func _drop_spoils() -> void:
	for spoil in [["heart", 2.0, -2.2], ["heart", 2.0, 0.4], ["energy", 50.0, 2.6]]:
		var reward := RewardPickup3D.new()
		reward.kind = spoil[0]
		reward.amount = spoil[1]
		reward.lifetime = 0.0
		get_parent().add_child(reward)
		reward.global_position = Vector3(global_position.x - 6.0 + spoil[2], 1.2, 0.0)


func _acquire_target() -> bool:
	if not is_instance_valid(_target):
		_target = null
		for node in get_tree().get_nodes_in_group("player"):
			_target = node
			break
	return _target != null


func _on_damage_shrugged(_amount: int, _from_position: Vector3) -> void:
	Fx.impact_text(get_parent(), global_position + Vector3(0, 1.0, 0),
		Color(0.75, 0.8, 0.9), "NOT THERE!", 0.7)


func _on_damaged(_amount: int, _from_position: Vector3) -> void:
	var tween := create_tween()
	tween.tween_property(_visual, "position:y", _visual.position.y + 0.4, 0.07)
	tween.tween_property(_visual, "position:y", _visual.position.y, 0.2)


func _on_defeated() -> void:
	state = State.RETREATING
	_timer = 1.8
	_drop_spoils()
	Snd.sfx("squeak", 6.0)
	if is_instance_valid(_paw):
		_paw.set_vulnerable(false)
		_paw.queue_free()
		_paw = null
	var tween := create_tween()
	tween.tween_property(_visual, "position:y", _visual.position.y + 9.0, 1.5
		).set_ease(Tween.EASE_IN)


## Head and eyes only. At cockroach scale a whole cat is off-screen anyway, and
## the head is the part that reads as a threat.
func _build_cat() -> Node3D:
	var root := Node3D.new()
	var fur := Block3D.textured_material(Color(0.34, 0.31, 0.32), "speckle", 2.4)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 3.2
	head_mesh.height = 5.6
	head_mesh.material = fur
	head.mesh = head_mesh
	root.add_child(head)
	for side in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var ear_mesh := CylinderMesh.new()
		ear_mesh.top_radius = 0.02
		ear_mesh.bottom_radius = 1.1
		ear_mesh.height = 1.9
		ear_mesh.radial_segments = 3
		ear_mesh.material = fur
		ear.mesh = ear_mesh
		ear.position = Vector3(side * 1.6, 3.1, -0.2)
		ear.rotation.z = side * -0.25
		root.add_child(ear)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.62
		eye_mesh.height = 1.1
		var eye_mat := Block3D.flat_material(Color(0.95, 0.85, 0.25))
		eye_mat.emission_enabled = true
		eye_mat.emission = Color(0.95, 0.8, 0.2)
		eye_mat.emission_energy_multiplier = 1.3
		eye_mesh.material = eye_mat
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 1.25, 0.7, 2.7)
		eye.set_meta("base_x", eye.position.x)
		root.add_child(eye)
		_eyes.append(eye)
		var slit := MeshInstance3D.new()
		var slit_mesh := BoxMesh.new()
		slit_mesh.size = Vector3(0.12, 0.9, 0.2)
		slit_mesh.material = Block3D.flat_material(Color(0.05, 0.04, 0.05))
		slit.mesh = slit_mesh
		slit.position = Vector3(side * 1.25, 0.7, 3.2)
		root.add_child(slit)
	var nose := MeshInstance3D.new()
	var nose_mesh := SphereMesh.new()
	nose_mesh.radius = 0.42
	nose_mesh.height = 0.6
	nose_mesh.material = Block3D.flat_material(Color(0.85, 0.5, 0.52))
	nose.mesh = nose_mesh
	nose.position = Vector3(0, -0.7, 3.1)
	root.add_child(nose)
	return root
