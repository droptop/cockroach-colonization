class_name CatPaw3D
extends StaticBody3D

## The cat's paw, left resting on the table after a swipe. This — and only this
## — is where the cat can be hurt.
##
## It sits on the enemy layer so the player's existing BiteArea finds it with no
## special casing: to Harry's attack code it is just another thing with
## `take_damage`. What makes it a weak point rather than a body part is that it
## only forwards damage while `vulnerable` is true, and says so out loud when it
## is not.

var boss: BaseBoss3D
var vulnerable := false

var _visual: MeshInstance3D
var _glow: StandardMaterial3D


func _ready() -> void:
	collision_layer = 4 # enemy, so the player's bite area sees it
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 1.1, 2.0)
	shape.shape = box
	shape.position = Vector3(0, 0.55, 0)
	add_child(shape)

	_visual = MeshInstance3D.new()
	var pad := SphereMesh.new()
	pad.radius = 1.2
	pad.height = 1.5
	_glow = Block3D.flat_material(Color(0.32, 0.29, 0.3))
	pad.material = _glow
	_visual.mesh = pad
	_visual.scale = Vector3(1.0, 0.75, 0.85)
	_visual.position = Vector3(0, 0.55, 0)
	add_child(_visual)
	# Toe beans, so it reads as a paw from the side and not a boulder.
	for i in 3:
		var toe := MeshInstance3D.new()
		var toe_mesh := SphereMesh.new()
		toe_mesh.radius = 0.42
		toe_mesh.height = 0.6
		toe_mesh.material = Block3D.flat_material(Color(0.5, 0.38, 0.4))
		toe.mesh = toe_mesh
		toe.position = Vector3(0.75, 0.4, (i - 1) * 0.62)
		add_child(toe)


## Pulses while it can be hurt, so the window is visible and not just felt.
func set_vulnerable(value: bool) -> void:
	vulnerable = value
	if _glow == null:
		return
	_glow.emission_enabled = value
	_glow.emission = Color(1.0, 0.55, 0.5)
	_glow.emission_energy_multiplier = 0.9 if value else 0.0


func take_damage(amount: int, from_position: Vector3) -> void:
	if boss == null or not is_instance_valid(boss) or boss.is_defeated:
		return
	if not vulnerable:
		# The paw is up and moving; hitting it achieves nothing. Say so, or the
		# player concludes the cat is simply unkillable.
		Fx.impact_text(get_parent(), global_position + Vector3(0, 1.4, 0),
			Color(0.7, 0.75, 0.85), "TOO FAST!", 0.7)
		return
	boss.lose_health(amount, from_position)
	Fx.hit_flash(_visual, Color(1.0, 0.7, 0.65))
	Snd.sfx("squeak", -2.0)
