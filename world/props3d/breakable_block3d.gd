@tool
class_name BreakableBlock3D
extends StaticBody3D

## A block that gives way, if you hit it hard enough.
##
## `required_damage` is the point of it: a bare bite does 1 and will never get
## through, while a knife does 3 and a HEAVY Harry does +1 on top of whatever he
## is holding. So being fat stops being purely a tax on speed and becomes the
## key to a route — which is the one weight benefit from the brief that the
## stat changes could not express on their own.
##
## It sits on the enemy layer so the existing bite area finds it with no special
## casing, exactly like WebAnchor3D. That also means the pogo can smash a floor
## by dropping on it, which is the down-attack finally having a use that is not
## an enemy.

signal broken

@export var size := Vector3(2.0, 2.0, 3.4):
	set(value):
		size = value
		_refresh()
@export var top_color := Color(0.42, 0.36, 0.33):
	set(value):
		top_color = value
		_refresh()
@export var base_color := Color(0.32, 0.27, 0.25):
	set(value):
		base_color = value
		_refresh()
@export_enum("speckle", "grain", "checker", "brick", "asphalt", "concrete") var texture_style := "concrete":
	set(value):
		texture_style = value
		_refresh()
## Minimum damage in a SINGLE blow to do anything at all. Below this it holds.
@export var required_damage := 2
## Qualifying hits needed to bring it down.
@export var hits_to_break := 2
## Shown once, the first time something too weak bounces off it.
@export var too_weak_hint := "TOO WEAK!"

var health := 2

var _mesh: MeshInstance3D
var _shape: CollisionShape3D
var _cracks: MultiMeshInstance3D
var _hinted := false


func _ready() -> void:
	health = hits_to_break
	collision_layer = 1 | 4 # world, so it blocks; enemy, so the bite finds it
	collision_mask = 0
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.mesh = BoxMesh.new()
		add_child(_mesh)
		_shape = CollisionShape3D.new()
		_shape.shape = BoxShape3D.new()
		add_child(_shape)
		_build_cracks()
	(_mesh.mesh as BoxMesh).size = size
	(_mesh.mesh as BoxMesh).material = Block3D.textured_material(
		base_color, texture_style, 0.8)
	(_shape.shape as BoxShape3D).size = size


## A seam of paler fragments across the face, so it reads as the thing to hit
## rather than as wall. One draw call.
func _build_cracks() -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	var chip := BoxMesh.new()
	chip.size = Vector3(0.16, 0.16, 0.04)
	chip.material = Block3D.flat_material(top_color.lightened(0.25))
	multi.mesh = chip
	multi.instance_count = 9
	var rng := RandomNumberGenerator.new()
	rng.seed = 8801
	for i in 9:
		var along := (float(i) / 8.0 - 0.5) * size.y * 0.8
		var basis := Basis.from_euler(Vector3(0, 0, rng.randf_range(-0.9, 0.9)))
		basis = basis.scaled(Vector3(rng.randf_range(0.6, 1.6), rng.randf_range(0.5, 1.2), 1.0))
		multi.set_instance_transform(i, Transform3D(basis, Vector3(
			rng.randf_range(-0.3, 0.3) * size.x, along, size.z * 0.5 + 0.03)))
	_cracks = MultiMeshInstance3D.new()
	_cracks.multimesh = multi
	add_child(_cracks)


func take_damage(amount: int, from_position: Vector3, _cause := "") -> void:
	if health <= 0:
		return
	if amount < required_damage:
		# Say why, once. Silently absorbing the hit teaches nothing, and the
		# player concludes the wall is simply scenery.
		Fx.spark_burst(get_parent(), from_position, Color(0.7, 0.7, 0.75))
		Snd.sfx("thud", -8.0, 0.2)
		if not _hinted:
			_hinted = true
			Fx.impact_text(get_parent(), global_position + Vector3(0, size.y * 0.5, 0),
				Color(0.8, 0.8, 0.85), too_weak_hint, 0.6)
		return
	health -= 1
	Snd.sfx("thud", -2.0, 0.2)
	Fx.spark_burst(get_parent(), from_position, top_color.lightened(0.3))
	Fx.hit_flash(_mesh, Color(1.0, 0.9, 0.8))
	if _cracks:
		_cracks.scale = Vector3.ONE * (1.0 + 0.35 * float(hits_to_break - health))
	if health <= 0:
		_break()


func _break() -> void:
	broken.emit()
	Snd.sfx("splat", 0.0, 0.25)
	Fx.impact_text(get_parent(), global_position + Vector3(0, size.y * 0.5, 0),
		Color(1.0, 0.85, 0.5), "SMASHED!", 0.8)
	Fx.spark_burst(get_parent(), global_position, top_color.lightened(0.3))
	# Collision off immediately — the way through should open the instant it
	# breaks, not when the animation finishes.
	_shape.set_deferred("disabled", true)
	if _cracks:
		_cracks.queue_free()
	var tween := create_tween()
	tween.tween_property(_mesh, "scale", Vector3(1.15, 0.08, 1.15), 0.18)
	tween.parallel().tween_property(_mesh, "position:y", -size.y * 0.4, 0.18)
	tween.tween_callback(queue_free)
