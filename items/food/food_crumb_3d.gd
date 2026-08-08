extends Area3D

## 3D crumb: golden lump that bobs and spins slowly.

@export var value := 1
@export var crumb_color := Color(0.85, 0.68, 0.4)
## Eaten food grows back so the player can always refuel. 0 = never.
@export var respawn_seconds := 12.0

var _time := 0.0
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU # desync bobbing between crumbs
	body_entered.connect(_on_body_entered)
	var mat := Block3D.flat_material(crumb_color)
	var main := MeshInstance3D.new()
	main.mesh = SphereMesh.new()
	(main.mesh as SphereMesh).radius = 0.16
	(main.mesh as SphereMesh).height = 0.28
	(main.mesh as SphereMesh).radial_segments = 8
	(main.mesh as SphereMesh).rings = 4
	(main.mesh as SphereMesh).material = mat
	add_child(main)
	var bump := MeshInstance3D.new()
	bump.mesh = SphereMesh.new()
	(bump.mesh as SphereMesh).radius = 0.09
	(bump.mesh as SphereMesh).height = 0.16
	(bump.mesh as SphereMesh).radial_segments = 8
	(bump.mesh as SphereMesh).rings = 4
	(bump.mesh as SphereMesh).material = Block3D.flat_material(crumb_color.lightened(0.25))
	bump.position = Vector3(0.08, 0.1, 0.05)
	add_child(bump)


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 3.0) * 0.06
	rotation.y += delta * 1.2


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("collect_food"):
		return
	body.collect_food(value)
	if body.has_method("add_wing_energy"):
		body.add_wing_energy(14.0) # crumbs top up the wing dial a little
	set_deferred("monitoring", false)
	Snd.sfx("crumb")
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.8, 0.12)
	tween.parallel().tween_property(self, "position:y", position.y + 0.3, 0.12)
	tween.tween_callback(_after_eaten)


func _after_eaten() -> void:
	if respawn_seconds <= 0.0:
		queue_free()
		return
	visible = false
	await get_tree().create_timer(respawn_seconds).timeout
	scale = Vector3.ONE
	position.y = _base_y
	visible = true
	set_deferred("monitoring", true)
