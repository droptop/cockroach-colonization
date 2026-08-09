class_name ParallaxBackdrop
extends Node3D

## Painted backdrop on a big quad behind the level. Follows the camera at
## slightly less than full speed, so the art slides gently as you run —
## classic parallax depth.

@export_file("*.jpeg", "*.jpg", "*.png") var texture_path := ""
## 1.0 = glued to the camera (no slide); lower = more slide.
@export var follow_factor := 0.9
@export var size := Vector2(34.0, 22.6)
@export var base_y := 6.0
@export var depth_z := -5.8

var _quad: MeshInstance3D


func _ready() -> void:
	_quad = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	if texture_path != "":
		mat.albedo_texture = load(texture_path)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if "disable_fog" in mat:
		mat.disable_fog = true # keep the painting crisp behind the murk
	mesh.material = mat
	_quad.mesh = mesh
	add_child(_quad)
	global_position = Vector3(0, base_y, depth_z)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	global_position.x = cam.global_position.x * follow_factor
	global_position.y = base_y + (cam.global_position.y - base_y) * 0.2
