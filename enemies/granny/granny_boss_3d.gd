class_name GrannyBoss3D
extends BaseBoss3D

## GRANNY. A level-ending encounter that is deliberately NOT a boss fight in the
## usual sense: GAME.md §11 keeps her a human-scale catastrophe, and the brief is
## explicit that she must not become another damage sponge with a health bar.
##
## So nothing you carry can hurt her. What you whittle down is her PATIENCE, and
## it only goes down when she MISSES. You beat Granny by not being hit — dodging
## is the attack. That makes her the opposite of the rat, who is beaten by
## landing hits in his recovery window.
##
## Every attack comes from above, telegraphs on the floor first, and damages
## exactly the circle it drew. The telegraph radius and the damage radius are
## the same number, passed to both, never two numbers that have to agree.

enum State { HIDDEN, RISING, SHOCKED, WAITING, TELEGRAPHING, STRIKING, RETREATING, GONE }

@export_group("Encounter")
## How close Harry has to get before she notices him over the counter.
@export var notice_range := 9.0
@export var rise_time := 0.9
@export var shock_time := 1.1
## Breather between attacks. Short enough to stay tense, long enough to move.
@export var attack_interval := 2.6

@export_group("Attacks")
@export var telegraph_time := 1.15
@export var swat_radius := 1.35
@export var swat_damage := 2
@export var stomp_radius := 2.1
@export var stomp_damage := 3
@export var water_radius := 2.4
@export var water_damage := 1
@export var spray_radius := 1.7
@export var spray_damage := 1
@export var spray_duration := 5.0

var state := State.HIDDEN

var _timer := 0.0
var _attack_index := 0
var _eeked := false
var _hidden_y := 0.0
var _visual: Node3D
var _mouth: MeshInstance3D
var _target: Node3D

## Attacks cycle rather than being random, so the encounter is learnable — the
## brief asks for a fair avoidance window, and fair means predictable.
const ROTATION := ["swat", "stomp", "water", "spray"]


func _ready() -> void:
	super()
	immune_to_damage = true
	_visual = _build_granny()
	add_child(_visual)
	_hidden_y = -2.6
	_visual.position.y = _hidden_y # ducked down behind the counter


func _physics_process(delta: float) -> void:
	if state == State.GONE:
		return
	_timer -= delta
	match state:
		State.HIDDEN:
			if _acquire_target() and absf(_target.global_position.x - global_position.x) < notice_range:
				state = State.RISING
				_timer = rise_time
				var tween := create_tween()
				tween.tween_property(_visual, "position:y", 0.0, rise_time
					).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		State.RISING:
			if _timer <= 0.0:
				_shock()
		State.SHOCKED:
			if _timer <= 0.0:
				state = State.WAITING
				_timer = attack_interval * 0.5
		State.WAITING:
			if _timer <= 0.0:
				_begin_attack()
		State.TELEGRAPHING, State.STRIKING:
			pass # driven by their own tweens
		State.RETREATING:
			if _timer <= 0.0:
				state = State.GONE


## She spots him, recoils, and shrieks — once per encounter.
func _shock() -> void:
	state = State.SHOCKED
	_timer = shock_time
	engage()
	if not _eeked:
		_eeked = true
		Snd.sfx("granny_eek", 4.0, 0.05)
	if _mouth:
		var tween := create_tween()
		tween.tween_property(_mouth, "scale", Vector3(1.0, 2.2, 1.0), 0.12)
		tween.tween_property(_mouth, "scale", Vector3.ONE, 0.5)
	var recoil := create_tween()
	recoil.tween_property(_visual, "rotation:z", 0.22, 0.1)
	recoil.tween_property(_visual, "rotation:z", 0.0, 0.35)


func _begin_attack() -> void:
	if not _acquire_target():
		state = State.WAITING
		_timer = attack_interval
		return
	var kind: String = ROTATION[_attack_index % ROTATION.size()]
	_attack_index += 1
	state = State.TELEGRAPHING
	match kind:
		"swat":
			_telegraph_and_strike(swat_radius, swat_damage, Color(0.9, 0.35, 0.3), _do_swat)
		"stomp":
			_telegraph_and_strike(stomp_radius, stomp_damage, Color(0.6, 0.5, 0.45), _do_stomp)
		"water":
			_telegraph_and_strike(water_radius, water_damage, Color(0.45, 0.7, 1.0), _do_water)
		"spray":
			_telegraph_and_strike(spray_radius, spray_damage, Color(0.5, 0.9, 0.3), _do_spray)


## Draws the circle, waits, then hands the SAME radius to whatever lands. The
## visible warning and the damaging area cannot disagree because they are one
## number.
func _telegraph_and_strike(radius: float, damage: int, tint: Color, strike: Callable) -> void:
	var aim := _target.global_position
	var marker := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.03
	disc.radial_segments = 20
	var mat := Block3D.flat_material(Color(tint.r, tint.g, tint.b, 0.34))
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 0.9
	disc.material = mat
	marker.mesh = disc
	get_parent().add_child(marker)
	marker.global_position = aim + Vector3(0, 0.04, 0)
	# Grow from nothing to full so the timing is readable, not just the place.
	marker.scale = Vector3(0.15, 1.0, 0.15)
	var tween := marker.create_tween()
	tween.tween_property(marker, "scale", Vector3.ONE, telegraph_time)
	await get_tree().create_timer(telegraph_time).timeout
	if state == State.GONE or is_defeated:
		marker.queue_free()
		return
	marker.queue_free()
	state = State.STRIKING
	strike.call(aim, radius, damage)
	state = State.WAITING
	_timer = attack_interval


## Did it land? Anything else is a miss, and a miss costs her patience.
func _resolve(aim: Vector3, radius: float, damage: int) -> bool:
	# Explicit bool: _target is an untyped Node3D, so `.is_dead` is a Variant and
	# the inferred type of the whole expression is unknowable to the parser.
	var hit: bool = is_instance_valid(_target) and not _target.is_dead \
		and _target.global_position.distance_to(aim) <= radius
	if hit:
		_target.take_damage(damage, aim)
	else:
		lose_health(1, aim) # she is losing her temper, not her health
		Fx.impact_text(get_parent(), aim + Vector3(0, 0.8, 0),
			Color(1.0, 0.85, 0.4), "MISSED!", 0.8)
	return hit


func _do_swat(aim: Vector3, radius: float, damage: int) -> void:
	var swatter := MeshInstance3D.new()
	var paddle := BoxMesh.new()
	paddle.size = Vector3(radius * 1.5, 0.08, radius * 1.5)
	paddle.material = Block3D.flat_material(Color(0.85, 0.3, 0.25))
	swatter.mesh = paddle
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.05
	handle_mesh.bottom_radius = 0.05
	handle_mesh.height = 2.2
	handle_mesh.material = Block3D.flat_material(Color(0.6, 0.55, 0.5))
	handle.mesh = handle_mesh
	handle.position = Vector3(0, 1.1, 0)
	swatter.add_child(handle)
	get_parent().add_child(swatter)
	swatter.global_position = aim + Vector3(0, 8.0, 0)
	var tween := swatter.create_tween()
	tween.tween_property(swatter, "global_position", aim + Vector3(0, 0.1, 0), 0.09
		).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_resolve(aim, radius, damage)
		Snd.sfx("granny_swat", 4.0)
		Fx.spark_burst(get_parent(), aim + Vector3(0, 0.3, 0), Color(0.9, 0.6, 0.5))
		_shake(0.45))
	tween.tween_interval(0.3)
	tween.tween_callback(swatter.queue_free)


func _do_stomp(aim: Vector3, radius: float, damage: int) -> void:
	var shoe := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(radius * 1.4, 0.5, radius * 1.1)
	mesh.material = Block3D.textured_material(Color(0.28, 0.22, 0.2), "speckle", 1.2)
	shoe.mesh = mesh
	get_parent().add_child(shoe)
	shoe.global_position = aim + Vector3(0, 9.0, 0)
	var tween := shoe.create_tween()
	tween.tween_property(shoe, "global_position", aim + Vector3(0, 0.25, 0), 0.13
		).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_resolve(aim, radius, damage)
		Snd.sfx("granny_stomp", 6.0)
		Fx.spark_burst(get_parent(), aim + Vector3(0, 0.2, 0), Color(0.7, 0.65, 0.6))
		_shake(0.7)) # the heaviest thing she does, and it feels it
	tween.tween_interval(0.45)
	tween.tween_property(shoe, "global_position", aim + Vector3(0, 9.0, 0), 0.5)
	tween.tween_callback(shoe.queue_free)


## A bucket of water: barely hurts, but it knocks him flying and leaves the
## floor slick.
func _do_water(aim: Vector3, radius: float, damage: int) -> void:
	Snd.sfx("water_splash", 2.0)
	_resolve(aim, radius, damage)
	Fx.spark_burst(get_parent(), aim + Vector3(0, 0.3, 0), Color(0.6, 0.85, 1.0))
	_shake(0.3)
	var slick := HazardPool3D.new()
	slick.damage = 0 # water is a shove and a nuisance, not acid
	slick.tick_interval = 1.0
	slick.slow_factor = 0.45
	slick.start_radius = radius
	slick.max_radius = radius
	slick.growth_per_feed = 0.0
	slick.lifetime = 4.0
	slick.pool_height = 0.18
	slick.color = Color(0.45, 0.72, 1.0, 0.4)
	slick.particle_count = 14
	get_parent().add_child(slick)
	slick.global_position = aim


func _do_spray(aim: Vector3, radius: float, damage: int) -> void:
	_resolve(aim, radius, damage)
	var cloud := HazardPool3D.new()
	cloud.damage = damage
	cloud.tick_interval = 1.0
	cloud.lifetime = spray_duration
	cloud.slow_factor = 0.5
	cloud.start_radius = radius
	cloud.max_radius = radius
	cloud.growth_per_feed = 0.0
	cloud.pool_height = 2.2
	cloud.color = Color(0.4, 0.85, 0.25, 0.28)
	cloud.particle_count = 26
	cloud.loop_sfx = "granny_spray" # hiss starts and stops with the visible gas
	get_parent().add_child(cloud)
	cloud.global_position = aim


func _shake(strength: float) -> void:
	if not is_instance_valid(_target):
		return
	var cam := _target.get_node_or_null("Camera3D")
	if cam and cam.has_method("shake"):
		cam.shake(strength)


func _on_damage_shrugged(_amount: int, _from_position: Vector3) -> void:
	# Say so out loud, or the player keeps swinging at a shin forever.
	Fx.impact_text(get_parent(), global_position + Vector3(0, 1.0, 0),
		Color(0.75, 0.8, 0.9), "SHE'S TOO BIG!", 0.75)


func _on_damaged(_amount: int, _from_position: Vector3) -> void:
	# Patience, not health. Every miss visibly rattles her.
	var tween := create_tween()
	tween.tween_property(_visual, "rotation:z", -0.16, 0.08)
	tween.tween_property(_visual, "rotation:z", 0.0, 0.25)


func _on_defeated() -> void:
	state = State.RETREATING
	_timer = 1.4
	Snd.sfx("granny_eek", 0.0, 0.05)
	Snd.loop("granny_spray", false)
	var tween := create_tween()
	tween.tween_property(_visual, "position:y", _hidden_y, 1.2).set_ease(Tween.EASE_IN)


func _acquire_target() -> bool:
	if not is_instance_valid(_target):
		_target = null
		for node in get_tree().get_nodes_in_group("player"):
			_target = node
			break
	return _target != null


## Head, bun, glasses and a shocked mouth, on a floral shoulder. Enough to read
## as a furious old woman looming over the counter from a side view.
func _build_granny() -> Node3D:
	var root := Node3D.new()
	var skin := Block3D.flat_material(Color(0.92, 0.76, 0.66))
	var shoulders := MeshInstance3D.new()
	var shoulder_mesh := BoxMesh.new()
	shoulder_mesh.size = Vector3(2.6, 1.8, 1.2)
	shoulder_mesh.material = Block3D.textured_material(Color(0.55, 0.3, 0.42), "speckle", 2.2)
	shoulders.mesh = shoulder_mesh
	shoulders.position = Vector3(0, -0.7, 0)
	root.add_child(shoulders)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.85
	head_mesh.height = 1.85
	head_mesh.material = skin
	head.mesh = head_mesh
	head.position = Vector3(0, 0.85, 0)
	root.add_child(head)

	var bun := MeshInstance3D.new()
	var bun_mesh := SphereMesh.new()
	bun_mesh.radius = 0.52
	bun_mesh.height = 1.0
	bun_mesh.material = Block3D.flat_material(Color(0.82, 0.82, 0.85))
	bun.mesh = bun_mesh
	bun.position = Vector3(-0.15, 1.7, -0.1)
	root.add_child(bun)

	for side in [-1.0, 1.0]:
		var lens := MeshInstance3D.new()
		var lens_mesh := CylinderMesh.new()
		lens_mesh.top_radius = 0.26
		lens_mesh.bottom_radius = 0.26
		lens_mesh.height = 0.06
		lens_mesh.radial_segments = 12
		var lens_mat := Block3D.flat_material(Color(0.8, 0.9, 1.0, 0.75))
		lens_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		lens_mesh.material = lens_mat
		lens.mesh = lens_mesh
		lens.rotation.x = PI / 2
		lens.position = Vector3(side * 0.32, 0.95, 0.78)
		root.add_child(lens)

	_mouth = MeshInstance3D.new()
	var mouth_mesh := SphereMesh.new()
	mouth_mesh.radius = 0.16
	mouth_mesh.height = 0.3
	mouth_mesh.material = Block3D.flat_material(Color(0.3, 0.12, 0.14))
	_mouth.mesh = mouth_mesh
	_mouth.position = Vector3(0, 0.42, 0.76)
	root.add_child(_mouth)
	return root
