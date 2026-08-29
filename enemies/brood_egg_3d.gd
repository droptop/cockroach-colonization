class_name BroodEgg3D
extends AnimatableBody3D

## An egg somebody should not ignore. Laid by the wasp on a clock and by the
## mantis in place of its old instant brood call: left alone it HATCHES, and
## one bite cracks it first. Turns "adds spawned at me" into a choice — spend
## a swing now, or fight what it becomes.
##
## AnimatableBody3D on the enemy layer, per the Area3D gotcha. The hatch is a
## Callable handed in by whoever laid it, so this file never names a boss
## class (and no boss names this one back — see the compile-cascade gotcha).

@export var hatch_time := 6.0
@export var shell_color := Color(0.93, 0.9, 0.76)
## Pod-shaped (taller, narrower) - the mantis ootheca look.
@export var tall := false
## Above zero alpha, a contrasting ring around the middle - the wasp's
## paper-nest band. Species must read at a glance (user's call).
@export var band_color := Color(0, 0, 0, 0)

## Called with the egg's global_position when the clock runs out.
var hatch_action: Callable

var _left := 0.0
var _shell: MeshInstance3D
var _time := 0.0


func _ready() -> void:
	add_to_group("brood_eggs")
	# Off, or global_position teleports outside a physics step are silently
	# swallowed and every egg reports x 0 - it never moves anyway.
	sync_to_physics = false
	collision_layer = 4 # enemy: the bite area has to find it
	collision_mask = 0
	_left = hatch_time
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 0.8, 0.7)
	shape.shape = box
	add_child(shape)
	_shell = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.24 if tall else 0.3
	mesh.height = 0.95 if tall else 0.74
	mesh.radial_segments = 8
	mesh.rings = 5
	mesh.material = Block3D.flat_material(shell_color)
	_shell.mesh = mesh
	_shell.position.y = 0.44 if tall else 0.34
	add_child(_shell)
	if band_color.a > 0.0:
		var band := MeshInstance3D.new()
		var band_mesh := TorusMesh.new()
		band_mesh.inner_radius = 0.22
		band_mesh.outer_radius = 0.31
		band_mesh.rings = 10
		band_mesh.ring_segments = 5
		band_mesh.material = Block3D.flat_material(band_color)
		band.mesh = band_mesh
		band.position.y = 0.0
		_shell.add_child(band)
	# Speckles, so it reads as an egg and not a dropped mint.
	var fleck := MeshInstance3D.new()
	var fleck_mesh := SphereMesh.new()
	fleck_mesh.radius = 0.06
	fleck_mesh.height = 0.1
	fleck_mesh.radial_segments = 5
	fleck_mesh.rings = 3
	fleck_mesh.material = Block3D.flat_material(shell_color.darkened(0.35))
	fleck.mesh = fleck_mesh
	fleck.position = Vector3(0.18, 0.44, 0.16)
	_shell.add_child(fleck)


func _physics_process(delta: float) -> void:
	_left -= delta
	_time += delta
	# The wobble accelerates as the clock runs down: the tell IS the timer.
	var urgency: float = clampf(1.0 - _left / maxf(hatch_time, 0.01), 0.0, 1.0)
	_shell.rotation.z = sin(_time * (3.0 + urgency * 14.0)) * (0.06 + urgency * 0.22)
	if _left <= 0.0:
		_hatch()


func _hatch() -> void:
	var at := global_position
	var parent := get_parent()
	if parent:
		Fx.spark_burst(parent, at + Vector3(0, 0.4, 0), shell_color)
		Fx.impact_text(parent, at + Vector3(0, 1.2, 0),
			Color(1.0, 0.7, 0.4), "HATCHED!", 0.8)
	Snd.sfx("splat", -3.0, 0.2)
	queue_free()
	if hatch_action.is_valid():
		hatch_action.call(at)


## One bite is enough: the egg is the cheap answer, the hatchling is not.
func take_damage(_amount: int, _from_position: Vector3, _cause := "") -> void:
	var parent := get_parent()
	if parent:
		Fx.spark_burst(parent, global_position + Vector3(0, 0.4, 0), shell_color)
		Fx.impact_text(parent, global_position + Vector3(0, 1.2, 0),
			Color(0.7, 1.0, 0.7), "CRACKED!", 0.7)
	Snd.sfx("crumb", -2.0, 0.2)
	queue_free()
