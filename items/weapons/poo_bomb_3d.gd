class_name PooBomb3D
extends Node3D

## What a very fat cockroach can leave behind him.
##
## Dropped, not thrown: it sits where he put it, counts down in front of you,
## and takes out everything in its radius. That makes it a placement weapon
## rather than an aiming one, which is the point — it is the payoff for being
## heavy, and heavy is exactly when he is too slow to aim anything.
##
## The countdown is VISIBLE and audible on purpose. A bomb that goes off on its
## own schedule with no tell would kill him as often as anything else, and he is
## the slowest thing on the screen while he is carrying the weight that earned
## it.

signal exploded

## Seconds before it goes off, and how far the blast reaches.
@export var fuse := 2.0
@export var radius := 3.6
@export var damage := 4
## He is not immune, but he suffers less than what he was aiming at: standing in
## your own blast should hurt, not end the run.
@export var self_damage := 1

var _left := 0.0
var _body: MeshInstance3D
var _fuse_light: MeshInstance3D
var _blown := false


func _ready() -> void:
	_left = fuse
	var muck := Block3D.textured_material(Color(0.32, 0.22, 0.13), "speckle", 2.4)
	# A lumpy little pile, not a cartoon sphere with a wick.
	_body = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.26
	mesh.height = 0.4
	mesh.radial_segments = 7
	mesh.rings = 4
	mesh.material = muck
	_body.mesh = mesh
	add_child(_body)
	for i in 2:
		var lump := MeshInstance3D.new()
		var lump_mesh := SphereMesh.new()
		lump_mesh.radius = 0.17 - float(i) * 0.04
		lump_mesh.height = 0.26
		lump_mesh.radial_segments = 6
		lump_mesh.rings = 3
		lump_mesh.material = muck
		lump.mesh = lump_mesh
		lump.position = Vector3(0.0, 0.22 + float(i) * 0.16, 0.0)
		add_child(lump)

	# The tell: a light on top that blinks faster as the fuse runs down.
	var hot := Block3D.flat_material(Color(1.0, 0.5, 0.2))
	hot.emission_enabled = true
	hot.emission = Color(1.0, 0.45, 0.15)
	hot.emission_energy_multiplier = 2.0
	_fuse_light = MeshInstance3D.new()
	var spark := SphereMesh.new()
	spark.radius = 0.09
	spark.height = 0.16
	spark.radial_segments = 6
	spark.rings = 3
	spark.material = hot
	_fuse_light.mesh = spark
	_fuse_light.position = Vector3(0, 0.56, 0)
	add_child(_fuse_light)


func _process(delta: float) -> void:
	if _blown:
		return
	_left -= delta
	# Blink rate scales with how little time is left, so the warning gets more
	# urgent rather than just continuing.
	var urgency: float = 1.0 - clampf(_left / maxf(fuse, 0.01), 0.0, 1.0)
	var blink := sin(Time.get_ticks_msec() * 0.001 * (8.0 + urgency * 34.0))
	if _fuse_light:
		_fuse_light.scale = Vector3.ONE * (1.0 + blink * 0.45 + urgency * 0.5)
	if _body:
		_body.scale = Vector3.ONE * (1.0 + urgency * 0.18)
	if _left <= 0.0:
		_detonate()


func _detonate() -> void:
	_blown = true
	Snd.sfx("impact_heavy", 4.0, 0.1)
	Fx.spark_burst(get_parent(), global_position, Color(0.7, 0.9, 0.4))
	Fx.spark_burst(get_parent(), global_position + Vector3(0, 0.5, 0),
		Color(0.5, 0.75, 0.3))
	Fx.impact_text(get_parent(), global_position + Vector3(0, 1.0, 0),
		Color(0.75, 0.95, 0.45), "BLAM!", 0.7)

	# Everything in range, including him. Duck-typed like the rest: anything
	# that can be hurt is hurt, and nothing needs to know what a bomb is.
	for node in get_parent().get_children():
		if not (node is Node3D) or node == self:
			continue
		var to := (node as Node3D).global_position.distance_to(global_position)
		if to > radius:
			continue
		if node.is_in_group("player"):
			if node.has_method("take_damage") and self_damage > 0:
				node.take_damage(self_damage, global_position, "bomb")
		elif node.has_method("take_damage"):
			node.take_damage(damage, global_position, "bomb")
			if node.has_method("stagger"):
				node.stagger(1.4)

	_ring()
	exploded.emit()
	queue_free()


## The blast, drawn so the radius is honest: what you see is what it reached.
func _ring() -> void:
	var level := get_parent()
	if level == null:
		return
	var ring := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.4
	mesh.radial_segments = 12
	mesh.rings = 6
	var mat := Block3D.flat_material(Color(0.7, 0.95, 0.45, 0.4))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.9, 0.4)
	mat.emission_energy_multiplier = 1.2
	mesh.material = mat
	ring.mesh = mesh
	ring.scale = Vector3.ONE * 0.2
	level.add_child(ring)
	ring.global_position = global_position
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE, 0.28)
	tween.tween_method(func(a: float) -> void:
		mat.albedo_color.a = a, 0.4, 0.0, 0.42)
	tween.chain().tween_callback(ring.queue_free)
