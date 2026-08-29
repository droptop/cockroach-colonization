extends Level3D

## Level 12 — The Moon. The saucer's hold opens and there is nothing to hold
## him down: gravity drops to a third, every hop is a flight, and the dust
## goes on forever under a black sky with the whole Earth hanging in it.
## The gaps here are wider than anything in the house because HE is lighter
## than he has ever been - the level is a playground for the one physics
## change, and then the dust starts moving.
##
## THE DUST WORM swims the far basin: twelfth verb, UNBURY. It hunts
## footsteps (walk without rhythm), shrugs everything while buried, and
## only flops mortal once the mound itself is smacked open.

## A third of Earth's pull, near enough. Set on the player at spawn;
## fly_acceleration (44) stays far above it, per the tuning rule.
const MOON_GRAVITY := 8.0
const MOON_FALL_SPEED := 7.0


func _ready() -> void:
	super()
	var p := get_node_or_null("Player")
	if p:
		p.gravity = MOON_GRAVITY
		p.max_fall_speed = MOON_FALL_SPEED


func _build_decor() -> void:
	_build_sky()
	_build_dust()
	_build_lander()
	decor_light(Vector3(18, 8, 3), Color(0.75, 0.78, 0.9), 0.7, 30.0)
	decor_light(Vector3(52, 7, 3), Color(0.8, 0.78, 0.7), 0.6, 24.0)
	decor_checkpoint(Vector3(40.5, 0.6, 1.4))
	_build_foreground()


## The Earth, whole, hanging where the moon usually goes. The one thing on
## this level worth homesickness.
func _build_sky() -> void:
	var earth := decor_box(Vector3(14, 18, -22), Vector3(0.1, 0.1, 0.1), Color(1, 1, 1))
	var globe := SphereMesh.new()
	globe.radius = 4.2
	globe.height = 8.4
	globe.radial_segments = 16
	globe.rings = 8
	var sea := Block3D.flat_material(Color(0.25, 0.45, 0.85))
	sea.emission_enabled = true
	sea.emission = Color(0.2, 0.4, 0.8)
	sea.emission_energy_multiplier = 0.35
	globe.material = sea
	earth.mesh = globe
	# Continents: green patches riding proud of the sea, offset past z-fights.
	for patch in [[12.6, 19.4, 0.9], [15.3, 17.2, 1.2], [13.4, 16.6, 0.7]]:
		decor_box(Vector3(patch[0], patch[1], -18.6),
			Vector3(patch[2], patch[2] * 0.7, 0.3), Color(0.3, 0.6, 0.3))
	decor_scatter(Vector3(30, 22, -26), Vector3(50, 8, 2), 60,
		Color(0.95, 0.95, 1.0), 0.07, "none", 12)


func _build_dust() -> void:
	# Crater rims and old bootprints (whose?) along the walking line.
	for rim in [[6.0, 1.6], [21.0, 2.2], [35.0, 1.8], [50.0, 2.6], [61.0, 1.9]]:
		decor_scatter(Vector3(rim[0], 0.25, -0.8), Vector3(rim[1], 0.3, 1.0), 10,
			Color(0.58, 0.57, 0.54), 0.16, "concrete", int(rim[0]))
	for print_x in [9.0, 10.1, 11.2]:
		decor_box(Vector3(print_x, 0.06, 0.6), Vector3(0.5, 0.08, 0.25),
			Color(0.5, 0.5, 0.48))
	# Grey hills against the black, and dead slow dust motes.
	decor_box(Vector3(32, 2.4, -12), Vector3(90, 9, 1.5), Color(0.16, 0.16, 0.17), "speckle", 0.4)
	decor_motes(Vector3(30, 3, 0), Vector3(30, 3, 2), Color(0.8, 0.8, 0.78, 0.18), 20)


## A derelict lander on legs, mid-level: somebody was here first and left.
func _build_lander() -> void:
	decor_box(Vector3(33.0, 2.5, -3.4), Vector3(2.6, 1.8, 2.2), Color(0.72, 0.72, 0.75), "speckle", 1.2)
	decor_glow_box(Vector3(33.9, 2.9, -2.2), Vector3(0.3, 0.3, 0.1), Color(0.9, 0.3, 0.2), 1.4)
	for leg in [[31.8, -4.4], [34.2, -2.4]]:
		decor_pipe_run(Vector3(leg[0], 0.0, leg[1]),
			Vector3(leg[0] + 0.6, 1.7, leg[1] + 0.6), 0.12,
			Color(0.6, 0.6, 0.64), true, false)
	# The flag, standing stiff with no wind to ask.
	decor_pipe_run(Vector3(37.5, 0.2, -3.0), Vector3(37.5, 3.4, -3.0), 0.06,
		Color(0.7, 0.7, 0.72), true, false)
	decor_box(Vector3(38.3, 3.1, -3.0), Vector3(1.5, 0.9, 0.08), Color(0.85, 0.3, 0.3))


func _build_foreground() -> void:
	const FORE := Color(0.05, 0.05, 0.06)
	decor_box(Vector3(31, -1.9, 3.2), Vector3(80, 2.0, 1.0), FORE)
	decor_scatter(Vector3(30, -0.6, 3.2), Vector3(24, 0.3, 0.3), 16, FORE, 0.22, "concrete", 44)
	# Near boulders, so the parallax has something to slide past.
	for boulder in [[5.0, 0.8], [18.0, 1.2], [33.0, 0.7], [49.0, 1.1], [63.0, 0.9]]:
		decor_box(Vector3(boulder[0], -0.7 + boulder[1] * 0.4, 3.15),
			Vector3(boulder[1], boulder[1] * 0.8, 0.6), FORE, "concrete", 0.6)
