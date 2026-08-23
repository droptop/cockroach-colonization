class_name WaspBoss3D
extends BaseBoss3D

## THE WASP, drunk on the sugar bowl at the end of the counter.
##
## Its verb is WHERE YOU STAND. It hovers permanently out of melee reach, so it
## can never be attacked on your terms — the only thing you control is the spot
## it dives at, because it always dives at you. Stand over a spill of syrup,
## step off at the last moment, and it buries itself in the sugar and is stuck
## there long enough to be hit. Dodge over bare counter and it simply pulls up
## and goes round again.
##
## So you never chase this boss. You bait it into terrain, which is the one
## differentiation on the brief's list nothing else here uses.
##
## Six bosses, six questions:
##   rat = when to hit · Granny = don't be hit · cat = what to hit ·
##   Spider Queen = hit something else first · mantis = hit from where ·
##   wasp = stand where it will regret

enum State { HOVER, TELEGRAPH, DIVE, STUCK, RECOVER, RETREATING, GONE }

@export_group("Encounter")
@export var notice_range := 13.0
@export var hover_height := 4.2
@export var hover_drift := 2.6
@export var dive_interval := 2.4
@export var telegraph_time := 0.95

@export_group("Dive")
@export var dive_speed := 15.0
@export var dive_damage := 2
@export var dive_radius := 1.2
## Stuck in the syrup, on the floor, and finally reachable.
@export var stuck_time := 2.6
@export var recover_time := 0.9

@export_group("Syrup")
@export var syrup_count := 3
## Spacing minus twice the radius is the width of BARE counter between patches.
## At 5.0/1.9 that gap was 1.2 units and almost the whole arena was sticky, so
## baiting it into syrup happened whether you meant it or not.
@export var syrup_spacing := 7.0
@export var syrup_radius := 1.7
## Ground level in the arena — where syrup sits and where a dive bottoms out.
@export var floor_y := 0.2

var state := State.HOVER

var _timer := 0.0
var _target: Node3D
var _visual: Node3D
var _wings: Node3D
var _aim := Vector3.ZERO
var _syrup: Array[Vector3] = []
var _hover_origin := Vector3.ZERO
var _time := 0.0


func _ready() -> void:
	super()
	boss_rule = "Stand in the SYRUP to bait the dive, then MOVE before it lands."
	immune_to_damage = true # nothing reaches it in the air
	_hover_origin = global_position
	_visual = _build_wasp()
	add_child(_visual)
	_spill_syrup.call_deferred() # siblings can't be added during a child's _ready


func _spill_syrup() -> void:
	var first := -(syrup_count - 1) * 0.5
	for i in syrup_count:
		var at := Vector3(_hover_origin.x + (first + i) * syrup_spacing, floor_y, 0.0)
		_syrup.append(at)
		# HEXAGONAL, because honey is the one thing in the game that has an
		# obvious shape of its own, and a plain disc read as a puddle of anything.
		# radial_segments 6 on a cylinder IS a hexagon; it was 16, i.e. a circle.
		var mat := Block3D.flat_material(Color(0.96, 0.78, 0.28, 0.88))
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.95, 0.72, 0.25)
		mat.emission_energy_multiplier = 0.4
		mat.roughness = 0.15 # the sheen is what says "sticky"

		var pool := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = syrup_radius
		mesh.bottom_radius = syrup_radius * 0.94
		mesh.height = 0.12
		mesh.radial_segments = 6
		mesh.material = mat
		pool.mesh = mesh
		pool.rotation.y = PI / 6.0 # flat edge to camera, not a point
		get_parent().add_child(pool)
		pool.global_position = at + Vector3(0, 0.07, 0)

		# A comb of smaller hexes around the rim, so it reads as honey rather
		# than as a yellow hexagon someone dropped. One MultiMesh, one draw call.
		var cells := MultiMesh.new()
		cells.transform_format = MultiMesh.TRANSFORM_3D
		var cell_mesh := CylinderMesh.new()
		cell_mesh.top_radius = syrup_radius * 0.3
		cell_mesh.bottom_radius = syrup_radius * 0.3
		cell_mesh.height = 0.1
		cell_mesh.radial_segments = 6
		cell_mesh.material = mat
		cells.mesh = cell_mesh
		cells.instance_count = 6
		for k in 6:
			var a: float = TAU * k / 6.0 + PI / 6.0
			cells.set_instance_transform(k, Transform3D(
				Basis.from_euler(Vector3(0, PI / 6.0, 0)),
				Vector3(cos(a) * syrup_radius * 0.86, -0.01,
					sin(a) * syrup_radius * 0.86)))
		var comb := MultiMeshInstance3D.new()
		comb.multimesh = cells
		pool.add_child(comb)

		# The gooeyness: strands that rise out of it and sag back, so it is
		# visibly stringy and not a solid tile. Staggered so they are never in
		# step with each other.
		for k in 3:
			var strand := MeshInstance3D.new()
			var strand_mesh := CylinderMesh.new()
			strand_mesh.top_radius = 0.035
			strand_mesh.bottom_radius = 0.075
			strand_mesh.height = 0.5
			strand_mesh.radial_segments = 5
			strand_mesh.material = mat
			strand.mesh = strand_mesh
			strand.position = Vector3(
				randf_range(-syrup_radius * 0.5, syrup_radius * 0.5), 0.2,
				randf_range(-0.3, 0.3))
			pool.add_child(strand)
			var pull := strand.create_tween()
			pull.set_loops()
			pull.tween_interval(randf_range(0.0, 1.4))
			pull.tween_property(strand, "scale", Vector3(0.6, 2.1, 0.6),
				randf_range(1.1, 1.7)).set_trans(Tween.TRANS_SINE)
			pull.tween_property(strand, "scale", Vector3(1.15, 0.45, 1.15),
				randf_range(0.8, 1.3)).set_trans(Tween.TRANS_SINE)


func _physics_process(delta: float) -> void:
	if state == State.GONE:
		return
	_time += delta
	_timer -= delta
	if _wings:
		_wings.scale.y = 1.0 + sin(_time * 40.0) * 0.5
	match state:
		State.HOVER:
			_hover(delta)
			if _timer <= 0.0 and _acquire_target() \
					and absf(_target.global_position.x - global_position.x) < notice_range:
				engage()
				_telegraph()
		State.STUCK:
			if _timer <= 0.0:
				_pull_free()
		State.RECOVER:
			if _timer <= 0.0:
				state = State.HOVER
				_timer = dive_interval
		State.RETREATING:
			if _timer <= 0.0:
				state = State.GONE


## Drifts over its patch, always above reach.
func _hover(delta: float) -> void:
	var sway := sin(_time * 0.9) * hover_drift
	var want := Vector3(_hover_origin.x + sway, floor_y + hover_height, 0.0)
	if _acquire_target():
		want.x = lerpf(want.x, _target.global_position.x, 0.35)
	global_position = global_position.lerp(want, minf(2.2 * delta, 1.0))


func _telegraph() -> void:
	state = State.TELEGRAPH
	_aim = Vector3(_target.global_position.x, floor_y, 0.0)
	Snd.sfx("whoosh", -10.0, 0.35)
	var marker := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = dive_radius
	disc.bottom_radius = dive_radius
	disc.height = 0.03
	disc.radial_segments = 16
	var mat := Block3D.flat_material(Color(1.0, 0.85, 0.3, 0.35))
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.25)
	mat.emission_energy_multiplier = 1.0
	disc.material = mat
	marker.mesh = disc
	get_parent().add_child(marker)
	marker.global_position = _aim + Vector3(0, 0.06, 0)
	marker.scale = Vector3(0.15, 1.0, 0.15)
	var grow := marker.create_tween()
	grow.tween_property(marker, "scale", Vector3.ONE, telegraph_time)
	await get_tree().create_timer(telegraph_time).timeout
	if is_instance_valid(marker):
		marker.queue_free()
	if state != State.TELEGRAPH:
		return
	_dive()


func _dive() -> void:
	state = State.DIVE
	Snd.sfx("whoosh", 2.0, 0.1)
	var tween := create_tween()
	tween.tween_property(self, "global_position", _aim + Vector3(0, 0.35, 0),
		global_position.distance_to(_aim) / dive_speed).set_ease(Tween.EASE_IN)
	tween.tween_callback(_impact)


## Where it lands decides everything.
func _impact() -> void:
	if state != State.DIVE:
		return
	Fx.spark_burst(get_parent(), _aim + Vector3(0, 0.2, 0), Color(1.0, 0.9, 0.5))
	# Explicit bool: _target is an untyped Node3D, so `.is_dead` is a Variant and
	# the parser cannot infer the type of the whole expression. Same trap as
	# GrannyBoss3D._resolve.
	var hit: bool = is_instance_valid(_target) and not _target.is_dead \
		and _target.global_position.distance_to(_aim) <= dive_radius
	if hit:
		_target.take_damage(dive_damage, _aim, "wasp")
		Snd.sfx("impact_heavy", 0.0)
		_bounce_off()
		return
	if _in_syrup(_aim):
		# Buried in the sugar. This is the only opening the fight offers.
		state = State.STUCK
		immune_to_damage = false
		_timer = stuck_time
		Snd.sfx("splat", 0.0, 0.2)
		Fx.impact_text(get_parent(), global_position + Vector3(0, 1.0, 0),
			Color(1.0, 0.9, 0.4), "STUCK!", 0.85)
		var stick := create_tween()
		stick.tween_property(_visual, "rotation:z", 0.7, 0.12)
		return
	# Bare counter: it just pulls up and goes round again.
	Snd.sfx("impact_light", -8.0)
	Fx.impact_text(get_parent(), _aim + Vector3(0, 0.7, 0),
		Color(0.8, 0.8, 0.85), "MISSED THE SYRUP", 0.5)
	_bounce_off()


func _in_syrup(at: Vector3) -> bool:
	for pool in _syrup:
		if absf(at.x - pool.x) <= syrup_radius:
			return true
	return false


func _bounce_off() -> void:
	state = State.RECOVER
	immune_to_damage = true
	_timer = recover_time
	var up := create_tween()
	up.tween_property(self, "global_position:y", floor_y + hover_height, recover_time
		).set_ease(Tween.EASE_OUT)


func _pull_free() -> void:
	if is_defeated:
		return
	state = State.RECOVER
	immune_to_damage = true
	_timer = recover_time
	Snd.sfx("whoosh", -2.0)
	var free_tween := create_tween()
	free_tween.tween_property(_visual, "rotation:z", 0.0, 0.2)
	free_tween.parallel().tween_property(self, "global_position:y",
		floor_y + hover_height, recover_time).set_ease(Tween.EASE_OUT)


func _acquire_target() -> bool:
	if not is_instance_valid(_target):
		_target = null
		for node in get_tree().get_nodes_in_group("player"):
			_target = node
			break
	return _target != null


func _on_damage_shrugged(_amount: int, _from_position: Vector3) -> void:
	Fx.impact_text(get_parent(), global_position + Vector3(0, 0.9, 0),
		Color(0.9, 0.9, 1.0), "OUT OF REACH!", 0.65)


func _on_damaged(_amount: int, _from_position: Vector3) -> void:
	Fx.hit_flash(_visual, Color(1.0, 0.9, 0.7))
	Snd.sfx("wasp_hurt", -6.0, 0.3)


func _on_defeated() -> void:
	state = State.RETREATING
	_timer = 1.5
	immune_to_damage = true
	Snd.sfx("wasp_death", 2.0)
	Fx.ghost(get_parent(), global_position, 1.0, 6)
	for spoil in [["heart", 2.0, -1.5], ["heart", 2.0, 1.5], ["energy", 50.0, 0.0]]:
		var reward := RewardPickup3D.new()
		reward.kind = spoil[0]
		reward.amount = spoil[1]
		reward.lifetime = 0.0
		get_parent().add_child(reward)
		reward.global_position = Vector3(global_position.x + spoil[2], floor_y + 0.6, 0.0)
	var tween := create_tween()
	tween.tween_property(_visual, "rotation:z", PI, 0.4)
	tween.parallel().tween_property(self, "global_position:y", floor_y + 0.2, 0.5
		).set_ease(Tween.EASE_IN)


## Striped abdomen, blurred wings, and a great deal of leg.
func _build_wasp() -> Node3D:
	var root := Node3D.new()
	var yellow := Block3D.flat_material(Color(0.95, 0.78, 0.2))
	var black := Block3D.flat_material(Color(0.15, 0.13, 0.12))

	var thorax := MeshInstance3D.new()
	var thorax_mesh := SphereMesh.new()
	thorax_mesh.radius = 0.42
	thorax_mesh.height = 0.8
	thorax_mesh.material = black
	thorax.mesh = thorax_mesh
	thorax.scale = Vector3(1.2, 0.9, 0.9)
	root.add_child(thorax)

	# Banded abdomen trailing behind.
	for i in 4:
		var band := MeshInstance3D.new()
		var band_mesh := SphereMesh.new()
		band_mesh.radius = 0.34 - i * 0.05
		band_mesh.height = 0.5 - i * 0.07
		band_mesh.material = yellow if i % 2 == 0 else black
		band.mesh = band_mesh
		band.position = Vector3(-0.5 - i * 0.28, -0.05 - i * 0.05, 0)
		root.add_child(band)
	var sting := MeshInstance3D.new()
	var sting_mesh := CylinderMesh.new()
	sting_mesh.top_radius = 0.005
	sting_mesh.bottom_radius = 0.07
	sting_mesh.height = 0.34
	sting_mesh.radial_segments = 5
	sting_mesh.material = black
	sting.mesh = sting_mesh
	sting.position = Vector3(-1.75, -0.28, 0)
	sting.rotation.z = 1.4
	root.add_child(sting)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.3
	head_mesh.height = 0.52
	head_mesh.material = yellow
	head.mesh = head_mesh
	head.position = Vector3(0.5, 0.05, 0)
	root.add_child(head)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.13
		eye_mesh.height = 0.24
		eye_mesh.material = black
		eye.mesh = eye_mesh
		eye.position = Vector3(0.66, 0.1, side * 0.16)
		root.add_child(eye)

	# Wings on a pivot, scaled every frame so they read as a blur.
	_wings = Node3D.new()
	_wings.position = Vector3(0.05, 0.32, 0)
	root.add_child(_wings)
	for side in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var wing_mesh := SphereMesh.new()
		wing_mesh.radius = 0.5
		wing_mesh.height = 0.9
		var wing_mat := Block3D.flat_material(Color(0.85, 0.9, 0.95, 0.35))
		wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wing_mesh.material = wing_mat
		wing.mesh = wing_mesh
		wing.scale = Vector3(0.9, 0.12, 0.45)
		wing.position = Vector3(-0.2, 0.0, side * 0.3)
		wing.rotation.x = side * 0.3
		_wings.add_child(wing)
	return root
