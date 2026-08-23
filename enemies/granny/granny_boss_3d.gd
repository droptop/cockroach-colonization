class_name GrannyBoss3D
extends BaseBoss3D

## GRANNY. A level-ending encounter that is deliberately NOT a boss fight in the
## usual sense: GAME.md §11 keeps her a human-scale catastrophe, and the brief is
## explicit that she must not become another damage sponge with a health bar.
##
## So nothing you carry can hurt her. You beat Granny by STAYING ALIVE for
## `survive_time` seconds while she throws everything she has at you. Dodging is
## the attack. That makes her the opposite of the rat, who is beaten by landing
## hits in his recovery window.
##
## It used to be a PATIENCE meter that ticked down when she MISSED, drawn as a
## health bar. Two problems, and the player named both: a bar that empties when
## you do nothing looks like a bug, and nothing on screen said what the bar was
## or what you were supposed to do about it. A countdown says both at once.
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
## HOW LONG YOU HAVE TO LAST. This is the whole fight: outlast it and she gives
## up. Her `health` is driven from what is left of it, purely so the bar above
## her and the defeat plumbing in BaseBoss3D keep working unchanged.
@export var survive_time := 40.0
## Where the pantry stands, relative to her arena centre. NEGATIVE, i.e. back
## the way he came. At +5 it landed at x 52 with the door at x 53, so the
## reward for beating her was a three metre cupboard parked squarely on the
## exit: the way out was behind it and there was nothing to tell you that.
@export var pantry_offset_x := -5.5

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
var _survive_left := 0.0
var _shouted := false
var _hidden_y := 0.0
var _visual: Node3D
var _mouth: MeshInstance3D
var _target: Node3D
## Arm pivots, 0 = her left (screen right), 1 = her right. Attacks swing these
## and the spray can is parented to a hand.
var _shoulders: Array[Node3D] = []
var _hands: Array[Node3D] = []

## Attacks cycle rather than being random, so the encounter is learnable — the
## brief asks for a fair avoidance window, and fair means predictable.
const ROTATION := ["swat", "stomp", "water", "spray"]


func _ready() -> void:
	super()
	boss_rule = "You cannot hurt Granny. Just do not be where she swings."
	immune_to_damage = true
	_visual = _build_granny()
	add_child(_visual)
	_hidden_y = -2.6
	_visual.position.y = _hidden_y # ducked down behind the counter
	# SHE DOES NOT CALL FOR HELP. Every other boss does, at 70/50/20% health,
	# and for her that is actively wrong twice over: her "health" is patience,
	# which drains when SHE misses, so dodging well is what summons the adds —
	# and her whole fight is "do not get hit", so a floor full of ants attacks
	# the one thing she is built around. Two clean dodges put three ants on you
	# and by the end there were nine.
	summon_count = 0


func _physics_process(delta: float) -> void:
	if state == State.GONE:
		return
	_timer -= delta
	_tick_clock(delta)
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
			elif not _shouted and _timer < attack_interval * 0.25:
				# "NOT IN MY HOUSE!" once she has settled into the fight, so it
				# does not land on top of the shriek.
				_shouted = true
				_say("granny_not_in_my_house", 0.0)
		State.TELEGRAPHING, State.STRIKING:
			pass # driven by their own tweens
		State.RETREATING:
			if _timer <= 0.0:
				state = State.GONE


## THE COUNTDOWN. Outlast it and she has had enough.
func _tick_clock(delta: float) -> void:
	if is_defeated or _survive_left <= 0.0:
		return
	if state == State.HIDDEN or state == State.RISING or state == State.RETREATING:
		return
	_survive_left = maxf(_survive_left - delta, 0.0)
	# The bar above her is a ratio of `health`, so drive health from the clock
	# rather than bolting a second readout onto her.
	var left := int(ceil(_survive_left))
	if _bar_label:
		_bar_label.text = "SURVIVE GRANNY\n%d" % left
	health = maxi(1, ceili(float(max_health) * _survive_left / maxf(survive_time, 0.01)))
	_refresh_bar()
	if _survive_left <= 0.0:
		lose_health(health, global_position) # time is up: she gives in


## She spots him, recoils, and shrieks — once per encounter.
func _shock() -> void:
	state = State.SHOCKED
	_timer = shock_time
	_survive_left = survive_time
	engage()
	if not _eeked:
		_eeked = true
		Snd.sfx("granny_eek", 4.0, 0.05)
		# "COCKROACH!" on the double-take, a beat after the shriek.
		_say("granny_cockroach_exclaim", 0.45)
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
	_wind_up(aim)
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
	_swing(aim)
	strike.call(aim, radius, damage)
	state = State.WAITING
	_timer = attack_interval


## Which arm faces him. 0 is her left, the side he arrives from.
func _arm_for(aim: Vector3) -> int:
	return 0 if aim.x <= global_position.x else 1


## ARM POSES. Rest is down and out, wound up is over her head, and the strike
## follows through past rest toward him.
const ARM_REST := 0.34
const ARM_RAISED := -2.45
const ARM_FOLLOW := 0.95


## Raise the near arm over her head through the telegraph, so the blow has
## somewhere to come FROM. The props still land at `aim`, which can be ten
## metres from her: what the arm sells is that she is the one throwing them.
func _wind_up(aim: Vector3) -> void:
	var i := _arm_for(aim)
	if i >= _shoulders.size():
		return
	var side := -1.0 if i == 0 else 1.0
	var arm := _shoulders[i]
	var tween := arm.create_tween()
	tween.tween_property(arm, "rotation:z", side * ARM_RAISED, telegraph_time * 0.7
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _visual:
		var lean := _visual.create_tween()
		lean.tween_property(_visual, "rotation:z", side * -0.16, telegraph_time * 0.7)


## And bring it down with the blow.
func _swing(aim: Vector3) -> void:
	var i := _arm_for(aim)
	if i >= _shoulders.size():
		return
	var side := -1.0 if i == 0 else 1.0
	var arm := _shoulders[i]
	var tween := arm.create_tween()
	tween.tween_property(arm, "rotation:z", side * ARM_FOLLOW, 0.09).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.28)
	tween.tween_property(arm, "rotation:z", side * ARM_REST, 0.45).set_trans(Tween.TRANS_SINE)
	if _visual:
		var lean := _visual.create_tween()
		lean.tween_property(_visual, "rotation:z", side * 0.1, 0.09)
		lean.tween_property(_visual, "rotation:z", 0.0, 0.5)


## Did it land? Anything else is a miss, and a miss costs her patience.
func _resolve(aim: Vector3, radius: float, damage: int, cause := "") -> bool:
	# Explicit bool: _target is an untyped Node3D, so `.is_dead` is a Variant and
	# the inferred type of the whole expression is unknowable to the parser.
	var hit: bool = is_instance_valid(_target) and not _target.is_dead \
		and _target.global_position.distance_to(aim) <= radius
	if hit:
		_target.take_damage(damage, aim, cause)
	else:
		# No longer costs her anything: the clock is the fight. Still shouted,
		# because it is the only thing that tells you the dodge worked.
		Fx.impact_text(get_parent(), aim + Vector3(0, 0.8, 0),
			Color(1.0, 0.85, 0.4), "MISSED!", 0.8)
	return hit


func _do_swat(aim: Vector3, radius: float, damage: int) -> void:
	var swatter := MeshInstance3D.new()
	var paddle := BoxMesh.new()
	paddle.size = Vector3(radius * 1.6, 0.07, radius * 1.4)
	paddle.material = Block3D.flat_material(Color(0.96, 0.36, 0.34))
	swatter.mesh = paddle

	# The perforations. One MultiMesh of pale discs set just proud of the face
	# rather than real holes: at this scale and with flat lighting they read as
	# holes, and geometry with actual holes would be a lathe job for one prop.
	var hole_mesh := CylinderMesh.new()
	hole_mesh.top_radius = radius * 0.055
	hole_mesh.bottom_radius = radius * 0.055
	hole_mesh.height = 0.09
	hole_mesh.radial_segments = 6
	hole_mesh.material = Block3D.flat_material(Color(0.99, 0.95, 0.95))
	var holes := MultiMesh.new()
	holes.transform_format = MultiMesh.TRANSFORM_3D
	holes.mesh = hole_mesh
	holes.instance_count = 16
	var n := 0
	for row in 4:
		for col in 4:
			var t := Transform3D(Basis(), Vector3(
				(col - 1.5) * radius * 0.32,
				0.0,
				(row - 1.5) * radius * 0.27))
			holes.set_instance_transform(n, t)
			n += 1
	var holes_node := MultiMeshInstance3D.new()
	holes_node.multimesh = holes
	swatter.add_child(holes_node)

	# The collar where the handle meets the paddle.
	var collar := MeshInstance3D.new()
	var collar_mesh := CylinderMesh.new()
	collar_mesh.top_radius = radius * 0.13
	collar_mesh.bottom_radius = radius * 0.15
	collar_mesh.height = 0.16
	collar_mesh.radial_segments = 8
	collar_mesh.material = Block3D.flat_material(Color(0.84, 0.22, 0.22))
	collar.mesh = collar_mesh
	collar.position = Vector3(0, 0.1, 0)
	swatter.add_child(collar)

	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.05
	handle_mesh.bottom_radius = 0.075
	# Long enough to leave the top of the frame: a swatter that ends in mid-air
	# reads as a prop dropped by nobody.
	handle_mesh.height = 6.0
	handle_mesh.material = Block3D.flat_material(Color(0.86, 0.89, 0.93))
	handle.mesh = handle_mesh
	handle.position = Vector3(0, 3.0, 0)
	swatter.add_child(handle)
	# And a fist at the top of it, so it is plainly being held.
	var fist := MeshInstance3D.new()
	var fist_mesh := SphereMesh.new()
	fist_mesh.radius = 0.42
	fist_mesh.height = 0.7
	fist_mesh.material = Block3D.flat_material(Color(0.92, 0.76, 0.66))
	fist.mesh = fist_mesh
	fist.position = Vector3(0, 5.4, 0)
	swatter.add_child(fist)
	get_parent().add_child(swatter)
	swatter.global_position = aim + Vector3(0, 8.0, 0)
	var tween := swatter.create_tween()
	tween.tween_property(swatter, "global_position", aim + Vector3(0, 0.1, 0), 0.09
		).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_resolve(aim, radius, damage, "swat")
		Snd.sfx("granny_swat", 4.0)
		Fx.spark_burst(get_parent(), aim + Vector3(0, 0.3, 0), Color(0.9, 0.6, 0.5))
		_shake(0.45))
	tween.tween_interval(0.3)
	tween.tween_callback(swatter.queue_free)


func _do_stomp(aim: Vector3, radius: float, damage: int) -> void:
	# JUST THE SHOE. This used to be a whole leg — bare foot, a six metre shin
	# and a skirt hem at the top of it — descending out of frame. A sandal
	# hurled at you is both funnier and more like a granny, and it stops the
	# attack having to explain where the rest of her is while she is stood over
	# on the counter.
	var shoe := Node3D.new()

	var sole := MeshInstance3D.new()
	var sole_mesh := BoxMesh.new()
	sole_mesh.size = Vector3(radius * 1.5, 0.18, radius * 1.05)
	sole_mesh.material = Block3D.flat_material(Color(0.78, 0.45, 0.16))
	sole.mesh = sole_mesh
	shoe.add_child(sole)

	# A heel under the back of it, so it reads as a shoe and not as a plank.
	var heel := MeshInstance3D.new()
	var heel_mesh := BoxMesh.new()
	heel_mesh.size = Vector3(radius * 0.4, 0.22, radius * 0.9)
	heel_mesh.material = Block3D.flat_material(Color(0.6, 0.33, 0.11))
	heel.mesh = heel_mesh
	heel.position = Vector3(radius * 0.5, -0.19, 0)
	shoe.add_child(heel)

	# Two straps over the instep.
	for i in 2:
		var strap := MeshInstance3D.new()
		var strap_mesh := BoxMesh.new()
		strap_mesh.size = Vector3(radius * 0.2, 0.36, radius * 0.95)
		strap_mesh.material = Block3D.flat_material(Color(0.95, 0.66, 0.2))
		strap.mesh = strap_mesh
		strap.position = Vector3(radius * (-0.24 + i * 0.34), 0.2, 0)
		shoe.add_child(strap)

	get_parent().add_child(shoe)
	shoe.global_position = aim + Vector3(radius * 0.9, 9.0, 0)
	shoe.rotation.z = -2.2
	# Thrown, so it turns over on the way down and lands flat.
	var spin := shoe.create_tween()
	spin.tween_property(shoe, "rotation:z", 0.0, 0.13).set_ease(Tween.EASE_OUT)
	var tween := shoe.create_tween()
	tween.tween_property(shoe, "global_position", aim + Vector3(0, 0.25, 0), 0.13
		).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_resolve(aim, radius, damage, "stomp")
		Snd.sfx("granny_stomp", 6.0)
		Fx.spark_burst(get_parent(), aim + Vector3(0, 0.2, 0), Color(0.7, 0.65, 0.6))
		_shake(0.7)) # the heaviest thing she does, and it feels it
	# Then it clatters over and lies there a moment rather than being winched
	# back up into the sky on a leg that is no longer there.
	tween.tween_property(shoe, "rotation:z", -0.5, 0.12).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(shoe, "global_position",
		aim + Vector3(-radius * 0.7, 0.18, 0), 0.12)
	tween.tween_interval(0.5)
	tween.tween_property(shoe, "scale", Vector3.ONE * 0.01, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_callback(shoe.queue_free)


## A bucket of water: barely hurts, but it knocks him flying and leaves the
## floor slick.
func _do_water(aim: Vector3, radius: float, damage: int) -> void:
	Snd.sfx("water_splash", 2.0)
	_resolve(aim, radius, damage, "water")
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
	slick.damage_cause = "water"
	slick.particle_count = 14
	get_parent().add_child(slick)
	slick.global_position = aim


func _do_spray(aim: Vector3, radius: float, damage: int) -> void:
	_resolve(aim, radius, damage, "spray")
	_show_spray_can(aim)
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
	cloud.damage_cause = "spray"
	cloud.particle_count = 26
	_spray_cloud_visual(aim, radius)
	cloud.loop_sfx = "granny_spray" # hiss starts and stops with the visible gas
	get_parent().add_child(cloud)
	cloud.global_position = aim


func _shake(strength: float) -> void:
	if not is_instance_valid(_target):
		return
	var cam := _target.get_node_or_null("Camera3D")
	if cam and cam.has_method("shake"):
		cam.shake(strength)


func _on_damage_shrugged(amount: int, from_position: Vector3) -> void:
	# Say so out loud, or the player keeps swinging at a shin forever. AT THE
	# SWING: she stands 6.6 m up a counter, so anchoring this to her put it
	# somewhere the player was not looking.
	Fx.impact_text(get_parent(), from_position + Vector3(0, 0.4, 0),
		Color(0.75, 0.8, 0.9), "SHE'S TOO BIG!", 0.75)
	super(amount, from_position)


func _on_damaged(_amount: int, _from_position: Vector3) -> void:
	# Patience, not health. Every miss visibly rattles her.
	var tween := create_tween()
	tween.tween_property(_visual, "rotation:z", -0.16, 0.08)
	tween.tween_property(_visual, "rotation:z", 0.0, 0.25)


func _on_defeated() -> void:
	state = State.RETREATING
	_timer = 1.4
	_drop_spoils()
	Snd.sfx("granny_eek", 0.0, 0.05)
	Snd.loop("granny_spray", false)
	# She used to slide back down behind the counter, which reads as "ducking",
	# not as beaten: the same move she makes between attacks. She reels, pales
	# and fades out instead.
	_fade_out()
	_pantry_payoff()


## Reeling, then gone. Transparency is forced on per-instance copies of her
## materials so nothing else built from the same flat_material fades with her.
func _fade_out() -> void:
	var fading: Array[StandardMaterial3D] = []
	for node in _all_visuals(_visual):
		var mesh := _mesh_of(node)
		var mat := mesh.surface_get_material(0) if mesh.get_surface_count() > 0 else null
		var copy: StandardMaterial3D = (mat as StandardMaterial3D).duplicate() if mat is StandardMaterial3D else StandardMaterial3D.new()
		copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		node.material_override = copy
		fading.append(copy)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_visual, "rotation:z", 0.5, 1.1)
	tween.tween_property(_visual, "position:y", _visual.position.y + 0.6, 1.1)
	tween.tween_method(func(a: float) -> void:
		for mat in fading:
			mat.albedo_color.a = a
			mat.emission_energy_multiplier *= 0.0 if a < 0.05 else 1.0,
		1.0, 0.0, 1.2)


## Everything DRAWN under her, batched or not. This used to collect only
## MeshInstance3D, which quietly stopped being all of her the moment her curls
## and the flowers on her dress were batched into MultiMeshInstance3D: she faded
## out and left her hair hanging in the air over the counter.
func _all_visuals(node: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	if _mesh_of(node) != null:
		out.append(node as GeometryInstance3D)
	for child in node.get_children():
		out.append_array(_all_visuals(child))
	return out


## The mesh behind either kind of instance, or null if the node draws nothing.
func _mesh_of(node: Node) -> Mesh:
	if node is MeshInstance3D:
		return (node as MeshInstance3D).mesh
	if node is MultiMeshInstance3D:
		var mm := (node as MultiMeshInstance3D).multimesh
		return mm.mesh if mm != null else null
	return null


## The look of the spray: a cone falling out of the nozzle that billows into a
## settling cloud. The hurtbox stays the HazardPool3D cylinder underneath, whose
## radius and height are derived from its own visible mesh and guarded by
## hazard_parity_test, so none of this touches what can hurt him: it is dressing
## over a volume that was already correct but read as a green tube.
func _spray_cloud_visual(at: Vector3, radius: float) -> void:
	var level := get_parent()
	if level == null:
		return
	var mat := Block3D.flat_material(Color(0.45, 0.88, 0.3, 0.34))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.9, 0.3)
	mat.emission_energy_multiplier = 0.4

	# The cone of mist coming down out of the can.
	var cone := MeshInstance3D.new()
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.12
	cone_mesh.bottom_radius = radius * 1.05
	cone_mesh.height = 3.4
	cone_mesh.radial_segments = 12
	cone_mesh.material = mat
	cone.mesh = cone_mesh
	cone.position = at + Vector3(0, 4.4, 0)
	level.add_child(cone)
	var fall := cone.create_tween()
	fall.tween_property(cone, "position", at + Vector3(0, 1.7, 0), 0.34
		).set_ease(Tween.EASE_IN)
	fall.tween_interval(spray_duration * 0.5)
	fall.tween_method(func(a: float) -> void:
		mat.albedo_color.a = a, 0.34, 0.0, spray_duration * 0.45)
	fall.tween_callback(cone.queue_free)

	# Puffs that billow out where it lands, so the bottom is a cloud and not a
	# flat lid.
	for i in 7:
		var puff := MeshInstance3D.new()
		var puff_mesh := SphereMesh.new()
		var r: float = radius * randf_range(0.32, 0.55)
		puff_mesh.radius = r
		puff_mesh.height = r * 1.5
		puff_mesh.radial_segments = 7
		puff_mesh.rings = 4
		puff_mesh.material = mat
		puff.mesh = puff_mesh
		var t: float = (float(i) + 0.5) / 7.0
		var spot := at + Vector3(
			lerpf(-radius, radius, t) * 0.85, 0.35 + randf_range(0.0, 0.5),
			randf_range(-0.4, 0.4))
		puff.position = spot + Vector3(0, 2.4, 0)
		puff.scale = Vector3.ONE * 0.3
		level.add_child(puff)
		var bloom := puff.create_tween()
		bloom.tween_interval(0.12 + t * 0.2)
		bloom.set_parallel(true)
		bloom.tween_property(puff, "position", spot, 0.4).set_ease(Tween.EASE_OUT)
		bloom.tween_property(puff, "scale", Vector3.ONE, 0.5)
		bloom.chain().tween_interval(spray_duration * 0.5)
		bloom.chain().tween_property(puff, "scale", Vector3.ONE * 1.5,
			spray_duration * 0.4)
		bloom.chain().tween_callback(puff.queue_free)


## The reward for beating her: the pantry door swings open on the family, and
## the kitchen goes up in sparks. Built here rather than placed in the level so
## it cannot be walked into before she is beaten.
func _pantry_payoff() -> void:
	var level := get_parent()
	if level == null:
		return
	# On the floor, where he can walk into it. It opened at HER height before,
	# six metres up: you could watch the door swing and never reach the family.
	var at := Vector3(arena_origin.x + pantry_offset_x, _floor_reference() - 0.4, -0.6)

	# The cupboard: a dark opening, and a door that swings back on its hinge.
	var cupboard := MeshInstance3D.new()
	var back := BoxMesh.new()
	back.size = Vector3(3.2, 3.0, 0.2)
	back.material = Block3D.flat_material(Color(0.06, 0.05, 0.07))
	cupboard.mesh = back
	cupboard.position = at + Vector3(0, 1.5, 0)
	level.add_child(cupboard)

	var hinge := Node3D.new()
	hinge.position = at + Vector3(-1.6, 1.5, 0.2)
	level.add_child(hinge)
	var door := MeshInstance3D.new()
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(3.2, 3.0, 0.16)
	door_mesh.material = Block3D.textured_material(Color(0.62, 0.45, 0.3), "grain", 1.4)
	door.mesh = door_mesh
	door.position = Vector3(1.6, 0, 0)
	hinge.add_child(door)
	var swing := hinge.create_tween()
	swing.tween_interval(0.9)
	swing.tween_property(hinge, "rotation:y", 2.1, 0.8).set_trans(Tween.TRANS_BACK
		).set_ease(Tween.EASE_OUT)
	swing.tween_callback(func() -> void:
		Snd.sfx("crack", -2.0, 0.1)
		_family(level, at)
		_fireworks(level, at))


## The family, waiting in the dark. They are cosmetic on purpose: the level's
## own babies are what he actually banks, and a pile of free followers here
## would make the run before it pointless.
func _family(level: Node, at: Vector3) -> void:
	for i in 5:
		var baby := MeshInstance3D.new()
		var body := SphereMesh.new()
		body.radius = 0.16 + float(i % 2) * 0.05
		body.height = body.radius * 1.7
		body.radial_segments = 8
		body.rings = 5
		body.material = Block3D.flat_material(Color(0.55, 0.3, 0.22))
		baby.mesh = body
		var spot := at + Vector3(-1.1 + i * 0.55, 0.22, 0.1)
		baby.position = spot + Vector3(0, -0.5, 0)
		level.add_child(baby)
		var bob := baby.create_tween()
		bob.tween_interval(0.1 * i)
		bob.tween_property(baby, "position", spot, 0.35).set_trans(Tween.TRANS_BACK
			).set_ease(Tween.EASE_OUT)
		bob.set_loops()
		bob.tween_property(baby, "position", spot + Vector3(0, 0.09, 0), 0.4)
		bob.tween_property(baby, "position", spot, 0.4)


## Fireworks over the kitchen.
func _fireworks(level: Node, at: Vector3) -> void:
	const COLOURS := [
		Color(1.0, 0.75, 0.25), Color(0.95, 0.35, 0.5),
		Color(0.45, 0.85, 1.0), Color(0.6, 1.0, 0.55),
		Color(1.0, 0.9, 0.4), Color(0.8, 0.55, 1.0),
	]
	for i in COLOURS.size():
		var burst_at := at + Vector3(
			randf_range(-3.5, 3.5), 3.2 + randf_range(0.0, 2.6), randf_range(-0.4, 0.6))
		var colour: Color = COLOURS[i]
		var timer := get_tree().create_timer(0.18 * i)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(level):
				return
			Fx.spark_burst(level, burst_at, colour)
			Snd.sfx("complete", -6.0, 0.25))
	Fx.impact_text(level, at + Vector3(0, 3.0, 0),
		Color(1.0, 0.9, 0.5), "THE HOUSE IS OURS!", 1.4)


## A line, optionally after a beat, with her mouth working while it plays.
func _say(key: String, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if state == State.GONE:
		return
	Snd.sfx(key, 4.0, 0.02)
	if _mouth:
		var tween := create_tween()
		tween.tween_property(_mouth, "scale", Vector3(1.1, 2.0, 1.0), 0.1)
		tween.tween_property(_mouth, "scale", Vector3.ONE, 0.25)


## She drops what she was holding as she goes — a payoff for the encounter,
## rather than the exit simply opening.
## Where the FLOOR is, taken from the player, who is standing on it.
##
## Everything she leaves behind used to be placed relative to HER, and she is
## six metres up on a counter: the pantry opened at her shoulder height where
## nothing could reach it, and her spoils were dropped by a hand-tuned -5.4
## offset that only happened to land near the floor in this one level. Anchor
## it to the ground he is actually standing on and both follow the level.
func _floor_reference() -> float:
	if is_instance_valid(_target):
		return (_target as Node3D).global_position.y
	var player := get_tree().get_first_node_in_group("player")
	if player is Node3D:
		return (player as Node3D).global_position.y
	return global_position.y - 5.4


func _drop_spoils() -> void:
	for spoil in [["heart", 2.0, -1.6], ["heart", 2.0, 0.0], ["energy", 45.0, 1.6]]:
		var reward := RewardPickup3D.new()
		reward.kind = spoil[0]
		reward.amount = spoil[1]
		reward.lifetime = 0.0 # hers keep, so a hard-won fight is not on a clock
		get_parent().add_child(reward)
		# On the floor in front of her, at his height, not hers.
		reward.global_position = Vector3(
			global_position.x + spoil[2], _floor_reference() + 0.5, 0.0)


func _acquire_target() -> bool:
	if not is_instance_valid(_target):
		_target = null
		for node in get_tree().get_nodes_in_group("player"):
			_target = node
			break
	return _target != null


## Waist-up granny looming over the far worktop: skirt, apron, a thick torso in
## her floral dress, sloping shoulders, a neck, a head, and two jointed ARMS.
##
## She used to be one 2.6 x 1.8 x 1.2 box with a head sat on it. No taper, no
## neck, no arms — a square. That is also why the swatter and the spray can had
## nothing to attach to: there was no hand anywhere on her.
##
## Nothing below the waist is built, on purpose. She stands at z -3.2 behind a
## worktop spanning z -1.6..1.6, so from the floor the counter edge cuts her off
## around the chest, and from up on the worktop you see her down to the counter
## line. Legs would be standing inside her own kitchen units.
func _build_granny() -> Node3D:
	var root := Node3D.new()
	var skin := Block3D.flat_material(Color(0.92, 0.76, 0.66))
	var dress := Block3D.textured_material(Color(0.55, 0.3, 0.42), "speckle", 2.2)
	var hair := Block3D.flat_material(Color(0.93, 0.93, 0.95))
	var lace := Block3D.flat_material(Color(0.95, 0.94, 0.9))

	# Skirt, flaring out and stopping at the counter line rather than running on
	# into the cabinets behind her.
	var skirt := MeshInstance3D.new()
	var skirt_mesh := CylinderMesh.new()
	skirt_mesh.top_radius = 1.16
	skirt_mesh.bottom_radius = 1.58
	skirt_mesh.height = 1.1
	skirt_mesh.radial_segments = 12
	skirt_mesh.material = dress
	skirt.mesh = skirt_mesh
	skirt.position = Vector3(0, -1.6, 0)
	root.add_child(skirt)


	# Torso: wider at the chest than the waist, which is the whole difference
	# between a person and a crate.
	var torso := MeshInstance3D.new()
	var torso_mesh := CylinderMesh.new()
	torso_mesh.top_radius = 1.28
	torso_mesh.bottom_radius = 1.14
	torso_mesh.height = 1.6
	torso_mesh.radial_segments = 12
	torso_mesh.material = dress
	torso.mesh = torso_mesh
	torso.position = Vector3(0, -0.6, 0)
	root.add_child(torso)

	# Pinny band at the waist, which also covers the torso/skirt seam.
	var band := MeshInstance3D.new()
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 1.19
	band_mesh.bottom_radius = 1.24
	band_mesh.height = 0.28
	band_mesh.radial_segments = 12
	band_mesh.material = lace
	band.mesh = band_mesh
	band.position = Vector3(0, -1.22, 0)
	root.add_child(band)

	# The flowers on the floral dress, scattered over the torso and skirt front
	# and sat ON the curve rather than on a flat plane in front of it. One
	# MultiMesh, so the dress pattern costs a single draw call.
	const BLOOMS := [
		Vector3(-0.7, -0.15, 0.0), Vector3(0.55, 0.05, 0.0), Vector3(0.0, -0.45, 0.0),
		Vector3(-0.35, -0.95, 0.0), Vector3(0.8, -0.75, 0.0), Vector3(-0.85, -1.35, 0.0),
		Vector3(0.35, -1.45, 0.0), Vector3(1.0, -0.25, 0.0), Vector3(-0.15, -1.9, 0.0),
		Vector3(0.95, -1.85, 0.0), Vector3(-1.0, -1.95, 0.0), Vector3(0.15, 0.15, 0.0),
	]
	var bloom_mesh := SphereMesh.new()
	bloom_mesh.radius = 0.11
	bloom_mesh.height = 0.22
	bloom_mesh.radial_segments = 6
	bloom_mesh.rings = 3
	bloom_mesh.material = Block3D.flat_material(Color(0.95, 0.86, 0.72))
	var blooms := MultiMesh.new()
	blooms.transform_format = MultiMesh.TRANSFORM_3D
	blooms.mesh = bloom_mesh
	blooms.instance_count = BLOOMS.size()
	for i in BLOOMS.size():
		var spot: Vector3 = BLOOMS[i]
		# The body radius AT that height, interpolated along whichever piece the
		# flower sits on. Two guessed radii left blooms hanging off the flare.
		var radius := 0.0
		if spot.y > -1.4: # torso, 1.14 at the waist to 1.28 at the chest
			radius = lerpf(1.14, 1.28, clampf((spot.y + 1.4) / 1.6, 0.0, 1.0))
		else: # skirt, 1.16 at the waist down to 1.58 at the hem
			radius = lerpf(1.16, 1.58, clampf((-1.05 - spot.y) / 1.1, 0.0, 1.0))
		var angle := asin(clampf(spot.x / radius, -1.0, 1.0))
		var size := 0.8 + float(i % 3) * 0.22
		blooms.set_instance_transform(i, Transform3D(
			Basis().scaled(Vector3(size, size, size * 0.45)),
			Vector3(spot.x, spot.y, cos(angle) * radius - 0.02)))
	var bloom_node := MultiMeshInstance3D.new()
	bloom_node.multimesh = blooms
	root.add_child(bloom_node)

	# Bosom, sitting proud of the chest. Two, not one: one reads as a barrel.
	for side in [-1.0, 1.0]:
		var bust := MeshInstance3D.new()
		var bust_mesh := SphereMesh.new()
		bust_mesh.radius = 0.52
		bust_mesh.height = 1.04
		bust_mesh.radial_segments = 10
		bust_mesh.rings = 6
		bust_mesh.material = dress
		bust.mesh = bust_mesh
		bust.position = Vector3(side * 0.46, -0.26, 0.9)
		bust.scale = Vector3(1.0, 0.86, 0.86)
		root.add_child(bust)

	# Sloping shoulders as a squashed sphere. The old square top was the single
	# most robotic thing about her.
	var shoulders := MeshInstance3D.new()
	var shoulder_mesh := SphereMesh.new()
	shoulder_mesh.radius = 1.0
	shoulder_mesh.height = 2.0
	shoulder_mesh.radial_segments = 12
	shoulder_mesh.rings = 6
	shoulder_mesh.material = dress
	shoulders.mesh = shoulder_mesh
	shoulders.position = Vector3(0, 0.08, 0)
	shoulders.scale = Vector3(1.4, 0.5, 1.3)
	root.add_child(shoulders)

	var neck := MeshInstance3D.new()
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.3
	neck_mesh.bottom_radius = 0.36
	neck_mesh.height = 0.8
	neck_mesh.radial_segments = 8
	neck_mesh.material = skin
	neck.mesh = neck_mesh
	neck.position = Vector3(0, 0.55, 0)
	root.add_child(neck)

	var collar := MeshInstance3D.new()
	var collar_mesh := CylinderMesh.new()
	collar_mesh.top_radius = 0.34
	collar_mesh.bottom_radius = 0.58
	collar_mesh.height = 0.22
	collar_mesh.radial_segments = 10
	collar_mesh.material = lace
	collar.mesh = collar_mesh
	collar.position = Vector3(0, 0.66, 0)
	root.add_child(collar)

	_build_arms(root, skin, dress)

	# Head and everything on it hangs off one pivot, lifted clear of the
	# shoulders so there is somewhere for the neck to be. Every offset below is
	# unchanged from when the head sat straight on the box.
	var head_pivot := Node3D.new()
	head_pivot.position = Vector3(0, 0.95, 0)
	root.add_child(head_pivot)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.85
	head_mesh.height = 1.85
	head_mesh.material = skin
	head.mesh = head_mesh
	head.position = Vector3(0, 0.85, 0)
	head_pivot.add_child(head)

	# Curly white hair: a cluster rather than one bun, which is what makes it
	# read as curls at this poly count. Batched into one MultiMesh — eight
	# spheres were eight draw calls for a hairdo.
	const CURLS := [
		Vector3(0.0, 1.62, -0.05), Vector3(-0.62, 1.42, 0.0), Vector3(0.62, 1.42, 0.0),
		Vector3(-0.42, 1.72, 0.22), Vector3(0.42, 1.72, 0.22), Vector3(0.0, 1.3, 0.55),
		Vector3(-0.82, 1.0, 0.1), Vector3(0.82, 1.0, 0.1),
	]
	var curl_mesh := SphereMesh.new()
	curl_mesh.radius = 0.34
	curl_mesh.height = 0.68
	curl_mesh.radial_segments = 8
	curl_mesh.rings = 5
	curl_mesh.material = hair
	var curls := MultiMesh.new()
	curls.transform_format = MultiMesh.TRANSFORM_3D
	curls.mesh = curl_mesh
	curls.instance_count = CURLS.size()
	for i in CURLS.size():
		curls.set_instance_transform(i, Transform3D(
			Basis().scaled(Vector3.ONE * (1.0 + float(i % 3) * 0.147)), CURLS[i]))
	var curl_node := MultiMeshInstance3D.new()
	curl_node.multimesh = curls
	head_pivot.add_child(curl_node)

	for side in [-1.0, 1.0]:
		# Eye behind the lens, so the glasses have something to magnify.
		var white := MeshInstance3D.new()
		var white_mesh := SphereMesh.new()
		white_mesh.radius = 0.2
		white_mesh.height = 0.4
		white_mesh.material = Block3D.flat_material(Color(1.0, 1.0, 1.0))
		white.mesh = white_mesh
		white.position = Vector3(side * 0.32, 0.95, 0.7)
		head_pivot.add_child(white)
		var iris := MeshInstance3D.new()
		var iris_mesh := SphereMesh.new()
		iris_mesh.radius = 0.1
		iris_mesh.height = 0.2
		iris_mesh.material = Block3D.flat_material(Color(0.28, 0.3, 0.72))
		iris.mesh = iris_mesh
		iris.position = Vector3(side * 0.3, 0.95, 0.85)
		head_pivot.add_child(iris)

		# Big round rims, the loudest thing about her.
		var rim := MeshInstance3D.new()
		var rim_mesh := TorusMesh.new()
		rim_mesh.inner_radius = 0.26
		rim_mesh.outer_radius = 0.34
		rim_mesh.rings = 14
		rim_mesh.ring_segments = 6
		rim_mesh.material = Block3D.flat_material(Color(0.97, 0.97, 1.0))
		rim.mesh = rim_mesh
		rim.rotation.x = PI / 2
		rim.position = Vector3(side * 0.32, 0.95, 0.8)
		head_pivot.add_child(rim)

		var lens := MeshInstance3D.new()
		var lens_mesh := CylinderMesh.new()
		lens_mesh.top_radius = 0.26
		lens_mesh.bottom_radius = 0.26
		lens_mesh.height = 0.05
		lens_mesh.radial_segments = 12
		var lens_mat := Block3D.flat_material(Color(0.85, 0.93, 1.0, 0.4))
		lens_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		lens_mesh.material = lens_mat
		lens.mesh = lens_mesh
		lens.rotation.x = PI / 2
		lens.position = Vector3(side * 0.32, 0.95, 0.82)
		head_pivot.add_child(lens)

		# Angry brow, angled down toward the nose.
		var brow := MeshInstance3D.new()
		var brow_mesh := BoxMesh.new()
		brow_mesh.size = Vector3(0.42, 0.09, 0.08)
		brow_mesh.material = hair
		brow.mesh = brow_mesh
		brow.position = Vector3(side * 0.34, 1.32, 0.76)
		brow.rotation.z = side * 0.42
		head_pivot.add_child(brow)

	# Bridge between the lenses.
	var bridge := MeshInstance3D.new()
	var bridge_mesh := BoxMesh.new()
	bridge_mesh.size = Vector3(0.24, 0.05, 0.05)
	bridge_mesh.material = Block3D.flat_material(Color(0.97, 0.97, 1.0))
	bridge.mesh = bridge_mesh
	bridge.position = Vector3(0, 0.95, 0.8)
	head_pivot.add_child(bridge)

	# Gritted mouth: a dark slot with a bar of teeth across it. Still one node
	# called _mouth, because the shout animation scales it on Y.
	_mouth = MeshInstance3D.new()
	var mouth_mesh := BoxMesh.new()
	mouth_mesh.size = Vector3(0.46, 0.2, 0.1)
	mouth_mesh.material = Block3D.flat_material(Color(0.32, 0.12, 0.16))
	_mouth.mesh = mouth_mesh
	_mouth.position = Vector3(0, 0.42, 0.78)
	head_pivot.add_child(_mouth)
	var teeth := MeshInstance3D.new()
	var teeth_mesh := BoxMesh.new()
	teeth_mesh.size = Vector3(0.4, 0.07, 0.06)
	teeth_mesh.material = Block3D.flat_material(Color(0.98, 0.97, 0.94))
	teeth.mesh = teeth_mesh
	teeth.position = Vector3(0, 0, 0.04)
	_mouth.add_child(teeth)
	return root


## Two arms, each a chain of pivots: shoulder -> upper arm -> elbow -> forearm
## -> hand. Pivots rather than one rigid mesh so the attacks can raise and swing
## them, and so the spray can has a hand to be held in.
##
## Puffed dress sleeve to the elbow, bare forearm below it. `_shoulders` and
## `_hands` are indexed 0 = her left (screen right), 1 = her right.
func _build_arms(root: Node3D, skin: StandardMaterial3D, dress: StandardMaterial3D) -> void:
	_shoulders.clear()
	_hands.clear()
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 1.24, 0.06, 0.06)
		shoulder.rotation.z = side * ARM_REST # arms held out from the body
		root.add_child(shoulder)

		var sleeve := MeshInstance3D.new()
		var sleeve_mesh := CylinderMesh.new()
		sleeve_mesh.top_radius = 0.38
		sleeve_mesh.bottom_radius = 0.32
		sleeve_mesh.height = 0.6
		sleeve_mesh.radial_segments = 8
		sleeve_mesh.material = dress
		sleeve.mesh = sleeve_mesh
		sleeve.position = Vector3(0, -0.26, 0)
		shoulder.add_child(sleeve)

		var upper := MeshInstance3D.new()
		var upper_mesh := CylinderMesh.new()
		upper_mesh.top_radius = 0.25
		upper_mesh.bottom_radius = 0.22
		upper_mesh.height = 1.0
		upper_mesh.radial_segments = 8
		upper_mesh.material = skin
		upper.mesh = upper_mesh
		upper.position = Vector3(0, -0.5, 0)
		shoulder.add_child(upper)

		var elbow := Node3D.new()
		elbow.position = Vector3(0, -1.0, 0)
		# Bent forward as well as in: rotation on Z alone can only swing an arm
		# in her own plane, and forearms angled toward the camera are what make
		# her read as squaring up rather than standing to attention.
		elbow.rotation.x = -0.55
		elbow.rotation.z = side * -0.28
		shoulder.add_child(elbow)

		var forearm := MeshInstance3D.new()
		var forearm_mesh := CylinderMesh.new()
		forearm_mesh.top_radius = 0.22
		forearm_mesh.bottom_radius = 0.18
		forearm_mesh.height = 0.9
		forearm_mesh.radial_segments = 8
		forearm_mesh.material = skin
		forearm.mesh = forearm_mesh
		forearm.position = Vector3(0, -0.45, 0)
		elbow.add_child(forearm)

		var hand := Node3D.new()
		hand.position = Vector3(0, -0.9, 0)
		elbow.add_child(hand)
		var fist := MeshInstance3D.new()
		var fist_mesh := SphereMesh.new()
		fist_mesh.radius = 0.29
		fist_mesh.height = 0.58
		fist_mesh.radial_segments = 8
		fist_mesh.rings = 5
		fist_mesh.material = skin
		fist.mesh = fist_mesh
		fist.scale = Vector3(1.0, 1.1, 0.82)
		hand.add_child(fist)

		_shoulders.append(shoulder)
		_hands.append(hand)


## The can itself, swung in over the cloud. The spray attack had no object
## behind it at all: poison simply appeared, which read as a bug rather than as
## Granny reaching for the tin. Banded red and yellow, white cap, so it is
## obviously bug spray and obviously hers.
func _show_spray_can(aim: Vector3) -> void:
	var can := Node3D.new()
	# In her hand if she has one to hold it in. The can used to fly in from off
	# frame under its own power, which read as the tin doing the attacking.
	var hand: Node3D = null
	var arm := _arm_for(aim)
	if arm < _hands.size():
		hand = _hands[arm]
	if hand:
		hand.add_child(can)
	else:
		get_parent().add_child(can)

	const RED := Color(0.83, 0.24, 0.14)
	const AMBER := Color(0.95, 0.72, 0.16)
	const PALE := Color(0.9, 0.91, 0.93)

	# Body, in three bands: red, the yellow label, red again.
	var bands := [
		{"y": 0.62, "h": 0.5, "c": RED},
		{"y": 0.2, "h": 0.42, "c": AMBER},
		{"y": -0.2, "h": 0.42, "c": RED},
	]
	for band in bands:
		var part := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.32
		mesh.bottom_radius = 0.32
		mesh.height = band.h
		mesh.radial_segments = 12
		mesh.material = Block3D.flat_material(band.c)
		part.mesh = mesh
		part.position = Vector3(0, band.y, 0)
		can.add_child(part)

	# The crossed-out roach on the label, as a ring and a bar. Reads at a
	# glance, which a printed decal would not at this size.
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.13
	ring_mesh.outer_radius = 0.17
	ring_mesh.rings = 14
	ring_mesh.ring_segments = 6
	ring_mesh.material = Block3D.flat_material(RED)
	ring.mesh = ring_mesh
	ring.rotation.x = PI / 2.0
	ring.position = Vector3(0, 0.2, 0.33)
	can.add_child(ring)
	var slash := MeshInstance3D.new()
	var slash_mesh := BoxMesh.new()
	slash_mesh.size = Vector3(0.32, 0.05, 0.03)
	slash_mesh.material = Block3D.flat_material(RED)
	slash.mesh = slash_mesh
	slash.position = Vector3(0, 0.2, 0.35)
	slash.rotation.z = -PI / 4.0
	can.add_child(slash)

	# Domed shoulder, collar and nozzle.
	var dome := MeshInstance3D.new()
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 0.32
	dome_mesh.height = 0.4
	dome_mesh.radial_segments = 12
	dome_mesh.rings = 5
	dome_mesh.material = Block3D.flat_material(PALE)
	dome.mesh = dome_mesh
	dome.position = Vector3(0, 0.9, 0)
	can.add_child(dome)
	var nozzle := MeshInstance3D.new()
	var nozzle_mesh := CylinderMesh.new()
	nozzle_mesh.top_radius = 0.1
	nozzle_mesh.bottom_radius = 0.13
	nozzle_mesh.height = 0.26
	nozzle_mesh.radial_segments = 8
	nozzle_mesh.material = Block3D.flat_material(PALE)
	nozzle.mesh = nozzle_mesh
	nozzle.position = Vector3(0, 1.14, 0)
	can.add_child(nozzle)

	if hand:
		# Gripped and tipped at him, juddering as she presses down. The cloud
		# still bursts at `aim` metres away, which is what spray does: it
		# travels. Nozzle points +Y, so tipping past 90 degrees aims it at the
		# floor on his side of her.
		var side := -1.0 if arm == 0 else 1.0
		can.position = Vector3(0, -0.46, 0.12)
		can.rotation.z = side * PI * 0.62
		can.scale = Vector3.ONE * 0.85
		var judder := can.create_tween()
		judder.set_loops(8)
		judder.tween_property(can, "position:y", -0.38, 0.07)
		judder.tween_property(can, "position:y", -0.46, 0.07)
		get_tree().create_timer(spray_duration * 0.6).timeout.connect(can.queue_free)
		return
	# No arms built (a test harness, or a stripped scene): the old fly-in.
	can.rotation.z = 0.85
	can.global_position = aim + Vector3(-1.4, 4.2, 0)
	var tween := can.create_tween()
	tween.tween_property(can, "global_position", aim + Vector3(-0.9, 2.4, 0), 0.18
		).set_ease(Tween.EASE_OUT)
	tween.tween_interval(spray_duration * 0.35)
	tween.tween_property(can, "global_position", aim + Vector3(-1.6, 6.0, 0), 0.45
		).set_ease(Tween.EASE_IN)
	tween.tween_callback(can.queue_free)
