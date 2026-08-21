class_name Level3D
extends Node3D

## Base for 3D levels: wires spawn/death/exit, shows intro text, chains to the
## next level. Subclasses build their decorative set dressing in _build_decor().

signal exit_state_changed(state: ExitState)

## EXPLORE -> LEARN -> ESCALATE -> BOSS -> REWARD -> EXIT, as a state on the
## level's way out. Advances in order and never goes back within a life.
enum ExitState { UNLOCKED, LOCKED, BOSS_ACTIVE, BOSS_DEFEATED, TRANSITION }

@export_file("*.tscn") var next_scene := ""
@export var intro_message := ""
@export var complete_message := "LEVEL COMPLETE"
## Invisible ceiling so climbing + flying can't leave the level.
@export var ceiling_height := 14.0
@export_file("*.wav", "*.mp3") var music_track := ""

@export_group("Boss gate")
## This level's Big Boss. Leave it empty and the exit is open from the start —
## which is how every level behaved before gating existed, so nothing regresses
## by default. Point it at a BaseBoss3D and the way out stays shut until that
## boss goes down.
@export var boss_path := NodePath()
## Shown when the player reaches a still-locked exit. Never fail silently: the
## player has to learn WHY they can't leave.
@export var locked_message := "No way out yet - something in here has to go first!"
## How long the defeat sequence gets before the exit actually opens.
@export var defeat_sequence_time := 1.6
## Wall the player into the fight once it starts. Only ever raised on `engaged`
## and always dropped on `defeated`, so a boss that never dies cannot leave him
## sealed in a room with it forever.
@export var lock_arena := true

@onready var _player: Player3D = $Player
@onready var _hud: CanvasLayer = $HUD

var exit_state := ExitState.UNLOCKED
var _boss: Node
var _arena_walls: Node3D
## Hand-placed Label3D hints, read for their text and their position only.
var _hint_labels: Array[Label3D] = []
## How close he has to be for a hint to apply.
@export var hint_range := 7.0


func _ready() -> void:
	_player.spawn_position = $SpawnPoint.global_position
	_player.global_position = _player.spawn_position
	$DeathZone.body_entered.connect(_on_death_zone_body_entered)
	$ExitZone.body_entered.connect(_on_exit_zone_body_entered)
	if intro_message != "":
		_hud.show_message(intro_message, 3.0)
	_add_ceiling()
	_spawn_following_babies()
	_player.babies_changed.connect(_on_babies_changed)
	_wire_boss()
	_build_decor()
	_style_hints()
	Snd.music(music_track)


## The in-world hints are hand-placed Label3D nodes under a "Hints" node in
## each level scene. They get their bubble and their line wrapping here, at
## load, rather than in six .tscn files — one place to change how a hint looks,
## and no scene surgery to keep in step.
##
## The whole group also answers the MESSAGES toggle in the pause menu, via the
## "hints" group rather than a signal: the HUD can then flip every hint in the
## running level without needing to know which level it is.
func _style_hints() -> void:
	var hints := get_node_or_null("Hints")
	if hints == null:
		return
	if not hints.is_in_group("hints"):
		hints.add_to_group("hints")
	# The bubbles themselves stay DOWN. Standing the advice in the level put it
	# physically in front of the thing it was advising about, which is what made
	# the drain feel cluttered. The labels are still the source of the text and
	# still say where it applies; only the presentation moved to the HUD.
	for child in hints.get_children():
		if child is Label3D:
			_hint_labels.append(child)
	hints.visible = false

## Babies that were following when the last level ended fall back in behind him
## here. Respawned rather than carried between scenes: a baby is a count, not a
## snowflake, and change_scene_to_file frees the old ones regardless. Connect
## the signal AFTER this runs, or the spawn writes to disk once per baby.
func _spawn_following_babies() -> void:
	for i in SaveGame.babies_banked():
		var baby := BabyFollower3D.new()
		add_child(baby)
		baby.global_position = _player.global_position - Vector3(0.6 * (i + 1), 0.0, 0.0)
		_player.adopt_baby(baby)


func _on_babies_changed(count: int) -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.babies_banked = count
	SaveGame.set_babies_banked(count)


## Levels with no boss declared stay UNLOCKED and behave exactly as before.
func _wire_boss() -> void:
	if boss_path.is_empty():
		return
	_boss = get_node_or_null(boss_path)
	if _boss == null:
		push_warning("boss_path set to '%s' but no such node — exit left unlocked." % boss_path)
		return
	# Already beaten in an earlier session: don't make them do it twice.
	if "boss_id" in _boss and SaveGame.is_boss_defeated(_boss.boss_id):
		_boss.queue_free()
		_boss = null
		return
	_set_exit_state(ExitState.LOCKED)
	if _boss.has_signal("defeated"):
		_boss.defeated.connect(_on_boss_defeated)
	if _boss.has_signal("engaged"):
		_boss.engaged.connect(_on_boss_engaged)
	# The boss carries its own bar above its head now (BaseBoss3D), so the
	# screen-wide one at the top of the HUD is not connected. The HUD still has
	# the methods: reconnecting these two lines brings it back.


func _set_exit_state(state: ExitState) -> void:
	if exit_state == state:
		return
	exit_state = state
	exit_state_changed.emit(state)


func _on_boss_engaged() -> void:
	_set_exit_state(ExitState.BOSS_ACTIVE)
	if lock_arena and _boss.has_method("arena_bounds"):
		_raise_arena_walls(_boss.arena_bounds())


## Invisible bookends at the arena edges, so the fight is a fight rather than
## something you walk away from. Not decor — these collide.
func _raise_arena_walls(bounds: Vector2) -> void:
	if _arena_walls != null:
		return
	_arena_walls = Node3D.new()
	add_child(_arena_walls)
	# The floor he is standing on when it seals, so the gates land at his feet
	# rather than at some fixed height that only suits one arena.
	var floor_y: float = _player.global_position.y if _player else 0.0
	# The BOSS has to end up inside its own arena. The mantis wanders, and the
	# walls go up where the arena says rather than where it happens to be, so it
	# could be sealed out of its own fight: you stand in an empty box while it
	# paces on the far side of a wall you cannot pass. Nothing recovers from
	# that except dying.
	if _boss is Node3D:
		var boss_node := _boss as Node3D
		var margin := 1.0
		var inside_x: float = clampf(boss_node.global_position.x,
			bounds.x + margin, bounds.y - margin)
		if not is_equal_approx(inside_x, boss_node.global_position.x):
			boss_node.global_position.x = inside_x
	for x in [bounds.x, bounds.y]:
		var wall := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.0, 40.0, 24.0)
		collision.shape = shape
		wall.add_child(collision)
		wall.position = Vector3(x, 10.0, 0)
		_arena_walls.add_child(wall)
		_build_sluice(x, floor_y)
	Snd.sfx("impact_heavy", 2.0, 0.1)


## A sluice gate that SLAMS down, because an invisible wall is not a rule the
## player can see. They would walk into nothing, bounce, and have no idea why.
## The collision is still the invisible box above; this is what tells them.
func _build_sluice(x: float, floor_y: float) -> void:
	# Tall enough to read as a wall and DEEP enough to reach the bottom of the
	# frame: a gate that stopped at the ledge left a gap under it that looked
	# passable and was not.
	const GATE_H := 9.0
	const GATE_W := 0.72
	var gate := Node3D.new()
	_arena_walls.add_child(gate)

	var rust := Block3D.textured_material(Color(0.34, 0.26, 0.21), "grain", 1.6)
	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(GATE_W, GATE_H, 2.4)
	plate_mesh.material = rust
	plate.mesh = plate_mesh
	gate.add_child(plate)

	# Ribs down the face, so it reads as a gate and not a slab.
	var dark := Block3D.flat_material(Color(0.19, 0.15, 0.12))
	for i in 7:
		var rib := MeshInstance3D.new()
		var rib_mesh := BoxMesh.new()
		rib_mesh.size = Vector3(GATE_W + 0.06, 0.22, 2.5)
		rib_mesh.material = dark
		rib.mesh = rib_mesh
		rib.position = Vector3(0, -GATE_H * 0.5 + 0.8 + i * 1.25, 0)
		gate.add_child(rib)

	# A frame at the top it drops out of.
	var lintel := MeshInstance3D.new()
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(GATE_W + 0.5, 0.5, 2.7)
	lintel_mesh.material = dark
	lintel.mesh = lintel_mesh
	lintel.position = Vector3(0, GATE_H * 0.5 + 0.25, 0)
	gate.add_child(lintel)

	# Buried below the floor line so there is never a gap under the gate.
	var seated := Vector3(x, floor_y + GATE_H * 0.5 - 2.4, 0)
	gate.position = seated + Vector3(0, GATE_H + 1.0, 0)
	var tween := gate.create_tween()
	tween.tween_property(gate, "position", seated, 0.34
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func() -> void:
		Fx.spark_burst(self, seated + Vector3(0, -GATE_H * 0.5, 0),
			Color(0.7, 0.6, 0.5)))


## The walls have to answer to the PLAYER's state, not just the boss's. Dying
## respawns him outside the arena, and walls that only drop on defeat would seal
## him out of a fight he still has to win — an unwinnable level, not a hard one.
func _process(_delta: float) -> void:
	_update_hint()
	if not lock_arena or _boss == null or not is_instance_valid(_boss):
		return
	if _boss.is_defeated:
		return
	if _player.is_dead:
		_drop_arena_walls()
		return
	if exit_state != ExitState.BOSS_ACTIVE or not _boss.has_method("arena_bounds"):
		return
	# Two thresholds, not one, and they fix two separate ways this locked up.
	#
	# DROP the moment he is outside at all. Knockback from a venom spit could
	# put him past the bound, and the walls only ever went up: he was then shut
	# OUT of a fight he still had to win, by a 1 unit thick invisible box he
	# could neither see nor pass. Death was handled above; being knocked out
	# was not.
	#
	# RAISE only once he is well inside, because a wall spawned on the exact
	# spot he is standing engulfs him. Crossing the bound put him at x = 37.05
	# with the wall occupying 36.5 to 37.5, which reads as shoving through
	# treacle at an invisible barrier.
	const REENTRY_MARGIN := 1.6
	var bounds: Vector2 = _boss.arena_bounds()
	var x := _player.global_position.x
	if x <= bounds.x or x >= bounds.y:
		_drop_arena_walls()
		return
	if _arena_walls == null and x > bounds.x + REENTRY_MARGIN and x < bounds.y - REENTRY_MARGIN:
		_raise_arena_walls(bounds)


## Nearest hint wins, so two that overlap cannot flicker against each other.
func _update_hint() -> void:
	if _hud == null or not _hud.has_method("show_hint"):
		return
	if _player == null or not is_instance_valid(_player):
		return
	var best := ""
	var best_distance := hint_range
	for label in _hint_labels:
		if not is_instance_valid(label):
			continue
		var d := _player.global_position.distance_to(label.global_position)
		if d < best_distance:
			best_distance = d
			best = label.text
	_hud.show_hint(best)


func _drop_arena_walls() -> void:
	if _arena_walls == null:
		return
	# Collision goes NOW: the whole point is that he is never held by something
	# he cannot see. The gates then wind back up and free themselves.
	var going := _arena_walls
	_arena_walls = null
	for child in going.get_children():
		if child is StaticBody3D:
			(child as StaticBody3D).process_mode = Node.PROCESS_MODE_DISABLED
			for sub in child.get_children():
				if sub is CollisionShape3D:
					(sub as CollisionShape3D).disabled = true
	var tween := going.create_tween()
	tween.tween_property(going, "position", Vector3(0, 7.0, 0), 0.45
		).set_ease(Tween.EASE_IN)
	tween.tween_callback(going.queue_free)


func _on_boss_defeated() -> void:
	_set_exit_state(ExitState.BOSS_DEFEATED)
	_drop_arena_walls()
	if _hud.has_method("hide_boss_bar"):
		_hud.hide_boss_bar()
	# Let the defeat sequence breathe before the way out opens.
	await get_tree().create_timer(defeat_sequence_time).timeout
	_set_exit_state(ExitState.UNLOCKED)
	_hud.show_message("The way out is clear!", 2.2)
	_claim_exit_if_standing_in_it()


## `body_entered` fires on the way IN and never again. Beat a boss while stood
## on the exit — which is exactly where you end up, since the arena and the way
## out are the same corner of the level — and the door opens behind you with
## nothing left to trigger it. You then have to walk off the exit and back onto
## it, with no way to know that. It read as "the level will not let me leave".
##
## An Area3D's overlaps only refresh on a physics step, so this asks after one.
func _claim_exit_if_standing_in_it() -> void:
	await get_tree().physics_frame
	if exit_state != ExitState.UNLOCKED:
		return
	var zone := get_node_or_null("ExitZone")
	if zone == null:
		return
	for body in (zone as Area3D).get_overlapping_bodies():
		_on_exit_zone_body_entered(body)


func _add_ceiling() -> void:
	var ceiling := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(500, 2, 24)
	collision.shape = shape
	ceiling.add_child(collision)
	ceiling.position = Vector3(24, ceiling_height + 1.0, 0)
	add_child(ceiling)


func _build_decor() -> void:
	pass # subclasses add set dressing here


func _on_death_zone_body_entered(body: Node3D) -> void:
	if body.has_method("fall_into_pit"):
		body.fall_into_pit()


func _on_exit_zone_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or exit_state == ExitState.TRANSITION:
		return
	if exit_state != ExitState.UNLOCKED:
		_hud.show_message(locked_message, 1.8)
		Snd.sfx("locked", -6.0)
		return
	_set_exit_state(ExitState.TRANSITION)
	$ExitZone.set_deferred("monitoring", false)
	Snd.sfx("level_up", 2.0, 0.0)
	if _player.has_method("bank_babies"):
		# Not handed over and freed any more — they walk out with him and are
		# waiting in the next level.
		var following: int = _player.bank_babies()
		if following > 0:
			var gm := get_node_or_null("/root/GameManager")
			if gm:
				gm.babies_banked = following
			SaveGame.set_babies_banked(following)
			complete_message += "  (%d %s came with you!)" % [
				following, "baby" if following == 1 else "babies"]
	if next_scene != "":
		SaveGame.set_furthest_level(next_scene)
		_hud.show_message(complete_message, 0.0)
		await get_tree().create_timer(1.4).timeout
		get_tree().change_scene_to_file(next_scene)
	else:
		var gm := get_node_or_null("/root/GameManager")
		if gm:
			gm.complete_level()
		_hud.show_message(complete_message, 0.0)


# --- decor helpers -----------------------------------------------------------

func decor_box(pos: Vector3, size: Vector3, color: Color, style := "none", density := 0.5) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Block3D.textured_material(color, style, density)
	inst.mesh = mesh
	inst.position = pos
	add_child(inst)
	return inst


## A decor box you can also stand on. Reuses Block3D rather than bolting a
## collider onto a MeshInstance, so a platform added from a level script gets
## the same lip and texturing as one hand-placed in the scene — a surface
## should not advertise which file it was created in.
func decor_platform(pos: Vector3, size: Vector3, top: Color, base: Color,
		style := "speckle", density := 0.5) -> Block3D:
	var block := Block3D.new()
	block.size = size
	block.top_color = top
	block.base_color = base
	block.texture_style = style
	block.texture_density = density
	block.position = pos
	add_child(block)
	return block


## Something in the way that can be hit out of the way. `required_damage`
## decides who gets through: a bare bite is 1, a knife 3, and a HEAVY Harry adds
## 1 to whatever he holds — so a wall can be gated on the build rather than on
## an item.
func decor_breakable(pos: Vector3, size: Vector3, required_damage := 2,
		hits := 2, style := "concrete") -> BreakableBlock3D:
	var block := BreakableBlock3D.new()
	block.size = size
	block.required_damage = required_damage
	block.hits_to_break = hits
	block.texture_style = style
	block.position = pos
	add_child(block)
	return block


func decor_cylinder(pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.material = Block3D.flat_material(color)
	inst.mesh = mesh
	inst.position = pos
	add_child(inst)
	return inst


## A pipe running between two points, with a flange at each end. The workhorse
## for depth layers: the same call makes a near-black bar sweeping across the
## foreground and a lit pipe run back behind the play plane.
## `flanges` off halves the draw cost of a run — worth doing wherever the pipe
## is an unlit black silhouette, since a flange on a shape with no shading is
## not visible anyway.
## `solid` gives the run a collider, turning a decorative pipe into somewhere to
## stand. Only worth it near the play plane — a pipe at z=-3 is scenery no
## matter what collision it has, since the player is locked to z=0.
func decor_pipe_run(from: Vector3, to: Vector3, radius: float, color: Color,
		unlit := false, flanges := true, solid := false) -> Node3D:
	var run := Node3D.new()
	var dir := to - from
	var length := dir.length()
	if length < 0.001:
		return run
	var mat := Block3D.flat_material(color)
	if unlit:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var parts := [[radius, length]]
	if flanges:
		parts.append([radius * 1.25, 0.3])
	for part in parts:
		var inst := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = part[0]
		mesh.bottom_radius = part[0]
		mesh.height = part[1]
		mesh.radial_segments = 10
		mesh.material = mat
		inst.mesh = mesh
		run.add_child(inst)
		if part[1] < length: # the flange: copy it to the far end too
			inst.position.y = -length / 2.0
			var far := inst.duplicate() as MeshInstance3D
			far.position.y = length / 2.0
			run.add_child(far)
	run.position = (from + to) * 0.5
	# CylinderMesh runs along +Y; swing that onto the from→to direction. A
	# cylinder is symmetric, so a parallel axis needs no rotation at all.
	var d := dir / length
	var axis := Vector3.UP.cross(d)
	if axis.length_squared() > 0.000001:
		run.rotate(axis.normalized(), Vector3.UP.angle_to(d))
	if solid:
		_make_pipe_walkable(run, length, radius)
	add_child(run)
	return run


## A box hugging the top of the pipe rather than a capsule around it: this is a
## 2.5D platformer, and what the player needs is a surface to land on, not a
## cylinder to slide off.
func _make_pipe_walkable(run: Node3D, length: float, radius: float) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(radius * 1.7, length, 3.4)
	collision.shape = box
	body.add_child(collision)
	run.add_child(body)


## Many small identical chunks — rubble, grit, chain links — in ONE draw call.
## Repeated props must never cost a draw call each: the web build runs on
## software GL, where draw calls are the budget. Seeded, so a level looks the
## same every load.
func decor_scatter(center: Vector3, extents: Vector3, count: int, color: Color,
		chunk_size := 0.22, style := "concrete", rng_seed := 1) -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * chunk_size
	mesh.material = Block3D.textured_material(color, style, 3.0)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for i in count:
		var basis := Basis.from_euler(Vector3(
			rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU)))
		basis = basis.scaled(Vector3(
			rng.randf_range(0.5, 1.7), rng.randf_range(0.4, 1.1), rng.randf_range(0.5, 1.4)))
		var offset := Vector3(
			rng.randf_range(-extents.x, extents.x),
			rng.randf_range(-extents.y, extents.y),
			rng.randf_range(-extents.z, extents.z))
		multi.set_instance_transform(i, Transform3D(basis, center + offset))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = multi
	add_child(inst)
	return inst


## Chain hanging from a point, as one draw call. Links alternate their yaw so
## the run reads as interlocking rather than as a stack of blocks.
func decor_chain(top: Vector3, links: int, color: Color, link_size := 0.16) -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(link_size, link_size * 1.6, link_size * 0.5)
	mesh.material = Block3D.flat_material(color)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = links
	for i in links:
		var basis := Basis.from_euler(Vector3(0.0, PI / 2.0 * (i % 2), 0.0))
		multi.set_instance_transform(i, Transform3D(
			basis, top + Vector3(0.0, -i * link_size * 1.3, 0.0)))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = multi
	add_child(inst)
	return inst


func decor_glow_box(pos: Vector3, size: Vector3, color: Color, energy := 1.6) -> MeshInstance3D:
	var inst := decor_box(pos, size, color)
	var mat := (inst.mesh as BoxMesh).material as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return inst


## Slow ambient drifting particles (spores, dust, fireflies) — cheap
## atmosphere, kage-style.
func decor_motes(center: Vector3, extents: Vector3, color: Color, amount := 24) -> CPUParticles3D:
	var motes := CPUParticles3D.new()
	motes.amount = amount
	motes.lifetime = 7.0
	motes.preprocess = 7.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = extents
	motes.direction = Vector3(0, 1, 0)
	motes.spread = 180.0
	motes.initial_velocity_min = 0.04
	motes.initial_velocity_max = 0.22
	motes.gravity = Vector3(0.06, 0.03, 0.0)
	motes.scale_amount_min = 0.5
	motes.scale_amount_max = 1.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 0.8
	mesh.material = mat
	motes.mesh = mesh
	motes.position = center
	add_child(motes)
	return motes


## Shaft of street light falling in through a sewer cap or storm drain above.
## `pos` is the opening (the cover is built there); the beam hangs down from it.
## Underground levels get their outside light this way instead of windows —
## windows belong to the street and the house.
func decor_light_shaft(pos: Vector3, shaft_height: float, color := Color(0.66, 0.86, 1.0),
		cap := "manhole", bottom_radius := 2.6, tilt := 0.0) -> LightShaft3D:
	var shaft := LightShaft3D.new()
	shaft.position = pos
	shaft.shaft_height = shaft_height
	shaft.beam_color = color
	shaft.cap_style = cap
	shaft.bottom_radius = bottom_radius
	shaft.tilt_degrees = tilt
	add_child(shaft)
	return shaft


## Somebody upstairs empties a bucket down the drain. Put it under a grate.
func hazard_flush(pos: Vector3, every := 11.0) -> DrainFlush3D:
	var flush := DrainFlush3D.new()
	flush.position = pos
	flush.interval = every
	add_child(flush)
	return flush


## The run-up to a boss: a crowd that climbs up out of the dark. Put the trigger
## where he crosses INTO the approach, and `pos` at the lip they come over.
func decor_climber_wave(pos: Vector3, waves := 3, per_wave := 2,
		span := 7.0) -> ClimberWave3D:
	var wave := ClimberWave3D.new()
	wave.position = pos
	wave.waves = waves
	wave.per_wave = per_wave
	wave.span = span
	wave.started.connect(func() -> void:
		if _hud and _hud.has_method("show_message"):
			_hud.show_message("THE COLONY IS COMING UP!", 1.8)
		Snd.sfx("locked", 0.0, 0.1))
	wave.cleared.connect(func() -> void:
		if _hud and _hud.has_method("show_message"):
			_hud.show_message("THE WAY UP IS CLEAR", 1.6))
	add_child(wave)
	return wave


## Somewhere safe: moves the respawn point and banks what he is carrying.
## Put one before anything that kills repeatedly — a boss run-up especially,
## since a gated exit means dying there otherwise re-walks the whole level.
func decor_checkpoint(pos: Vector3, color := Color(0.55, 0.9, 0.7)) -> Checkpoint3D:
	var point := Checkpoint3D.new()
	point.position = pos
	point.color = color
	add_child(point)
	return point


func hazard_drip(pos: Vector3, color: Color, drip_interval := 2.4) -> DripEmitter3D:
	var emitter := DripEmitter3D.new()
	emitter.position = pos
	emitter.drop_color = color
	emitter.interval = drip_interval
	add_child(emitter)
	return emitter


## "GRANNY IS COMING" — a level-scoped environmental hazard, not a boss
## (GAME.md §11). See GrannyHazard for the attack logic.
func decor_granny_hazard() -> GrannyHazard:
	var hazard := GrannyHazard.new()
	hazard.hud = _hud
	hazard.player = _player
	add_child(hazard)
	return hazard


func decor_light(pos: Vector3, color: Color, energy := 1.2, light_range := 9.0) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	add_child(light)
	return light
