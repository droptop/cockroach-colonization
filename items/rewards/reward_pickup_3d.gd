class_name RewardPickup3D
extends Area3D

## A small reward dropped by something you beat: a heart when it restores
## health, a wing shard when it restores flight energy. One class for both,
## because they differ only in what they give and what they look like.
##
## It drifts toward Harry once he is near, so a kill in an awkward spot still
## pays out — but it can also just be walked into, per the brief.
##
## Nothing is ever granted silently. Taking one says what it gave; taking one
## while already full says so and LEAVES IT THERE, rather than swallowing a
## reward the player cannot use yet.

@export_enum("heart", "energy", "coin") var kind := "heart"
## Hearts are in half-heart units (the HUD renders halves); energy is wing bar;
## coins are coins.
@export var amount := 1.0
@export var magnet_range := 3.2
@export var magnet_speed := 7.0
## 0 = never expires.
@export var lifetime := 14.0
## How long before it will nag about being full again.
@export var full_reprompt := 1.6

var _time := 0.0
var _life := 0.0
var _full_cooldown := 0.0
var _player: Node3D
var _visual: Node3D


func _ready() -> void:
	collision_layer = 16 # pickup
	collision_mask = 2 # player
	monitorable = false
	_life = lifetime
	_time = randf() * TAU
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.42
	shape.shape = sphere
	add_child(shape)
	match kind:
		"heart":
			_visual = _build_heart()
		"coin":
			_visual = _build_coin()
		_:
			_visual = _build_shard()
	add_child(_visual)
	body_entered.connect(_on_body_entered)
	# A little pop out of whatever dropped it, so it reads as loot.
	scale = Vector3.ONE * 0.2
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.24).set_trans(Tween.TRANS_BACK
		).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	_full_cooldown = maxf(_full_cooldown - delta, 0.0)
	_visual.position.y = 0.28 + sin(_time * 3.2) * 0.09
	_visual.rotation.y += delta * 1.6
	if lifetime > 0.0:
		_life -= delta
		# Blink out the last second, so it isn't simply gone.
		if _life < 1.0:
			_visual.visible = fmod(_life, 0.2) > 0.1
		if _life <= 0.0:
			queue_free()
			return
	if not is_instance_valid(_player):
		_player = null
		for node in get_tree().get_nodes_in_group("player"):
			_player = node
			break
	if _player and global_position.distance_to(_player.global_position) < magnet_range:
		global_position = global_position.move_toward(
			_player.global_position + Vector3(0, 0.3, 0), magnet_speed * delta)


func _on_body_entered(body: Node3D) -> void:
	if body == null:
		return
	var took := false
	if kind == "heart" and body.has_method("restore_health"):
		took = body.restore_health(amount)
	elif kind == "energy" and body.has_method("add_wing_energy"):
		took = body.add_wing_energy(amount)
	elif kind == "coin" and body.has_method("collect_coins"):
		# Coins have no "full": money always fits.
		took = body.collect_coins(int(amount))
	if not took:
		_say_full(body)
		return
	Snd.sfx("fruit", 2.0, 0.12)
	var tint := Color(0.5, 0.85, 1.0)
	var label := "+WINGS"
	if kind == "heart":
		tint = Color(1.0, 0.4, 0.45)
		label = "+HEALTH"
	elif kind == "coin":
		tint = Color(1.0, 0.85, 0.35)
		label = "+%d COIN" % int(amount) if int(amount) == 1 else "+%d COINS" % int(amount)
	Fx.impact_text(get_parent(), global_position, tint, label, 0.6)
	Fx.spark_burst(get_parent(), global_position, tint)
	queue_free()


## Already full. Say so, and leave the reward where it is — swallowing it would
## be the silent grant the brief rules out, just with extra steps.
func _say_full(_body: Node3D) -> void:
	if _full_cooldown > 0.0:
		return
	_full_cooldown = full_reprompt
	Fx.impact_text(get_parent(), global_position, Color(0.75, 0.78, 0.8),
		"FULL!" if kind == "heart" else "WINGS FULL!", 0.5)
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3.ONE * 1.25, 0.08)
	tween.tween_property(_visual, "scale", Vector3.ONE, 0.14)


func _build_heart() -> Node3D:
	var root := Node3D.new()
	var mat := Block3D.flat_material(Color(0.95, 0.25, 0.35))
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.25, 0.35)
	mat.emission_energy_multiplier = 0.9
	# Two lobes and a point — a heart at this size is a silhouette, not a model.
	for side in [-1.0, 1.0]:
		var lobe := MeshInstance3D.new()
		var lobe_mesh := SphereMesh.new()
		lobe_mesh.radius = 0.15
		lobe_mesh.height = 0.3
		lobe_mesh.radial_segments = 8
		lobe_mesh.rings = 4
		lobe_mesh.material = mat
		lobe.mesh = lobe_mesh
		lobe.position = Vector3(side * 0.11, 0.09, 0)
		root.add_child(lobe)
	var point := MeshInstance3D.new()
	var point_mesh := CylinderMesh.new()
	point_mesh.top_radius = 0.21
	point_mesh.bottom_radius = 0.01
	point_mesh.height = 0.3
	point_mesh.radial_segments = 8
	point_mesh.material = mat
	point.mesh = point_mesh
	point.position = Vector3(0, -0.08, 0)
	root.add_child(point)
	root.position.y = 0.28
	return root


## A fat gold disc. Unmistakably money, unmistakably not food — the whole point
## of coins is that food already IS a currency with a cost attached.
func _build_coin() -> Node3D:
	var root := Node3D.new()
	var mat := Block3D.flat_material(Color(1.0, 0.82, 0.3))
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.78, 0.25)
	mat.emission_energy_multiplier = 0.8
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 0.19
	disc_mesh.bottom_radius = 0.19
	disc_mesh.height = 0.07
	disc_mesh.radial_segments = 10
	disc_mesh.material = mat
	disc.mesh = disc_mesh
	disc.rotation.x = PI / 2.0 # stood on edge, so the spin in _process reads
	root.add_child(disc)
	var stamp := MeshInstance3D.new()
	var stamp_mesh := BoxMesh.new()
	stamp_mesh.size = Vector3(0.07, 0.18, 0.1)
	stamp_mesh.material = Block3D.flat_material(Color(0.85, 0.62, 0.18))
	stamp.mesh = stamp_mesh
	root.add_child(stamp)
	root.position.y = 0.28
	return root


## Deliberately the wing dial's colour, so its meaning is already learned.
func _build_shard() -> Node3D:
	var root := Node3D.new()
	var mat := Block3D.flat_material(Color(0.55, 0.85, 1.0, 0.9))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.85, 1.0)
	mat.emission_energy_multiplier = 1.3
	for side in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var wing_mesh := SphereMesh.new()
		wing_mesh.radius = 0.16
		wing_mesh.height = 0.34
		wing_mesh.radial_segments = 6
		wing_mesh.rings = 3
		wing_mesh.material = mat
		wing.mesh = wing_mesh
		wing.scale = Vector3(0.5, 1.0, 0.28)
		wing.position = Vector3(side * 0.12, 0.0, 0)
		wing.rotation.z = side * -0.4
		root.add_child(wing)
	root.position.y = 0.28
	return root
