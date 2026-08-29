class_name MagpieBoss3D
extends BaseBoss3D

## THE MAGPIE, on the gable at the end of the roof. The eighth boss, eighth
## verb: it only lands to GLOAT.
##
## It is a THIEF. It rides the gusts out of reach, swoops on the wind's
## rhythm, and a swoop that touches him STEALS coins (or pecks him bloody if
## he is broke). Then greed does what greed does: it lands on its gloat perch
## to crow over the haul, and that strut is the only time it can be hurt —
## every hit shakes stolen coins back out of it. A swoop he DODGES leaves it
## tumbling across the tiles, which is the second opening. Patience and
## punished greed, nothing else works.
##
## Eight bosses, eight questions:
##   rat = when · Granny = don't be hit · cat = what · Queen = something else
##   first · mantis = from where · wasp = stand where · toad = what you feed
##   it · magpie = punish the GLOAT

enum State { PERCH, SWOOP, GLOAT, CRASH, RETREATING, GONE }

@export_group("Encounter")
@export var notice_range := 13.0
@export var swoop_interval := 4.2
@export var swoop_speed := 11.0
@export var steal_radius := 1.1
## Coins one successful swoop takes.
@export var steal_count := 3
@export var peck_damage := 1
## How long it struts after a theft — the punish window.
@export var gloat_time := 3.2
## And how long a whiffed swoop leaves it sprawled.
@export var crash_time := 2.0
## Where it sits between swoops, relative to spawn.
@export var perch_offset := Vector3(0.0, 4.6, 0.0)
## Where it gloats: down on the tiles, in reach, drunk on shininess.
@export var gloat_offset := Vector3(-3.0, 0.0, 0.0)

var state := State.PERCH

var _timer := 2.0
var _target: Node3D
var _visual: Node3D
var _wing_pivots: Array[Node3D] = []
var _wing_beat := 0.0
var _hoard := 0
var _swoop_from := Vector3.ZERO
var _swoop_aim := Vector3.ZERO
var _swoop_t := 0.0
var _stole_this_swoop := false


func _ready() -> void:
	super()
	boss_rule = "A THIEF. It only lands to GLOAT - that's when you take it back!"
	immune_to_damage = true # out of reach on the wing; the gloat drops this
	summon_count = 0 # thieves work alone
	_visual = _build_magpie()
	add_child(_visual)
	global_position = arena_origin + perch_offset


func _physics_process(delta: float) -> void:
	if state == State.GONE:
		return
	_timer -= delta
	_wing_beat += delta * (26.0 if state == State.SWOOP else 3.0)
	for pivot in _wing_pivots:
		pivot.rotation.z = signf(pivot.position.z) * \
			(0.5 + sin(_wing_beat) * (0.65 if state == State.SWOOP else 0.12))
	match state:
		State.PERCH:
			# Bobbing on the perch, head cocked at everything shiny below.
			global_position = global_position.lerp(
				arena_origin + perch_offset + Vector3(0, sin(_wing_beat * 2.0) * 0.15, 0),
				minf(4.0 * delta, 1.0))
			if not _acquire_target():
				return
			if absf(_target.global_position.x - global_position.x) <= notice_range:
				engage()
				if _timer <= 0.0:
					_begin_swoop()
		State.SWOOP:
			_swoop_t = minf(_swoop_t + delta * swoop_speed / maxf(
				_swoop_from.distance_to(_swoop_aim), 0.1), 1.0)
			# A quadratic dip: down through his height and up again, so the
			# steal happens at the bottom of the arc where he lives.
			var flat := _swoop_from.lerp(_swoop_aim, _swoop_t)
			flat.y -= sin(_swoop_t * PI) * 1.2
			global_position = flat
			if not _stole_this_swoop and is_instance_valid(_target) \
					and _target.global_position.distance_to(global_position) <= steal_radius:
				_steal()
			if _swoop_t >= 1.0:
				if _stole_this_swoop:
					_gloat()
				else:
					_crash()
		State.GLOAT:
			if _timer <= 0.0:
				_take_wing()
		State.CRASH:
			if _timer <= 0.0:
				_take_wing()
		State.RETREATING:
			if _timer <= 0.0:
				state = State.GONE


func _acquire_target() -> bool:
	if not is_instance_valid(_target):
		_target = null
		for node in get_tree().get_nodes_in_group("player"):
			_target = node
			break
	return _target != null


func _begin_swoop() -> void:
	if not is_instance_valid(_target):
		return
	state = State.SWOOP
	_stole_this_swoop = false
	_swoop_t = 0.0
	_swoop_from = global_position
	# Committed to where he IS at launch; moving after that dodges it.
	_swoop_aim = Vector3(_target.global_position.x, _target.global_position.y, 0.0) \
		+ Vector3(signf(global_position.x - _target.global_position.x) * -2.4, 0.4, 0.0)
	_swoop_aim.x = clampf(_swoop_aim.x, arena_bounds().x + 0.8, arena_bounds().y - 0.8)
	Snd.sfx("whoosh", -2.0, 0.15)
	Fx.impact_text(get_parent(), global_position + Vector3(0, 1.0, 0),
		Color(0.8, 0.85, 1.0), "KRAA!", 0.6)


func _steal() -> void:
	_stole_this_swoop = true
	var taken := 0
	for i in steal_count:
		if SaveGame.spend_coins(1):
			taken += 1
	if taken > 0:
		_hoard += taken
		Snd.sfx("locked", -2.0, 0.2)
		Fx.impact_text(get_parent(), global_position + Vector3(0, 1.2, 0),
			Color(1.0, 0.85, 0.35), "MINE! %d COINS!" % taken, 0.9)
		if _target.has_signal("coins_changed"):
			_target.coins_changed.emit(SaveGame.coins())
	else:
		# Broke. It takes its payment out of his shell instead.
		if _target.has_method("take_damage"):
			_target.take_damage(peck_damage, global_position, "magpie")
		Snd.sfx("impact_light", -2.0)


## Down on the tiles, strutting over the haul — hittable, finally.
func _gloat() -> void:
	state = State.GLOAT
	_timer = gloat_time
	immune_to_damage = false
	global_position = arena_origin + gloat_offset
	global_position.z = 0.0
	Snd.sfx("locked", -6.0, 0.3)
	Fx.impact_text(get_parent(), global_position + Vector3(0, 1.6, 0),
		Color(1.0, 0.85, 0.35), "IT'S GLOATING - NOW!", 0.9)


## A dodged swoop ends in the tiles, sprawled and just as hittable.
func _crash() -> void:
	state = State.CRASH
	_timer = crash_time
	immune_to_damage = false
	global_position.y = arena_origin.y + 0.4
	global_position.z = 0.0
	Snd.sfx("impact_light", 0.0, 0.2)
	Fx.spark_burst(get_parent(), global_position, Color(0.7, 0.75, 0.85))
	Fx.impact_text(get_parent(), global_position + Vector3(0, 1.4, 0),
		Color(0.85, 0.95, 0.8), "IT TUMBLED!", 0.8)
	var sprawl := create_tween()
	sprawl.tween_property(_visual, "rotation:z", 0.9, 0.15)
	sprawl.tween_interval(crash_time - 0.5)
	sprawl.tween_property(_visual, "rotation:z", 0.0, 0.25)


func _take_wing() -> void:
	immune_to_damage = true
	state = State.PERCH
	_timer = swoop_interval
	Snd.sfx("whoosh", -4.0, 0.2)


## Every hit that lands shakes stolen coins back out of it.
func _on_damaged(_amount: int, _from_position: Vector3) -> void:
	Fx.hit_flash(_visual, Color(1.0, 0.9, 0.85))
	Snd.sfx("impact_light", -3.0) # a magpie cry can drop in over this later
	var shake := mini(_hoard, 2)
	_drop_coins(shake)


func _on_damage_shrugged(_amount: int, _from_position: Vector3) -> void:
	Fx.impact_text(get_parent(), global_position + Vector3(0, 1.4, 0),
		Color(0.85, 0.9, 1.0), "ON THE WING - WAIT!", 0.7)


func _drop_coins(count: int) -> void:
	if count <= 0:
		return
	_hoard -= count
	var scene := load("res://items/rewards/coin_3d.tscn") as PackedScene
	if scene == null:
		return
	for i in count:
		var coin := scene.instantiate()
		get_parent().add_child(coin)
		(coin as Node3D).global_position = global_position \
			+ Vector3(-1.0 + i * 1.0, 0.6, 0.0)
		(coin as Node3D).global_position.z = 0.0


func _on_defeated() -> void:
	state = State.RETREATING
	_timer = 1.4
	immune_to_damage = true
	# Everything it ever took, plus interest from the base coin drop.
	_drop_coins(_hoard)
	Snd.sfx("whoosh", 2.0)
	Fx.ghost(get_parent(), global_position, 1.2, 6)
	var tween := create_tween()
	tween.tween_property(self, "global_position",
		global_position + Vector3(6.0, 12.0, -8.0), 1.3).set_ease(Tween.EASE_IN)


## Black and white with a blue-green sheen, long tail, one greedy eye glint.
func _build_magpie() -> Node3D:
	var root := Node3D.new()
	var black := Block3D.flat_material(Color(0.1, 0.1, 0.13))
	black.roughness = 0.35
	var white := Block3D.flat_material(Color(0.92, 0.93, 0.95))
	var sheen := Block3D.flat_material(Color(0.15, 0.3, 0.4))
	sheen.metallic = 0.4
	sheen.roughness = 0.3

	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.55
	body_mesh.height = 1.0
	body_mesh.material = black
	body.mesh = body_mesh
	body.position = Vector3(0, 0.7, 0)
	body.scale = Vector3(1.5, 0.9, 0.9)
	root.add_child(body)

	var belly := MeshInstance3D.new()
	var belly_mesh := SphereMesh.new()
	belly_mesh.radius = 0.4
	belly_mesh.height = 0.7
	belly_mesh.material = white
	belly.mesh = belly_mesh
	belly.position = Vector3(0.1, 0.55, 0)
	belly.scale = Vector3(1.3, 0.7, 0.8)
	root.add_child(belly)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.34
	head_mesh.height = 0.6
	head_mesh.material = black
	head.mesh = head_mesh
	head.position = Vector3(0.75, 1.15, 0)
	root.add_child(head)

	var beak := MeshInstance3D.new()
	var beak_mesh := CylinderMesh.new()
	beak_mesh.top_radius = 0.02
	beak_mesh.bottom_radius = 0.1
	beak_mesh.height = 0.45
	beak_mesh.radial_segments = 6
	beak_mesh.material = Block3D.flat_material(Color(0.2, 0.2, 0.22))
	beak.mesh = beak_mesh
	beak.rotation.z = -PI / 2.0
	beak.position = Vector3(1.15, 1.1, 0)
	root.add_child(beak)

	var eye_mat := Block3D.flat_material(Color(0.05, 0.05, 0.06))
	var glint_mat := Block3D.flat_material(Color(1.0, 0.95, 0.7))
	glint_mat.emission_enabled = true
	glint_mat.emission = Color(1.0, 0.9, 0.5)
	glint_mat.emission_energy_multiplier = 1.4
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.09
		eye_mesh.height = 0.16
		eye_mesh.radial_segments = 6
		eye_mesh.rings = 3
		eye_mesh.material = eye_mat
		eye.mesh = eye_mesh
		eye.position = Vector3(0.9, 1.25, side * 0.16)
		root.add_child(eye)
		# The glint: a thief's eye is never dull.
		var glint := MeshInstance3D.new()
		var glint_mesh := SphereMesh.new()
		glint_mesh.radius = 0.03
		glint_mesh.height = 0.05
		glint_mesh.radial_segments = 4
		glint_mesh.rings = 2
		glint_mesh.material = glint_mat
		glint.mesh = glint_mesh
		glint.position = Vector3(0.96, 1.29, side * 0.14)
		root.add_child(glint)

	# The tail: the magpie's whole silhouette, iridescent and too long.
	var tail := MeshInstance3D.new()
	var tail_mesh := BoxMesh.new()
	tail_mesh.size = Vector3(1.6, 0.08, 0.3)
	tail_mesh.material = sheen
	tail.mesh = tail_mesh
	tail.position = Vector3(-1.2, 0.85, 0)
	tail.rotation.z = 0.25
	root.add_child(tail)

	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.0, 0.95, side * 0.3)
		root.add_child(pivot)
		_wing_pivots.append(pivot)
		var wing := MeshInstance3D.new()
		var wing_mesh := BoxMesh.new()
		wing_mesh.size = Vector3(0.9, 0.06, 1.1)
		wing_mesh.material = sheen
		wing.mesh = wing_mesh
		wing.position = Vector3(-0.1, 0.0, side * 0.55)
		pivot.add_child(wing)
		var tip := MeshInstance3D.new()
		var tip_mesh := BoxMesh.new()
		tip_mesh.size = Vector3(0.7, 0.05, 0.5)
		tip_mesh.material = white
		tip.mesh = tip_mesh
		tip.position = Vector3(-0.2, 0.01, side * 1.2)
		pivot.add_child(tip)

	# Stub legs for the strut.
	for fore in [0.25, -0.15]:
		var leg := MeshInstance3D.new()
		var leg_mesh := CylinderMesh.new()
		leg_mesh.top_radius = 0.05
		leg_mesh.bottom_radius = 0.04
		leg_mesh.height = 0.5
		leg_mesh.radial_segments = 5
		leg_mesh.material = Block3D.flat_material(Color(0.25, 0.22, 0.2))
		leg.mesh = leg_mesh
		leg.position = Vector3(fore, 0.2, 0)
		root.add_child(leg)
	return root
