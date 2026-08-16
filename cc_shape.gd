extends SceneTree
var _f := 0
var _lvl: Node
var _p: Projectile3D
func _initialize() -> void:
	_lvl = (load("res://world/levels/street_level.tscn") as PackedScene).instantiate()
	root.add_child(_lvl)
func _process(_d: float) -> bool:
	_f += 1
	if _f == 15:
		_p = Projectile3D.new()
		_lvl.add_child(_p)
		print("children=%d" % _p.get_child_count())
		for c in _p.get_children():
			print("  child: %s (%s) shape=%s disabled=%s" % [c.name, c.get_class(),
				c.shape if c is CollisionShape3D else "-", c.disabled if c is CollisionShape3D else "-"])
		print("layer=%d mask=%d monitoring=%s monitorable=%s" % [
			_p.collision_layer, _p.collision_mask, _p.monitoring, _p.monitorable])
	if _f == 60:
		print("overlaps after settling = %d" % _p.get_overlapping_bodies().size())
		_p.global_position = Vector3(50, 0.6, 0)
	if _f == 400:
		print("overlaps parked in the mantis = %d" % _p.get_overlapping_bodies().size())
		quit(); return true
	return false
