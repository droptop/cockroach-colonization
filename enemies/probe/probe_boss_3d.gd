class_name ProbeBoss3D
extends BaseBoss3D

## THE PROBE, scouting ahead of the saucer. Eleventh boss, eleventh verb:
## SEND IT BACK.
##
## A darting scanner behind a shimmer field nothing of this world can cross —
## bite, knife, fork, all of it splashes off. But the field was built to keep
## EARTH out, not its own fire: a zap batted back with the SPOON (the reflect
## weapon, load-bearing at last, the way the snail made the fork matter)
## sails home through the shimmer and hurts it. Ranged against ranged; the
## first fight in the game about timing a swing against an incoming shot.
##
## Eleven bosses, eleven questions: ... · owl = freeze · probe = REFLECT.

enum State { SCAN, ZAP, DART, RETREATING, GONE }

@export_group("Encounter")
@export var notice_range := 14.0
## LOW: a reflected bolt climbs at only 1.5/s (Projectile3D.reflect), so the
## probe must scan at roach altitude or every returned shot sails under it.
@export var hover_height := 1.8
@export var zap_interval := 2.2
@export var zap_damage := 1
@export var zap_speed := 8.0
## How far it darts sideways after firing, so it never sits still.
@export var dart_distance := 3.5

var state := State.SCAN

var _timer := 1.2
var _target: Node3D
var _visual: Node3D
var _ring: MeshInstance3D
var _time := 0.0
var _dart_to := 0.0


func _ready() -> void:
	super()
	boss_rule = "Its field shrugs EVERYTHING - except its own fire. SPOON it back!"
	immune_to_damage = false # the field does the guarding, in take_damage
	summon_count = 0
	_visual = _build_probe()
	add_child(_visual)
	_dart_to = global_position.x


func _physics_process(delta: float) -> void:
	if state == State.GONE:
		return
	_timer -= delta
	_time += delta
	if is_instance_valid(_visual):
		_visual.position.y = sin(_time * 2.4) * 0.18
		_visual.rotation.y += delta * 1.4
	if is_instance_valid(_ring):
		_ring.rotation.y -= delta * 3.0
	match state:
		State.SCAN:
			global_position.x = move_toward(global_position.x, _dart_to, 4.0 * delta)
			global_position.y = arena_origin.y + hover_height
			global_position.z = 0.0
			if not _acquire_target():
				return
			if absf(_target.global_position.x - global_position.x) <= notice_range:
				engage()
				if _timer <= 0.0:
					_zap()
		State.RETREATING:
			if _timer <= 0.0:
				state = State.GONE


## One aimed shot, then a sideways dart. The shot is a Projectile3D carrying
## the "zap" cause - the ONLY thing its own field lets back in.
func _zap() -> void:
	_timer = zap_interval
	if not is_instance_valid(_target):
		return
	var zap := Projectile3D.new()
	zap.damage = zap_damage
	zap.speed = zap_speed
	zap.fall_rate = 0.0
	zap.lifetime = 3.0
	zap.spin = 0.0
	zap.damage_cause = "zap"
	zap.hits = 1 | 2
	var bolt := MeshInstance3D.new()
	var bolt_mesh := SphereMesh.new()
	bolt_mesh.radius = 0.18
	bolt_mesh.height = 0.34
	bolt_mesh.radial_segments = 6
	bolt_mesh.rings = 3
	var mat := Block3D.flat_material(Color(0.5, 1.0, 0.7))
	mat.emission_enabled = true
	mat.emission = Color(0.4, 1.0, 0.6)
	mat.emission_energy_multiplier = 2.0
	bolt_mesh.material = mat
	bolt.mesh = bolt_mesh
	zap.set_visual(bolt)
	get_parent().add_child(zap)
	var toward := (_target.global_position + Vector3(0, 0.4, 0)
		- global_position).normalized()
	zap.launch(global_position + toward * 0.8, toward)
	Snd.sfx("sizzle", -4.0, 0.2)
	# Dart to a new firing spot, clamped in-arena.
	var bounds := arena_bounds()
	_dart_to = clampf(global_position.x
		+ (dart_distance if randf() < 0.5 else -dart_distance),
		bounds.x + 1.2, bounds.y - 1.2)


## The shimmer field: everything shrugs off except its own returned fire.
func take_damage(amount: int, from_position: Vector3, cause := "") -> void:
	if cause == "zap":
		# Its own bolt, batted home. No field argues with itself — but every
		# extra swing while a bolt passes calls reflect() again and pumps its
		# damage, so a mashed return arrives absurdly hot. The field bleeds a
		# bolt down to 2 on the way in: three honest returns finish it.
		Fx.spark_burst(get_parent(), global_position, Color(0.5, 1.0, 0.7))
		lose_health(mini(amount, 2), from_position)
		return
	engage()
	_on_damage_shrugged(amount, from_position)
	if is_instance_valid(_ring):
		var flare := create_tween()
		flare.tween_property(_ring, "scale", Vector3.ONE * 1.3, 0.08)
		flare.tween_property(_ring, "scale", Vector3.ONE, 0.2)


func _acquire_target() -> bool:
	if not is_instance_valid(_target):
		_target = null
		for node in get_tree().get_nodes_in_group("player"):
			_target = node
			break
	return _target != null


func _on_damaged(_amount: int, _from_position: Vector3) -> void:
	Fx.hit_flash(_visual, Color(0.8, 1.0, 0.9))
	Snd.sfx("impact_light", -3.0, 0.2)


func _on_defeated() -> void:
	state = State.RETREATING
	_timer = 1.3
	Snd.sfx("impact_heavy", 2.0)
	Fx.ghost(get_parent(), global_position, 1.2, 6)
	Fx.shatter(get_parent(), _visual, 7.5)


## A chrome teardrop with one great lens and a spinning scanner ring.
func _build_probe() -> Node3D:
	var root := Node3D.new()
	var chrome := Block3D.flat_material(Color(0.75, 0.78, 0.85))
	chrome.metallic = 0.6
	chrome.roughness = 0.25

	var hull := MeshInstance3D.new()
	var hull_mesh := SphereMesh.new()
	hull_mesh.radius = 0.75
	hull_mesh.height = 1.7
	hull_mesh.material = chrome
	hull.mesh = hull_mesh
	root.add_child(hull)

	var lens := MeshInstance3D.new()
	var lens_mesh := SphereMesh.new()
	lens_mesh.radius = 0.32
	lens_mesh.height = 0.6
	lens_mesh.radial_segments = 8
	lens_mesh.rings = 4
	var lens_mat := Block3D.flat_material(Color(0.3, 0.9, 0.6))
	lens_mat.emission_enabled = true
	lens_mat.emission = Color(0.3, 0.95, 0.6)
	lens_mat.emission_energy_multiplier = 1.6
	lens_mesh.material = lens_mat
	lens.mesh = lens_mesh
	lens.position = Vector3(0.55, -0.1, 0)
	root.add_child(lens)

	_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.0
	ring_mesh.outer_radius = 1.12
	ring_mesh.rings = 16
	ring_mesh.ring_segments = 6
	var ring_mat := Block3D.flat_material(Color(0.5, 1.0, 0.7, 0.5))
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.4, 1.0, 0.6)
	ring_mat.emission_energy_multiplier = 1.0
	ring_mesh.material = ring_mat
	_ring.mesh = ring_mesh
	root.add_child(_ring)

	# Three antenna stubs below.
	for i in 3:
		var a := TAU * float(i) / 3.0
		var stub := MeshInstance3D.new()
		var stub_mesh := CylinderMesh.new()
		stub_mesh.top_radius = 0.03
		stub_mesh.bottom_radius = 0.05
		stub_mesh.height = 0.5
		stub_mesh.radial_segments = 5
		stub_mesh.material = chrome
		stub.mesh = stub_mesh
		stub.position = Vector3(cos(a) * 0.35, -0.95, sin(a) * 0.35)
		root.add_child(stub)
	return root
