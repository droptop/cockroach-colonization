extends Area3D

## A cockroach egg. Cracked open at the top like a chicken egg someone has
## already been at, with the baby down inside it — never poking through intact
## shell. When Harry gets close it hatches, the crown of the shell bursts off,
## and the baby falls in behind him for good (see BabyFollower3D).

enum State { EGG, HATCHING, HATCHED }

var state := State.EGG

var _shell: MeshInstance3D
var _opening: MeshInstance3D
var _teeth: Array[MeshInstance3D] = []
var _time := 0.0


func _ready() -> void:
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)
	_build_egg()


func _build_egg() -> void:
	var shell_mat := Block3D.flat_material(Color(0.94, 0.92, 0.85))
	shell_mat.emission_enabled = true
	shell_mat.emission = Color(0.9, 0.88, 0.8)
	shell_mat.emission_energy_multiplier = 0.25

	# Body of the shell: a sphere squashed slightly taller than wide.
	_shell = MeshInstance3D.new()
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.2
	shell_mesh.height = 0.52
	shell_mesh.material = shell_mat
	_shell.mesh = shell_mesh
	_shell.position = Vector3(0, 0.24, 0)
	add_child(_shell)

	# The opening: a dark disc set into the top, so the egg reads as already
	# broken rather than as a plain sphere.
	_opening = MeshInstance3D.new()
	var hole := CylinderMesh.new()
	hole.top_radius = 0.125
	hole.bottom_radius = 0.125
	hole.height = 0.02
	hole.radial_segments = 10
	hole.material = Block3D.flat_material(Color(0.16, 0.13, 0.12))
	_opening.mesh = hole
	_opening.position = Vector3(0, 0.42, 0)
	add_child(_opening)

	# Jagged crown around the rim — the tell that makes it read as cracked.
	for i in 7:
		var tooth := MeshInstance3D.new()
		var tooth_mesh := BoxMesh.new()
		var tall := 0.05 + fposmod(i * 0.37, 1.0) * 0.05
		tooth_mesh.size = Vector3(0.07, tall, 0.05)
		tooth_mesh.material = shell_mat
		tooth.mesh = tooth_mesh
		var angle := TAU * i / 7.0
		tooth.position = Vector3(cos(angle) * 0.125, 0.42 + tall * 0.4, sin(angle) * 0.125)
		tooth.rotation = Vector3(0.0, -angle, cos(angle) * 0.25)
		add_child(tooth)
		_teeth.append(tooth)


func _process(delta: float) -> void:
	if state != State.EGG:
		return
	# Something alive in there.
	var wobble := sin(_time * 3.0) * 0.08
	_time += delta
	_shell.rotation.z = wobble
	_opening.rotation.z = wobble


func _on_body_entered(body: Node3D) -> void:
	if state != State.EGG or not body.has_method("adopt_baby"):
		return
	state = State.HATCHING
	set_deferred("monitoring", false)
	Snd.sfx("crumb", 2.0, 0.2)
	# The crown bursts off first...
	for i in _teeth.size():
		var tooth := _teeth[i]
		var angle := TAU * i / float(_teeth.size())
		var tween := tooth.create_tween()
		tween.set_parallel(true)
		tween.tween_property(tooth, "position",
			tooth.position + Vector3(cos(angle) * 0.4, 0.35, sin(angle) * 0.4), 0.28
		).set_ease(Tween.EASE_OUT)
		tween.tween_property(tooth, "rotation:x", randf_range(-4.0, 4.0), 0.28)
		tween.chain().tween_callback(tooth.queue_free)
	var shell_tween := _shell.create_tween()
	shell_tween.tween_property(_shell, "scale", Vector3(1.25, 0.6, 1.25), 0.12)
	shell_tween.tween_property(_shell, "scale", Vector3(0.01, 0.01, 0.01), 0.14)
	shell_tween.tween_callback(_hatch.bind(body))


func _hatch(player: Node3D) -> void:
	state = State.HATCHED
	_opening.queue_free()
	Snd.sfx("fruit", 0.0, 0.15)
	var baby := BabyFollower3D.new()
	# Parented to the level, not to the player or to this egg: the egg is about
	# to be gone, and riding the player's transform is what we moved away from.
	get_parent().add_child(baby)
	baby.global_position = global_position + Vector3(0, 0.2, 0)
	if player.has_method("adopt_baby"):
		player.adopt_baby(baby)
	queue_free()
