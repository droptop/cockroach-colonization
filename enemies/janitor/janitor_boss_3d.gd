class_name JanitorBoss3D
extends BaseBoss3D

## THE JANITOR-BOT, keeping the saucer spotless. Thirteenth boss, thirteenth
## verb: CLOG.
##
## A rolling vacuum drum whose intake never stops: it drags Harry and every
## loose thing in the room toward its throat. Junk that drifts in slowly gets
## shredded and burped back out - the bot has eaten worse. But a junk can
## SMACKED mid-drift arrives too fast to shred, jams the fan, and leaves the
## thing choking, sparking and mortal until it clears its throat.
##
## Thirteen bosses: rat = when · Granny = don't be hit · cat = what · Queen =
## something else first · mantis = from where · wasp = stand where · toad =
## feed · magpie = gloat · snail = flip · owl = freeze · probe = reflect ·
## worm = unbury · janitor = CLOG.

enum State { SUCK, CLOGGED, BURP, GONE }

@export_group("Encounter")
@export var notice_range := 13.0
## Pull on the player, in apply_wind units. The roof's gusts run ~30.
@export var suck_force := 16.0
## How fast loose junk drifts intake-ward, and how fast a smacked can flies.
@export var junk_drift := 1.6
@export var junk_smacked_speed := 10.0
## How long it chokes per clog, and how many junk cans it keeps in the room.
@export var clog_seconds := 4.5
@export var junk_stock := 3

var state := State.SUCK

var _timer := 0.0
var _target: Node3D
var _visual: Node3D
var _fan: MeshInstance3D
var _time := 0.0
var _junk: Array[Node3D] = []
## The bot restocks after eating everything too — or a player who lets every
## can drift in unsmacked is left in a room with no ammunition at all.
var _restock_timer := 0.0
## Hits it takes mid-choke before coughing the jam clear: without this a fast
## mash emptied all six health in a single clog window (the worm taught us).
var _clog_hits := 0


## A loose junk can: hittable where it drifts (AnimatableBody3D, enemy layer,
## per the Area3D gotcha), and a projectile the moment it is smacked.
class JunkCan3D:
	extends AnimatableBody3D

	var bot: JanitorBoss3D
	var smacked := false
	var fly := Vector3.ZERO

	func _ready() -> void:
		collision_layer = 4 # enemy layer: the bite area has to find it
		collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.6, 0.7, 0.6)
		shape.shape = box
		add_child(shape)
		var body := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.26
		mesh.bottom_radius = 0.26
		mesh.height = 0.62
		mesh.radial_segments = 8
		mesh.material = Block3D.flat_material(Color(0.72, 0.74, 0.78))
		body.mesh = mesh
		add_child(body)
		var stripe := MeshInstance3D.new()
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.54, 0.16, 0.54)
		stripe_mesh.material = Block3D.flat_material(Color(0.85, 0.35, 0.25))
		stripe.mesh = stripe_mesh
		add_child(stripe)

	func take_damage(_amount: int, from_position: Vector3, _cause := "") -> void:
		if smacked:
			return
		smacked = true
		var dir := signf(global_position.x - from_position.x)
		if dir == 0.0:
			dir = 1.0
		# Toward the bot regardless of which side it was hit from: the smack
		# is the send-off, the intake does the aiming.
		if is_instance_valid(bot):
			dir = signf(bot.global_position.x - global_position.x)
		# Flat and hard: an arcing can sailed OVER the intake's catch radius.
		fly = Vector3(dir * bot.junk_smacked_speed, 0.3, 0.0)
		Snd.sfx("impact_light", 0.0, 0.25)
		Fx.impact_text(get_parent(), global_position + Vector3(0, 0.8, 0),
			Color(0.85, 0.95, 1.0), "INCOMING!", 0.6)


func _ready() -> void:
	super()
	boss_rule = "It EATS slow junk. SMACK a can into its throat to CLOG it!"
	immune_to_damage = false # the fan does the guarding, in take_damage
	summon_count = 0
	_visual = _build_bot()
	add_child(_visual)
	call_deferred("_restock_junk") # siblings: not during our own _ready


func _physics_process(delta: float) -> void:
	if state == State.GONE:
		return
	_time += delta
	_timer -= delta
	if is_instance_valid(_fan):
		_fan.rotation.z += delta * (14.0 if state == State.SUCK else 1.5)
	match state:
		State.SUCK:
			if not _acquire_target():
				return
			var dx := _target.global_position.x - global_position.x
			if absf(dx) <= notice_range:
				engage()
			if not engaged:
				return
			# The pull, on him and on the junk.
			if _target.has_method("apply_wind"):
				_target.apply_wind(-signf(dx) * suck_force)
			_drag_junk(delta)
			if _junk.is_empty():
				_restock_timer -= delta
				if _restock_timer <= 0.0:
					_restock_timer = 1.2
					_restock_junk()
			_visual.position.y = sin(_time * 3.0) * 0.05
		State.CLOGGED:
			if _timer <= 0.0:
				state = State.BURP
				_timer = 0.8
				Snd.sfx("whoosh", 0.0, 0.15)
		State.BURP:
			if _timer <= 0.0:
				_restock_junk()
				state = State.SUCK


## Junk drifts intake-ward; smacked junk flies. Arriving fast means a clog,
## arriving slow means lunch.
func _drag_junk(delta: float) -> void:
	for can in _junk:
		if not is_instance_valid(can):
			continue
		var jc := can as JunkCan3D
		if jc.smacked:
			jc.global_position += jc.fly * delta
		else:
			jc.global_position.x = move_toward(jc.global_position.x,
				global_position.x, junk_drift * delta)
		if jc.global_position.distance_to(global_position) < 1.3:
			if jc.smacked:
				_clog()
			else:
				Fx.spark_burst(get_parent(), global_position + Vector3(0, 0.4, 0),
					Color(0.7, 0.72, 0.78))
				Snd.sfx("crumb", -4.0, 0.2)
			jc.queue_free()
		elif jc.smacked and absf(jc.global_position.x - global_position.x) > 8.0:
			jc.queue_free() # sailed past everything: gone, not stuck in the stock
	_junk = _junk.filter(func(c: Node3D) -> bool:
		return is_instance_valid(c) and not c.is_queued_for_deletion())


func _clog() -> void:
	state = State.CLOGGED
	_clog_hits = 0
	_timer = clog_seconds
	Snd.sfx("impact_heavy", 0.0, 0.1)
	Fx.spark_burst(get_parent(), global_position + Vector3(0, 0.8, 0),
		Color(1.0, 0.8, 0.3))
	Fx.impact_text(get_parent(), global_position + Vector3(0, 1.8, 0),
		Color(1.0, 0.85, 0.4), "CLOGGED!", 0.9)


## The fan does the guarding: anything swung at a running vacuum just gets
## pulled through the blades. Choking, it is only metal.
func take_damage(amount: int, from_position: Vector3, _cause := "") -> void:
	engage()
	if state == State.CLOGGED:
		lose_health(amount, from_position)
		_clog_hits += 1
		if _clog_hits >= 3 and health > 0:
			state = State.BURP
			_timer = 0.8
			Fx.spark_burst(get_parent(), global_position + Vector3(0, 0.8, 0),
				Color(0.7, 0.72, 0.78))
			Snd.sfx("whoosh", 0.0, 0.15)
	else:
		_on_damage_shrugged(amount, from_position)


## Keeps the room stocked: however a can went (eaten, clogged, or lost off
## the edge), the bot's own tidiness hands the player fresh ammunition.
func _restock_junk() -> void:
	var bounds := arena_bounds()
	while _junk.size() < junk_stock:
		var can := JunkCan3D.new()
		can.bot = self
		get_parent().add_child(can)
		var t := (float(_junk.size()) + 0.7) / (float(junk_stock) + 1.0)
		var side := -1.0 if _junk.size() % 2 == 0 else 1.0
		can.global_position = Vector3(
			clampf(global_position.x + side * (2.5 + t * 4.0),
				bounds.x + 1.0, bounds.y - 1.0),
			arena_origin.y + 0.4, 0.0)
		_junk.append(can)


func _acquire_target() -> bool:
	if not is_instance_valid(_target):
		_target = null
		for node in get_tree().get_nodes_in_group("player"):
			_target = node
			break
	return _target != null


func _on_damaged(_amount: int, _from_position: Vector3) -> void:
	Fx.hit_flash(_visual, Color(1.0, 0.9, 0.7))
	Snd.sfx("impact_light", -3.0, 0.2)


func _on_defeated() -> void:
	state = State.GONE
	for can in _junk:
		if is_instance_valid(can):
			can.queue_free()
	Snd.sfx("impact_heavy", 2.0)
	Fx.ghost(get_parent(), global_position, 1.2, 6)
	Fx.shatter(get_parent(), _visual, 7.5)


## A squat vacuum drum: rounded body, one wide dark intake, a visible fan
## inside it, stubby bumper skirt, and a status light that means nothing.
func _build_bot() -> Node3D:
	var root := Node3D.new()
	var shell := Block3D.flat_material(Color(0.82, 0.83, 0.86))
	var drum := MeshInstance3D.new()
	var drum_mesh := CylinderMesh.new()
	drum_mesh.top_radius = 0.85
	drum_mesh.bottom_radius = 0.95
	drum_mesh.height = 1.3
	drum_mesh.radial_segments = 12
	drum_mesh.material = shell
	drum.mesh = drum_mesh
	drum.position.y = 0.65
	root.add_child(drum)
	var skirt := MeshInstance3D.new()
	var skirt_mesh := CylinderMesh.new()
	skirt_mesh.top_radius = 1.0
	skirt_mesh.bottom_radius = 1.05
	skirt_mesh.height = 0.25
	skirt_mesh.radial_segments = 12
	skirt_mesh.material = Block3D.flat_material(Color(0.3, 0.32, 0.36))
	skirt.mesh = skirt_mesh
	skirt.position.y = 0.12
	root.add_child(skirt)
	# The intake: a dark mouth facing the room, fan spinning inside.
	var maw := MeshInstance3D.new()
	var maw_mesh := CylinderMesh.new()
	maw_mesh.top_radius = 0.5
	maw_mesh.bottom_radius = 0.5
	maw_mesh.height = 0.3
	maw_mesh.radial_segments = 10
	maw_mesh.material = Block3D.flat_material(Color(0.08, 0.08, 0.1))
	maw.mesh = maw_mesh
	maw.rotation.x = PI / 2.0
	maw.position = Vector3(0, 0.7, 0.8)
	root.add_child(maw)
	_fan = MeshInstance3D.new()
	var fan_mesh := BoxMesh.new()
	fan_mesh.size = Vector3(0.75, 0.1, 0.06)
	var fan_mat := Block3D.flat_material(Color(0.6, 0.62, 0.66))
	fan_mesh.material = fan_mat
	_fan.mesh = fan_mesh
	_fan.position = Vector3(0, 0.7, 0.85)
	root.add_child(_fan)
	var lamp := MeshInstance3D.new()
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.12
	lamp_mesh.height = 0.24
	lamp_mesh.radial_segments = 6
	lamp_mesh.rings = 3
	var lamp_mat := Block3D.flat_material(Color(0.3, 0.9, 0.5))
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(0.3, 0.9, 0.5)
	lamp_mat.emission_energy_multiplier = 1.4
	lamp_mesh.material = lamp_mat
	lamp.mesh = lamp_mesh
	lamp.position = Vector3(0, 1.45, 0)
	root.add_child(lamp)
	return root
