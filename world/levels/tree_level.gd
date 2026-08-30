extends Level3D

## Level 10 — The Great Tree. The arc goes vertical: the trunk leans, so the
## route climbs branch to branch, up and to the right, with the garden bed
## far below to catch a fall (soft, not lethal — the tree teaches height
## without punishing every slip; the OWL punishes plenty). Amber sap grips
## like the insecticide did. At the crown: the Owl, and above it, the sky the
## abduction comes from.


func _build_decor() -> void:
	# The user's painted canopy behind everything procedural, same rig as
	# drain and mars: the trunk and branches play in front of it.
	var backdrop := ParallaxBackdrop.new()
	backdrop.texture_path = "res://art/backgrounds/tree_bg.jpeg"
	backdrop.size = Vector2(50.0, 33.3)
	backdrop.base_y = 8.0
	backdrop.depth_z = -9.5
	add_child(backdrop)
	_build_trunk_and_canopy()
	_build_sap()
	_build_aphids()
	# Moonlight through the leaves, and warm knot-hole glows.
	decor_light(Vector3(20, 8, 2), Color(0.65, 0.75, 1.0), 0.9, 24.0)
	decor_light(Vector3(52, 12, 2), Color(0.65, 0.75, 1.0), 0.8, 22.0)
	decor_glow_box(Vector3(9.5, 1.8, -2.2), Vector3(1.1, 1.4, 0.4), Color(1.0, 0.8, 0.45), 1.0)
	decor_light(Vector3(9.5, 2.0, -0.5), Color(1.0, 0.8, 0.5), 0.9, 7.0)
	# Fireflies drifting between the branches.
	decor_motes(Vector3(35, 6, 0), Vector3(34, 6, 2), Color(0.9, 1.0, 0.5, 0.35), 30)
	# On the low branch, and before the crown.
	decor_checkpoint(Vector3(18.0, 3.0, 1.4))
	decor_checkpoint(Vector3(52.0, 9.0, 1.4))
	_build_foreground()


## The trunk behind everything, the branches' own bark, and the canopy mass.
func _build_trunk_and_canopy() -> void:
	# The leaning trunk, in three fat segments marching up and right.
	for seg in [[8.0, 3.0, 5.0], [24.0, 7.0, 4.4], [42.0, 11.0, 3.8]]:
		decor_cylinder(Vector3(seg[0], seg[1], -3.6), seg[2] * 0.5, 9.0, Color(0.36, 0.27, 0.18))
	# Canopy: broad leaf masses behind and above, one emissive-edged each.
	for leafy in [[18.0, 10.0, 16.0], [40.0, 13.0, 20.0], [62.0, 15.0, 16.0]]:
		decor_box(Vector3(leafy[0], leafy[1], -5.5), Vector3(leafy[2], 5.0, 2.0),
			Color(0.16, 0.3, 0.16), "speckle", 1.0)
		decor_glow_box(Vector3(leafy[0], leafy[1] - 2.4, -5.2), Vector3(leafy[2] * 0.8, 0.5, 1.4),
			Color(0.35, 0.6, 0.3), 0.3)
	# Bark lips along each branch's front edge.
	for branch in [[22.0, 2.55, 14.0], [39.0, 5.55, 14.0], [56.0, 8.55, 14.0], [66.0, 10.1, 12.0]]:
		decor_box(Vector3(branch[0], branch[1], -1.5), Vector3(branch[2], 0.35, 0.4),
			Color(0.34, 0.25, 0.17), "grain", 1.4)
	# Distant ground and stars retired: the painted backdrop at z -9.5 is
	# the deep forest now, and both sat behind it, invisible.


## Amber: sap pools that GRIP (slow) and burn slowly - the tree's one hazard,
## on the branches where a grabbed roach is a watched roach.
func _build_sap() -> void:
	for sap in [[26.0, 2.75], [43.0, 5.75], [59.0, 8.75]]:
		var pool := HazardPool3D.new()
		pool.damage = 1
		pool.tick_interval = 1.1
		pool.lifetime = 999999.0
		pool.start_radius = 0.9
		pool.max_radius = 0.9
		pool.growth_per_feed = 0.0
		pool.pool_height = 0.2
		pool.color = Color(0.95, 0.7, 0.2)
		pool.slow_factor = 0.55
		pool.damage_cause = "sap"
		add_child(pool)
		pool.position = Vector3(sap[0], sap[1], 0.0)


## Aphid herds on the leaves - the ants' livestock, pure set dressing.
func _build_aphids() -> void:
	decor_scatter(Vector3(24.0, 2.9, -0.8), Vector3(2.0, 0.06, 0.6), 10,
		Color(0.6, 0.8, 0.45), 0.12, "none", 88)
	decor_scatter(Vector3(44.0, 5.9, -0.8), Vector3(2.0, 0.06, 0.6), 8,
		Color(0.6, 0.8, 0.45), 0.12, "none", 89)


## In FRONT: leaves and twigs sweeping past, and one hanging vine.
func _build_foreground() -> void:
	const FORE := Color(0.04, 0.06, 0.045)
	decor_box(Vector3(33, -1.8, 3.2), Vector3(80, 2.2, 1.0), FORE)
	for twig in [[6.0, 2.0], [28.0, 5.5], [50.0, 8.5]]:
		decor_pipe_run(Vector3(twig[0], twig[1] - 3.0, 3.2),
			Vector3(twig[0] + 1.5, twig[1] + 2.0, 3.2), 0.1, FORE, true, false)
	# Big near leaves, angled, below the route.
	for leaf in [[14.0, 0.2], [37.0, 3.4], [60.0, 6.6]]:
		var blade := decor_box(Vector3(leaf[0], leaf[1], 3.3), Vector3(2.6, 0.12, 1.0), FORE)
		blade.rotation.z = 0.35
	decor_chain(Vector3(45.0, 12.0, 3.4), 10, FORE, 0.16)
	decor_scatter(Vector3(30.0, -0.5, 3.2), Vector3(18.0, 0.2, 0.3), 12, FORE, 0.2, "concrete", 90)
