class_name Level3D
extends Node3D

## Base for 3D levels: wires spawn/death/exit, shows intro text, chains to the
## next level. Subclasses build their decorative set dressing in _build_decor().

@export_file("*.tscn") var next_scene := ""
@export var intro_message := ""
@export var complete_message := "LEVEL COMPLETE"
## Invisible ceiling so climbing + flying can't leave the level.
@export var ceiling_height := 14.0

@onready var _player: Player3D = $Player
@onready var _hud: CanvasLayer = $HUD

var _exited := false


func _ready() -> void:
	_player.spawn_position = $SpawnPoint.global_position
	_player.global_position = _player.spawn_position
	$DeathZone.body_entered.connect(_on_death_zone_body_entered)
	$ExitZone.body_entered.connect(_on_exit_zone_body_entered)
	if intro_message != "":
		_hud.show_message(intro_message, 3.0)
	_add_ceiling()
	_build_decor()


func _add_ceiling() -> void:
	var ceiling := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(500, 2, 24)
	collision.shape = shape
	ceiling.add_child(collision)
	ceiling.position = Vector3(24, ceiling_height + 1.0, 0)
	add_child(ceiling)


func _build_decor() -> void:
	pass # subclasses add set dressing here


func _on_death_zone_body_entered(body: Node3D) -> void:
	if body.has_method("fall_into_pit"):
		body.fall_into_pit()


func _on_exit_zone_body_entered(body: Node3D) -> void:
	if _exited or not body.is_in_group("player"):
		return
	_exited = true
	$ExitZone.set_deferred("monitoring", false)
	if next_scene != "":
		_hud.show_message(complete_message, 0.0)
		await get_tree().create_timer(1.4).timeout
		get_tree().change_scene_to_file(next_scene)
	else:
		GameManager.complete_level()
		_hud.show_message(complete_message, 0.0)


# --- decor helpers -----------------------------------------------------------

func decor_box(pos: Vector3, size: Vector3, color: Color, style := "none", density := 0.5) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Block3D.textured_material(color, style, density)
	inst.mesh = mesh
	inst.position = pos
	add_child(inst)
	return inst


func decor_cylinder(pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.material = Block3D.flat_material(color)
	inst.mesh = mesh
	inst.position = pos
	add_child(inst)
	return inst


func decor_glow_box(pos: Vector3, size: Vector3, color: Color, energy := 1.6) -> MeshInstance3D:
	var inst := decor_box(pos, size, color)
	var mat := (inst.mesh as BoxMesh).material as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return inst


func hazard_drip(pos: Vector3, color: Color, drip_interval := 2.4) -> DripEmitter3D:
	var emitter := DripEmitter3D.new()
	emitter.position = pos
	emitter.drop_color = color
	emitter.interval = drip_interval
	add_child(emitter)
	return emitter


func decor_light(pos: Vector3, color: Color, energy := 1.2, light_range := 9.0) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	add_child(light)
	return light
