class_name EnemyHealthBar
extends Node3D

## Floating health bar above an enemy. Green -> orange -> red as health drops.
## Materials are per-instance so bars don't recolor each other.

const WIDTH := 0.9

var _fill: MeshInstance3D
var _fill_mat: StandardMaterial3D


func _ready() -> void:
	var bg := MeshInstance3D.new()
	var bg_mesh := BoxMesh.new()
	bg_mesh.size = Vector3(WIDTH + 0.07, 0.11, 0.02)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.1, 0.1, 0.14, 0.9)
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mesh.material = bg_mat
	bg.mesh = bg_mesh
	add_child(bg)
	_fill = MeshInstance3D.new()
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(WIDTH, 0.075, 0.03)
	_fill_mat = StandardMaterial3D.new()
	_fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mesh.material = _fill_mat
	_fill.mesh = fill_mesh
	add_child(_fill)
	set_ratio(1.0)


func set_ratio(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	if _fill == null:
		return
	_fill.scale.x = maxf(ratio, 0.001)
	_fill.position.x = -(1.0 - ratio) * WIDTH / 2.0
	var color: Color
	if ratio > 0.55:
		color = Color(0.3, 0.85, 0.35)
	elif ratio > 0.28:
		color = Color(0.95, 0.6, 0.2)
	else:
		color = Color(0.9, 0.2, 0.2)
	_fill_mat.albedo_color = color
