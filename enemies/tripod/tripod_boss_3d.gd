class_name TripodBoss3D
extends BaseBoss3D

## THE WAR TRIPOD, striding the last red mile. Fourteenth boss, final verb:
## TOPPLE.
##
## Its eye burns far above the plane a roach fights on — out of reach by
## definition. What IS in reach: three knees, one per leg, at exactly swing
## height. Break all three and the whole tower comes down on its face, eye
## in the dust, mortal, until it hauls itself back up on repaired legs.
## Bring the fight DOWN to your world: the smallest thing on two planets
## fells the tallest, which is the only way this story was ever going to end.
##
## Fourteen bosses: rat = when · Granny = don't be hit · cat = what · Queen =
## something else first · mantis = from where · wasp = stand where · toad =
## feed · magpie = gloat · snail = flip · owl = freeze · probe = reflect ·
## worm = unbury · janitor = clog · tripod = TOPPLE.

enum State { STRIDE, CRASHED, RISING, GONE }

@export_group("Encounter")
@export var notice_range := 15.0
@export var stride_speed := 1.1
## Where the eye rides while it stands, and how long it lies fallen.
@export var eye_height := 5.6
@export var crashed_seconds := 6.0
## The heat ray: telegraph, then a strike on the marked column.
@export var ray_interval := 3.4
@export var ray_telegraph := 0.9
@export var ray_damage := 1

var state := State.STRIDE

var _timer := 0.0
var _ray_timer := 2.0
var _ray_x := 0.0
var _ray_armed := false
var _target: Node3D
var _visual: Node3D
var _eye: Node3D
var _legs: Array[Node3D] = []
var _leg_lean: Array[float] = []
var _leg_sin: Array[float] = [0.0, 0.0, 0.0]
var _knees: Array[Node] = []
var _shape: CollisionShape3D
var _time := 0.0
## Hits it takes lying down before hauling itself up early: a fast mash must
## not empty the final boss in a single topple.
var _crash_hits := 0


## A knee joint at swing height: the one part of the tower a roach can argue
## with. AnimatableBody3D on the enemy layer, per the Area3D gotcha.
class Knee3D:
	extends AnimatableBody3D

	## Untyped, and never referring to the outer class by name: an inner
	## class naming its own outer class_name sent Godot's class loader into
	## a cycle and HUNG the engine at startup, with no error printed.
	var tripod
	var hits_left := 2
	var buckled := false
	var _mesh: MeshInstance3D

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.9, 1.1, 0.9)
		shape.shape = box
		add_child(shape)
		_mesh = MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.42
		mesh.height = 0.8
		mesh.radial_segments = 8
		mesh.rings = 4
		var mat := Block3D.flat_material(Color(0.75, 0.5, 0.3))
		mat.emission_enabled = true
		mat.emission = Color(0.9, 0.45, 0.2)
		mat.emission_energy_multiplier = 0.7
		mesh.material = mat
		_mesh.mesh = mesh
		add_child(_mesh)

	func take_damage(_amount: int, from_position: Vector3, _cause := "") -> void:
		if buckled or (is_instance_valid(tripod)
				and not tripod.knees_strikeable()):
			return
		hits_left -= 1
		Fx.hit_flash(_mesh, Color(1.0, 0.8, 0.5))
		Snd.sfx("impact_light", -2.0, 0.2)
		if hits_left > 0:
			Fx.spark_burst(get_parent(), global_position, Color(1.0, 0.7, 0.3))
			return
		buckled = true
		_mesh.scale = Vector3(1.3, 0.4, 1.3)
		Fx.impact_text(get_parent(), global_position + Vector3(0, 1.2, 0),
			Color(1.0, 0.75, 0.4), "KNEE DOWN!", 0.8)
		Snd.sfx("impact_heavy", -2.0, 0.1)
		if is_instance_valid(tripod):
			tripod._on_knee_buckled(from_position)

	func restore() -> void:
		buckled = false
		hits_left = 2
		_mesh.scale = Vector3.ONE


func _ready() -> void:
	super()
	boss_rule = "The eye rides too HIGH to touch. Break all THREE knees - bring it DOWN!"
	immune_to_damage = false # altitude does the guarding, in take_damage
	summon_count = 0
	_visual = _build_tripod()
	add_child(_visual)
	_shape = get_node_or_null("CollisionShape3D")
	if _shape:
		_shape.position.y = eye_height
	call_deferred("_spawn_knees") # siblings: not during our own _ready


func _physics_process(delta: float) -> void:
	if state == State.GONE:
		return
	_time += delta
	_timer -= delta
	match state:
		State.STRIDE:
			if not _acquire_target():
				return
			var dx := _target.global_position.x - global_position.x
			if absf(dx) <= notice_range:
				engage()
			if not engaged:
				return
			global_position.x = clampf(
				move_toward(global_position.x, _target.global_position.x,
					stride_speed * delta),
				arena_bounds().x + 2.6, arena_bounds().y - 2.6)
			_visual.position.y = absf(sin(_time * 2.1)) * 0.16
			_visual.rotation.z = sin(_time * 1.4) * 0.035
			_stride_gait(delta)
			_place_knees()
			_heat_ray(delta)
		State.CRASHED:
			if _timer <= 0.0:
				state = State.RISING
				_timer = 1.4
				Snd.sfx("whoosh", -2.0, 0.1)
		State.RISING:
			var t := 1.0 - clampf(_timer / 1.4, 0.0, 1.0)
			_visual.position.y = lerpf(-eye_height + 0.7, 0.0, t)
			_visual.rotation.z = lerpf(0.45, 0.0, t)
			if _shape:
				_shape.position.y = lerpf(0.8, eye_height, t)
			if _timer <= 0.0:
				for knee in _knees:
					if is_instance_valid(knee):
						knee.restore()
				state = State.STRIDE


## Altitude does the guarding: standing, the eye is simply not where swings
## happen. Fallen, it is exactly where they happen.
func take_damage(amount: int, from_position: Vector3, _cause := "") -> void:
	engage()
	if state == State.CRASHED:
		lose_health(amount, from_position)
		_crash_hits += 1
		if _crash_hits >= 3 and health > 0:
			state = State.RISING
			_timer = 1.4
			Snd.sfx("whoosh", -2.0, 0.1)
	else:
		_on_damage_shrugged(amount, from_position)


## Duck-typed for the knees, so they never name this class (see Knee3D).
func knees_strikeable() -> bool:
	return state == State.STRIDE


func _on_knee_buckled(_from_position: Vector3) -> void:
	var standing := 0
	for knee in _knees:
		if is_instance_valid(knee) and not knee.buckled:
			standing += 1
	if standing > 0:
		return
	# Three knees gone: TIMBER.
	state = State.CRASHED
	_crash_hits = 0
	_timer = crashed_seconds
	_ray_armed = false
	_visual.position.y = -eye_height + 0.7
	_visual.rotation.z = 0.45
	if _shape:
		_shape.position.y = 0.8
	Snd.sfx("impact_heavy", 4.0, 0.05)
	Fx.spark_burst(get_parent(), Vector3(global_position.x, 0.6, 0.0),
		Color(0.9, 0.5, 0.3))
	Fx.impact_text(get_parent(), Vector3(global_position.x, 2.2, 0.0),
		Color(1.0, 0.85, 0.4), "IT FALLS!", 1.1)
	var quake := get_tree().get_first_node_in_group("player")
	if quake is Node3D:
		var cam: Node = (quake as Node).get_node_or_null("Camera3D")
		if cam and cam.has_method("shake"):
			cam.shake(0.4)


## The walk: each stilt swings on its hip a third of a cycle apart, and a
## stilt PLANTING is a footfall - thud, dust, and a tremor if he is close.
func _stride_gait(_delta: float) -> void:
	for i in _legs.size():
		var phase := _time * 2.1 + float(i) * TAU / 3.0
		var s := sin(phase)
		_legs[i].rotation.z = _leg_lean[i] + s * 0.13
		if _leg_sin[i] > -0.96 and s <= -0.96:
			_footfall(i)
		_leg_sin[i] = s


func _footfall(leg_index: int) -> void:
	Snd.sfx("impact_heavy", -14.0, 0.25)
	if leg_index < _knees.size() and is_instance_valid(_knees[leg_index]):
		Fx.spark_burst(get_parent(),
			_knees[leg_index].global_position + Vector3(0, -0.4, 0),
			Color(0.7, 0.4, 0.25))
	if is_instance_valid(_target):
		if absf(_target.global_position.x - global_position.x) < 9.0:
			var cam: Node = _target.get_node_or_null("Camera3D")
			if cam and cam.has_method("shake"):
				cam.shake(0.07)


## The knees track their legs: at swing height, spread under the hub.
func _place_knees() -> void:
	var spread := [-2.4, 0.0, 2.4]
	for i in _knees.size():
		var knee: Node = _knees[i]
		if not is_instance_valid(knee):
			continue
		knee.global_position = Vector3(
			global_position.x + float(spread[i]) + sin(_time * 1.6 + float(i) * 2.1) * 0.3,
			arena_origin.y + 0.7, 0.0)


## Telegraph a column of light on him, then strike it. Standing still through
## the whole windup is the only way to be hit - it teaches feet, not luck.
func _heat_ray(delta: float) -> void:
	_ray_timer -= delta
	if not _ray_armed and _ray_timer <= 0.0:
		_ray_armed = true
		_ray_timer = ray_telegraph
		_ray_x = _target.global_position.x
		Fx.impact_text(get_parent(), Vector3(_ray_x, 2.6, 0.0),
			Color(1.0, 0.5, 0.3), "!", 0.9)
		Snd.sfx("sizzle", -3.0, 0.3)
	elif _ray_armed and _ray_timer <= 0.0:
		_ray_armed = false
		_ray_timer = ray_interval
		Fx.spark_burst(get_parent(), Vector3(_ray_x, 1.0, 0.0), Color(1.0, 0.4, 0.2))
		Snd.sfx("sizzle", 2.0, 0.1)
		if is_instance_valid(_target) \
				and absf(_target.global_position.x - _ray_x) < 1.1 \
				and _target.has_method("take_damage"):
			_target.take_damage(ray_damage, Vector3(_ray_x, 6.0, 0.0), "the heat ray")


func _spawn_knees() -> void:
	for i in 3:
		var knee := Knee3D.new()
		knee.tripod = self
		get_parent().add_child(knee)
		_knees.append(knee)
	_place_knees()


func _acquire_target() -> bool:
	if not is_instance_valid(_target):
		_target = null
		for node in get_tree().get_nodes_in_group("player"):
			_target = node
			break
	return _target != null


func _on_damaged(_amount: int, _from_position: Vector3) -> void:
	Fx.hit_flash(_eye if _eye else _visual, Color(1.0, 0.6, 0.5))
	Snd.sfx("impact_light", -3.0, 0.2)


func _on_defeated() -> void:
	state = State.GONE
	for knee in _knees:
		if is_instance_valid(knee):
			knee.queue_free()
	Snd.sfx("impact_heavy", 3.0)
	Fx.ghost(get_parent(), global_position + Vector3(0, 1.0, 0), 1.4, 8)
	Fx.shatter(get_parent(), _visual, 8.0)


## Hub, hooded eye, three long legs. Built standing; the crash lays the whole
## visual down by moving and tilting the root.
func _build_tripod() -> Node3D:
	var root := Node3D.new()
	var hull := Block3D.flat_material(Color(0.45, 0.4, 0.42))
	var hub := MeshInstance3D.new()
	var hub_mesh := SphereMesh.new()
	hub_mesh.radius = 1.3
	hub_mesh.height = 1.8
	hub_mesh.radial_segments = 10
	hub_mesh.rings = 5
	hub_mesh.material = hull
	hub.mesh = hub_mesh
	hub.position.y = eye_height
	root.add_child(hub)
	_eye = MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.5
	eye_mesh.height = 1.0
	eye_mesh.radial_segments = 8
	eye_mesh.rings = 4
	var eye_mat := Block3D.flat_material(Color(1.0, 0.35, 0.2))
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.3, 0.15)
	eye_mat.emission_energy_multiplier = 1.8
	eye_mesh.material = eye_mat
	(_eye as MeshInstance3D).mesh = eye_mesh
	_eye.position = Vector3(0, eye_height - 0.2, 0.9)
	root.add_child(_eye)
	for i in 3:
		var x: float = [-2.4, 0.0, 2.4][i]
		# A pivot at the hip: the WHOLE stilt swings from up there, which is
		# what makes the walk read as a walker and not a slide (user's call:
		# like the War of the Worlds).
		var hip := Node3D.new()
		hip.position = Vector3(float(x) * 0.25, eye_height, [0.4, -0.5, 0.4][i])
		var leg := MeshInstance3D.new()
		var leg_mesh := CylinderMesh.new()
		leg_mesh.top_radius = 0.16
		leg_mesh.bottom_radius = 0.1
		leg_mesh.height = eye_height
		leg_mesh.radial_segments = 6
		leg_mesh.material = hull
		leg.mesh = leg_mesh
		leg.position = Vector3(0, -eye_height * 0.5, 0)
		hip.add_child(leg)
		hip.rotation.z = -atan2(float(x), eye_height)
		root.add_child(hip)
		_legs.append(hip)
		_leg_lean.append(hip.rotation.z)
	return root
