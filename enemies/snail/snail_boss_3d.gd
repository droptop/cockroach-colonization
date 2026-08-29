class_name SnailBoss3D
extends BaseBoss3D

## THE SNAIL, fat on lettuce in the roof garden's greenhouse. Ninth boss,
## ninth verb: FLIP it.
##
## Nothing in the game dents the shell — not the knife, not a heavy bite, not
## a mega smash. But the FORK launches what it hits, and a snail is all shell
## and no grip: two quick launches rock it clean over onto its back, and the
## soft side has never heard of armour. It rights itself, slowly, furious,
## so the fight is a rhythm of tip-tip-punish.
##
## Its threat is patience made solid: it slides at him without hurry, and the
## slime it leaves BURNS — the arena slowly fills with everywhere you can no
## longer stand, which is a clock without a timer.
##
## Nine bosses, nine questions:
##   rat = when · Granny = don't be hit · cat = what · Queen = something else
##   first · mantis = from where · wasp = stand where · toad = what you feed
##   it · magpie = punish the gloat · snail = FLIP it

enum State { PATROL, FLIPPED, RIGHTING, RETREATING, GONE }

@export_group("Encounter")
@export var notice_range := 12.0
@export var slide_speed := 1.1
@export var ram_damage := 1
## Upward velocity that counts as a real launch (the fork gives 8).
@export var tip_threshold := 3.5
## Launches inside this window flip it.
@export var tip_window := 4.0
@export var tips_to_flip := 2
@export var flipped_time := 4.5
@export var righting_time := 1.6
## Slime: how often it leaves a burning pool while sliding.
@export var slime_interval := 3.2
@export var gravity := 26.0

var state := State.PATROL

var _timer := 0.0
var _target: Node3D
var _visual: Node3D
var _shell: Node3D
var _stalks: Array[Node3D] = []
var _tips := 0
var _tip_timer := 0.0
var _slime_timer := 2.0
var _ram_cooldown := 0.0
var _wiggle := 0.0


func _ready() -> void:
	super()
	boss_rule = "No blade dents that shell. The FORK can - LAUNCH it, FLIP it!"
	immune_to_damage = true # the shell; being flipped is what drops this
	summon_count = 0 # a snail invites nobody, ever
	_visual = _build_snail()
	add_child(_visual)


func _physics_process(delta: float) -> void:
	if state == State.GONE:
		return
	_timer -= delta
	_tip_timer = maxf(_tip_timer - delta, 0.0)
	if _tip_timer <= 0.0:
		_tips = 0
	_ram_cooldown = maxf(_ram_cooldown - delta, 0.0)
	if not is_on_floor():
		velocity.y = maxf(velocity.y - gravity * delta, -18.0)
	# The tip detector: a real launch while it still has its feet.
	if state == State.PATROL and velocity.y > tip_threshold:
		_tip()
	match state:
		State.PATROL:
			if _acquire_target() \
					and absf(_target.global_position.x - global_position.x) <= notice_range:
				engage()
				var to_him := signf(_target.global_position.x - global_position.x)
				velocity.x = to_him * slide_speed
				_wiggle += delta * 3.0
				if is_instance_valid(_visual):
					_visual.rotation.z = sin(_wiggle) * 0.04
					_visual.position.y = absf(sin(_wiggle * 0.7)) * 0.05
				_slime_timer -= delta
				if _slime_timer <= 0.0:
					_slime_timer = slime_interval
					_leave_slime()
				# The ram: no lunge, just arriving. Slow enough to sidestep
				# forever, damaging enough to forbid standing in its lane.
				if _ram_cooldown <= 0.0 and is_instance_valid(_target) \
						and _target.global_position.distance_to(global_position) < 1.6 \
						and _target.has_method("take_damage"):
					_ram_cooldown = 1.4
					_target.take_damage(ram_damage, global_position, "snail")
			else:
				velocity.x = move_toward(velocity.x, 0.0, 4.0 * delta)
		State.FLIPPED:
			# Beached: a flipped snail is a dome on the ground, and further
			# launches ROCK it, they do not lift it — without this the fork
			# juggled it into the air like a bin lid.
			velocity.y = minf(velocity.y, 1.0)
			velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
			_wiggle += delta * 9.0
			# On its back, all foot and fury, eyestalks flailing.
			for stalk in _stalks:
				stalk.rotation.z = sin(_wiggle + stalk.position.x * 8.0) * 0.6
			if _timer <= 0.0:
				_right_itself()
		State.RIGHTING:
			velocity.x = 0.0
			if _timer <= 0.0:
				state = State.PATROL
				immune_to_damage = true
		State.RETREATING:
			if _timer <= 0.0:
				state = State.GONE
	move_and_slide()


func _acquire_target() -> bool:
	if not is_instance_valid(_target):
		_target = null
		for node in get_tree().get_nodes_in_group("player"):
			_target = node
			break
	return _target != null


func _tip() -> void:
	_tips += 1
	_tip_timer = tip_window
	Snd.sfx("impact_light", -2.0, 0.2)
	var rock := create_tween()
	rock.tween_property(_visual, "rotation:z", 0.5 * float(_tips), 0.15)
	rock.tween_property(_visual, "rotation:z", 0.0, 0.3)
	if _tips >= tips_to_flip:
		_flip()
	else:
		Fx.impact_text(get_parent(), global_position + Vector3(0, 1.8, 0),
			Color(0.9, 0.95, 0.8), "IT ROCKED - AGAIN!", 0.7)


func _flip() -> void:
	_tips = 0
	state = State.FLIPPED
	_timer = flipped_time
	immune_to_damage = false
	Snd.sfx("impact_heavy", 0.0, 0.1)
	Fx.impact_text(get_parent(), global_position + Vector3(0, 2.0, 0),
		Color(0.65, 0.95, 0.7), "FLIPPED! THE SOFT SIDE!", 0.95)
	Fx.spark_burst(get_parent(), global_position + Vector3(0, 0.8, 0),
		Color(0.85, 0.9, 0.7))
	var over := create_tween()
	over.tween_property(_visual, "rotation:z", PI, 0.35
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _right_itself() -> void:
	state = State.RIGHTING
	_timer = righting_time
	Snd.sfx("whoosh", -6.0, 0.2)
	Fx.impact_text(get_parent(), global_position + Vector3(0, 1.8, 0),
		Color(0.9, 0.85, 0.7), "IT'S ROLLING BACK...", 0.7)
	var back := create_tween()
	back.tween_property(_visual, "rotation:z", 0.0, righting_time * 0.8
		).set_ease(Tween.EASE_IN_OUT)


## A pool of what it walks on. HazardPool3D derives its hurtbox from the
## visible mesh, so this can never hurt anyone it does not visibly threaten.
func _leave_slime() -> void:
	var slime := HazardPool3D.new()
	slime.damage = 1
	slime.tick_interval = 0.7
	slime.lifetime = 6.0
	slime.start_radius = 0.8
	slime.max_radius = 0.8
	slime.growth_per_feed = 0.0
	slime.pool_height = 0.2
	slime.color = Color(0.7, 0.85, 0.4)
	slime.damage_cause = "slime"
	get_parent().add_child(slime)
	slime.global_position = Vector3(global_position.x - signf(velocity.x) * 1.2,
		global_position.y + 0.1, 0.0)


func _on_damage_shrugged(_amount: int, _from_position: Vector3) -> void:
	Fx.impact_text(get_parent(), global_position + Vector3(0, 1.8, 0),
		Color(0.85, 0.9, 0.95), "THE SHELL! FLIP IT FIRST!", 0.7)
	Snd.sfx("guard", -6.0, 0.2)


func _on_damaged(_amount: int, _from_position: Vector3) -> void:
	Fx.hit_flash(_visual, Color(1.0, 0.9, 0.85))
	Snd.sfx("impact_light", -3.0, 0.2)


func _on_defeated() -> void:
	state = State.RETREATING
	_timer = 1.5
	immune_to_damage = true
	Snd.sfx("impact_heavy", 2.0)
	Fx.ghost(get_parent(), global_position + Vector3(0, 0.8, 0), 1.4, 6)
	# Shell and all, it comes apart into its own pieces — every boss pays out
	# in shapes now, and the base burst turns the moment into treats and coins.
	Fx.shatter(get_parent(), _visual, 7.5)


## A fat spiral shell on a glistening foot, with two hopeful eyestalks.
func _build_snail() -> Node3D:
	var root := Node3D.new()
	var foot_mat := Block3D.flat_material(Color(0.75, 0.68, 0.5))
	foot_mat.roughness = 0.25 # the sheen is what says slime
	var shell_mat := Block3D.textured_material(Color(0.5, 0.34, 0.2), "speckle", 1.4)

	var foot := MeshInstance3D.new()
	var foot_mesh := SphereMesh.new()
	foot_mesh.radius = 0.85
	foot_mesh.height = 1.1
	foot_mesh.material = foot_mat
	foot.mesh = foot_mesh
	foot.position = Vector3(0.3, 0.5, 0)
	foot.scale = Vector3(1.8, 0.75, 0.9)
	root.add_child(foot)

	_shell = Node3D.new()
	_shell.position = Vector3(-0.4, 1.6, 0)
	root.add_child(_shell)
	# The spiral: shrinking tori stacked at an angle. Reads as a whorl from
	# the side, which is the only side a 2.5D game has.
	for i in 3:
		var whorl := MeshInstance3D.new()
		var whorl_mesh := TorusMesh.new()
		whorl_mesh.inner_radius = 0.35 + (2 - i) * 0.35
		whorl_mesh.outer_radius = 0.85 + (2 - i) * 0.45
		whorl_mesh.rings = 12
		whorl_mesh.ring_segments = 6
		whorl_mesh.material = shell_mat
		whorl.mesh = whorl_mesh
		whorl.rotation.x = PI / 2.0
		whorl.position = Vector3(float(i) * 0.12, float(i) * 0.1, 0)
		whorl.scale = Vector3.ONE * (1.0 - float(i) * 0.08)
		_shell.add_child(whorl)
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 1.05
	core_mesh.height = 2.0
	core_mesh.material = shell_mat
	core.mesh = core_mesh
	core.position = Vector3(0.1, 0.05, 0)
	_shell.add_child(core)

	# Eyestalks, on pivots so the flip can flail them.
	for side in [-0.18, 0.18]:
		var stalk := Node3D.new()
		stalk.position = Vector3(1.7, 1.05, side)
		root.add_child(stalk)
		_stalks.append(stalk)
		var stem := MeshInstance3D.new()
		var stem_mesh := CylinderMesh.new()
		stem_mesh.top_radius = 0.05
		stem_mesh.bottom_radius = 0.08
		stem_mesh.height = 0.8
		stem_mesh.radial_segments = 5
		stem_mesh.material = foot_mat
		stem.mesh = stem_mesh
		stem.position = Vector3(0, 0.4, 0)
		stalk.add_child(stem)
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.13
		eye_mesh.height = 0.24
		eye_mesh.radial_segments = 6
		eye_mesh.rings = 3
		eye_mesh.material = Block3D.flat_material(Color(0.1, 0.09, 0.1))
		eye.mesh = eye_mesh
		eye.position = Vector3(0, 0.85, 0)
		stalk.add_child(eye)
	return root
