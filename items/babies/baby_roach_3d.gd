extends Area3D

## A cockroach egg. Cracked open at the top like a chicken egg someone has
## already been at, with the baby down inside it — never poking through intact
## shell. When Harry gets close it hatches, the crown of the shell bursts off,
## and the baby falls in behind him for good (see BabyFollower3D).

enum State { EGG, HATCHING, HATCHED }

var state := State.EGG

var _shell: MeshInstance3D
var _opening: MeshInstance3D
var _crown: MultiMeshInstance3D
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
	# One MultiMesh rather than seven MeshInstances: three eggs in the drain
	# were costing 27 draw calls between them purely for shell fragments.
	var crown := MultiMesh.new()
	crown.transform_format = MultiMesh.TRANSFORM_3D
	var tooth := BoxMesh.new()
	tooth.size = Vector3(0.07, 0.09, 0.05)
	tooth.material = shell_mat
	crown.mesh = tooth
	crown.instance_count = 7
	for i in 7:
		var angle := TAU * i / 7.0
		var tall := 0.55 + fposmod(i * 0.37, 1.0) * 0.55
		var basis := Basis.from_euler(Vector3(0.0, -angle, cos(angle) * 0.25))
		basis = basis.scaled(Vector3(1.0, tall, 1.0))
		crown.set_instance_transform(i, Transform3D(basis, Vector3(
			cos(angle) * 0.125, 0.42 + tall * 0.04, sin(angle) * 0.125)))
	_crown = MultiMeshInstance3D.new()
	_crown.multimesh = crown
	add_child(_crown)


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
	# The crown bursts as one piece plus a spark — seven individually tweened
	# fragments were not worth six extra draw calls on every egg in the level.
	if is_instance_valid(_crown):
		var crown_tween := _crown.create_tween()
		crown_tween.tween_property(_crown, "scale", Vector3(1.5, 0.2, 1.5), 0.14)
		crown_tween.tween_callback(_crown.queue_free)
	Fx.spark_burst(get_parent(), global_position + Vector3(0, 0.45, 0),
		Color(0.95, 0.93, 0.85))
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
