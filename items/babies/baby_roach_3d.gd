extends Area3D

## A cockroach egg hidden in the drain. When Harry gets close it hatches into
## a tiny pale baby roach that hops onto his back and rides there. Carry it to
## the level exit to bank it — die and every carried baby is lost.

enum State { EGG, HATCHING, CARRIED }

var state := State.EGG
var _egg: MeshInstance3D
var _baby: Node3D
var _time := 0.0
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)
	_egg = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.52
	var mat := Block3D.flat_material(Color(0.94, 0.92, 0.85))
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.88, 0.8)
	mat.emission_energy_multiplier = 0.25
	mesh.material = mat
	_egg.mesh = mesh
	_egg.position = Vector3(0, 0.24, 0)
	add_child(_egg)


func _process(delta: float) -> void:
	_time += delta
	if state == State.EGG:
		# Gentle wobble — something's alive in there.
		_egg.rotation.z = sin(_time * 3.0) * 0.08
	elif state == State.CARRIED and _baby:
		_baby.position.y = _baby.get_meta("ride_y", 0.55) + sin(_time * 6.0) * 0.03


func _on_body_entered(body: Node3D) -> void:
	if state != State.EGG or not body.has_method("carry_baby"):
		return
	state = State.HATCHING
	set_deferred("monitoring", false)
	Snd.sfx("crumb", 2.0, 0.2)
	# Egg pops...
	var tween := create_tween()
	tween.tween_property(_egg, "scale", Vector3(1.5, 0.5, 1.5), 0.12)
	tween.tween_property(_egg, "scale", Vector3(0.01, 0.01, 0.01), 0.1)
	tween.tween_callback(_egg.queue_free)
	tween.tween_callback(_hatch.bind(body))


func _hatch(player: Node3D) -> void:
	# ...and out comes a tiny pale baby that leaps onto Harry's back.
	_baby = Node3D.new()
	_baby.set_script(load("res://player/roach_visual_3d.gd"))
	_baby.shell_color = Color(0.85, 0.75, 0.65)
	_baby.body_color = Color(0.96, 0.93, 0.88)
	_baby.blush_color = Color(0.95, 0.6, 0.55)
	add_child(_baby)
	_baby.scale = Vector3.ONE * 0.4
	Snd.sfx("fruit", 0.0, 0.15)
	if player.has_method("carry_baby"):
		player.carry_baby(self)
	state = State.CARRIED


## Called by the player to mount the baby on his back at slot `index`.
func ride(player: Node3D, index: int) -> void:
	reparent(player)
	position = Vector3(-0.28 - index * 0.06, 0.0, 0.0)
	if _baby:
		var ride_y := 0.52 + index * 0.2
		_baby.set_meta("ride_y", ride_y)
		_baby.position = Vector3(0, ride_y, 0)
		_baby.scale = Vector3.ONE * 0.4
