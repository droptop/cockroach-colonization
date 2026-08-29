extends Level3D

## Level 7 — The Pantry. The glutton level (BACKLOG item 39): the one room
## where fullness is the SUBJECT rather than a tax. The first half feeds him
## until he is heavy enough to break the soft panel; the far half is where the
## weight comes off — poo bombs, taught just before the one fight that runs on
## them. The Toad at the door is beaten by FEEDING it, so the gorge, the gym
## and the boss are the same loop.

## Front faces of the blocks sit near z 1.76; painted details ride clear.
const FACE_Z := 1.84


func _build_decor() -> void:
	# Larder walls: dark wood, shelf uprights marching back.
	decor_box(Vector3(31, 7, -5.6), Vector3(74, 20, 1.2), Color(0.3, 0.22, 0.15), "grain", 0.8)
	for x in [-2.0, 10.0, 22.0, 34.0, 46.0, 58.0]:
		decor_box(Vector3(x, 5.0, -4.6), Vector3(0.8, 14.0, 0.9), Color(0.24, 0.17, 0.11), "grain", 1.0)
	# Deep shelves behind the play plane, stacked with stores.
	for shelf in [[10.0, 4.2, 20.0], [34.0, 6.4, 22.0], [52.0, 4.0, 16.0]]:
		decor_box(Vector3(shelf[0], shelf[1], -4.0), Vector3(shelf[2], 0.5, 2.2),
			Color(0.42, 0.31, 0.2), "grain", 0.9)
	_build_stores()
	_build_weight_door()
	# One bare bulb on a flex, swinging over the middle of the room.
	decor_pipe_run(Vector3(30, 13.5, -1.0), Vector3(30, 9.6, -1.0), 0.06,
		Color(0.15, 0.13, 0.1))
	decor_glow_box(Vector3(30, 9.3, -1.0), Vector3(0.7, 0.9, 0.7), Color(1.0, 0.9, 0.6), 2.2)
	decor_light(Vector3(30, 8.8, 0.5), Color(1.0, 0.9, 0.65), 1.6, 18.0)
	# A crack of daylight under the pantry door at the exit.
	decor_glow_box(Vector3(65.0, 0.7, -0.4), Vector3(0.5, 1.5, 1.6), Color(1.0, 0.85, 0.55), 2.2)
	decor_light(Vector3(64, 1.0, 1.0), Color(1.0, 0.85, 0.55), 1.2, 6.0)
	decor_light(Vector3(10, 6, 2), Color(1.0, 0.85, 0.6), 0.6, 16.0)
	decor_motes(Vector3(30, 5, 0), Vector3(30, 4, 2), Color(1.0, 0.9, 0.65, 0.22), 22)
	# Flour haze where the sack has been leaking.
	decor_motes(Vector3(20, 2, 0), Vector3(4, 2, 2), Color(0.95, 0.92, 0.85, 0.3), 12)
	# Before the weight door, and again before the Toad notices him.
	decor_checkpoint(Vector3(24.0, 0.5, 1.4))
	decor_checkpoint(Vector3(47.0, 0.5, 1.4))
	_build_foreground()


## Jars, tins and sacks: the stores that make it a pantry. Non-collidable —
## the shelving in the .tscn is the geometry.
func _build_stores() -> void:
	# Jam jars along the back shelves, lit from within like the shop's icon.
	for jar in [[6.0, 4.9, Color(0.75, 0.3, 0.2)], [12.5, 4.9, Color(0.85, 0.6, 0.2)],
			[30.0, 7.1, Color(0.5, 0.3, 0.55)], [38.0, 7.1, Color(0.75, 0.3, 0.2)],
			[50.0, 4.7, Color(0.85, 0.6, 0.2)]]:
		decor_cylinder(Vector3(jar[0], jar[1], -4.0), 0.55, 1.1, Color(0.7, 0.75, 0.7))
		decor_glow_box(Vector3(jar[0], jar[1], -3.9), Vector3(0.7, 0.7, 0.5), jar[2], 0.6)
	# Sacks slumped against the wall.
	for sack in [[2.5, -3.6], [48.0, -3.7]]:
		var lump := decor_box(Vector3(sack[0], 1.0, sack[1]), Vector3(2.4, 2.2, 1.6),
			Color(0.7, 0.62, 0.5), "speckle", 1.1)
		lump.rotation.z = 0.12
	# Spilled flour drifted at the sack's foot, and sugar near the crate.
	decor_scatter(Vector3(20.0, 0.12, 0.8), Vector3(2.4, 0.04, 1.1), 18,
		Color(0.92, 0.9, 0.84), 0.1, "speckle", 55)
	decor_scatter(Vector3(44.0, 0.12, 0.7), Vector3(2.0, 0.04, 1.0), 14,
		Color(0.95, 0.95, 0.92), 0.08, "speckle", 56)
	# Onion strings hanging from the top shelf.
	decor_chain(Vector3(25.0, 9.0, -3.2), 8, Color(0.75, 0.55, 0.3), 0.2)
	decor_chain(Vector3(55.0, 9.0, -3.2), 6, Color(0.75, 0.55, 0.3), 0.2)


## The soft panel across the route: the level's own lesson made load-bearing.
## Required damage 2 = a HEAVY bare bite — no weapon can be demanded here, but
## the room is wall-to-wall food, so the weight is always on offer.
func _build_weight_door() -> void:
	var panel := decor_breakable(Vector3(31.5, 1.55, 0), Vector3(1.1, 3.1, 3.2), 2, 2, "grain")
	panel.too_weak_hint = "TOO SOFT A HIT - EAT UP FIRST!"
	# A crack of the far half glowing through it.
	decor_glow_box(Vector3(32.3, 0.6, -0.6), Vector3(0.3, 1.2, 1.2),
		Color(1.0, 0.85, 0.55), 0.8)


## In FRONT of the play plane: jars and tins on a near shelf edge, sweeping
## past the camera. Same rules as everywhere: narrow, sparse, and OFF the
## Toad's arena — that fight is about a tongue you have to read.
func _build_foreground() -> void:
	const FORE := Color(0.05, 0.04, 0.03)
	decor_box(Vector3(28, -1.6, 3.2), Vector3(70, 2.0, 1.0), FORE)
	decor_cylinder(Vector3(5.0, 0.9, 3.1), 0.7, 3.0, FORE)
	decor_cylinder(Vector3(18.0, 0.6, 3.05), 0.5, 2.4, FORE)
	decor_cylinder(Vector3(33.0, 1.1, 3.15), 0.62, 3.4, FORE)
	decor_cylinder(Vector3(45.0, 0.7, 3.05), 0.45, 2.6, FORE)
	# A rolling pin leant across the top of frame, short of the arena.
	decor_pipe_run(Vector3(2.0, 10.2, 3.4), Vector3(40.0, 9.2, 3.4), 0.4,
		FORE, true, false)
	decor_scatter(Vector3(22.0, -0.4, 3.15), Vector3(12.0, 0.2, 0.3), 12, FORE, 0.2, "concrete", 57)
