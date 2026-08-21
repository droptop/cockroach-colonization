class_name BaseBoss3D
extends CharacterBody3D

## Shared contract for Big Bosses: health, an arena, and the three signals a
## level needs to gate its exit on.
##
## Deliberately thin. Every boss keeps its own FSM, its own attacks and its own
## defeat mechanic, because what makes something a boss is HOW you beat it —
## sharing that is exactly what turns bosses into re-skinned enemies with more
## health. This base owns only the bookkeeping that a level and the HUD need to
## be able to ask about in a uniform way.
##
## Subclasses run their FSM in `_physics_process` as usual, call `super()` from
## `_ready()`, and override the `_on_*` hooks for their own juice. They must NOT
## reimplement `take_damage` — override `_on_damaged` instead, or the level will
## never hear that the fight has started.

## The fight has begun — the level shows the boss bar and may lock the arena.
signal engaged
## Boss is down. The level's exit unlocks on this, after `_on_defeated` plays out.
signal defeated
signal boss_health_changed(current: int, max_value: int)

@export var boss_name := "BOSS"
## Stable key for the save file. Leave empty and this boss simply never
## persists — it will be there again next session.
@export var boss_id := ""
@export var max_health := 8
## Some bosses cannot be hurt by weapons at all — see GrannyBoss3D, where what
## you whittle down is patience, not hit points.
@export var immune_to_damage := false
## How far either side of its spawn point the boss will range.
@export var arena_half_width := 4.5
## Height above the boss origin for its floating health bar. A screen-wide bar
## at the top of the HUD never said WHOSE health it was, which mattered most on
## the Queen: her fight is about hitting the webs rather than her, so a bar that
## did not move with her read as damage you were doing to the wrong thing.
@export var health_bar_height := 1.9
## What it bursts into when it dies.
@export var boss_crumb_drop := 8
@export var boss_fruit_drop := 3
## It calls for help as it loses ground: a wave at each of these fractions of
## its health, once each. Three at a time rather than ten, because every add
## still answers to Encounter's two-attacker cap, so a bigger crowd would just
## queue up off-screen and cost draw calls without ever reaching him.
@export var summon_at := PackedFloat32Array([0.7, 0.5, 0.2])
@export var summon_count := 3
## How far above it they drop in from.
@export var summon_height := 7.0
@export var summon_spread := 4.5

var health := 8
var is_defeated := false
## Where the boss started — the centre of its arena. Set in `_ready`, so
## subclasses must call `super()` before using it.
var arena_origin := Vector3.ZERO

var _engaged := false
var _summoned := {}
var _bar: Node3D
var _bar_label: Label3D


func _ready() -> void:
	health = max_health
	arena_origin = global_position
	_build_health_bar()


## Floats over the boss and stays hidden until the fight starts, so it does not
## give away a boss the player has not met yet.
func _build_health_bar() -> void:
	_bar = EnemyHealthBar.new()
	_bar.position = Vector3(0, health_bar_height, 0)
	_bar.scale = Vector3(2.2, 2.2, 1.0) # bosses read bigger than the mooks
	_bar.visible = false
	add_child(_bar)
	_bar_label = Label3D.new()
	_bar_label.text = boss_name
	_bar_label.font_size = 44
	_bar_label.pixel_size = 0.006
	_bar_label.position = Vector3(0, health_bar_height + 0.42, 0)
	_bar_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bar_label.no_depth_test = true
	_bar_label.modulate = Color(1, 0.85, 0.85)
	_bar_label.outline_size = 8
	_bar_label.visible = false
	add_child(_bar_label)


func _set_bar_visible(shown: bool) -> void:
	if _bar:
		_bar.visible = shown
	if _bar_label:
		_bar_label.visible = shown


func _refresh_bar() -> void:
	if _bar and _bar.has_method("set_ratio") and max_health > 0:
		_bar.set_ratio(float(health) / float(max_health))


## Left and right bounds of the arena in world X.
func arena_bounds() -> Vector2:
	return Vector2(arena_origin.x - arena_half_width, arena_origin.x + arena_half_width)


## Idempotent: call it freely from whatever the boss treats as "noticing" the
## player. Fires once.
func engage() -> void:
	if _engaged or is_defeated:
		return
	_engaged = true
	engaged.emit()
	boss_health_changed.emit(health, max_health)
	_refresh_bar()
	_set_bar_visible(true)
	_on_engaged()


## `cause` is accepted and ignored here — it only decides the PLAYER's
## death message. Taking it keeps one duck-typed signature across
## everything that can be hurt, so a caller never has to ask what it is
## hitting before it hits it.
func take_damage(amount: int, from_position: Vector3, _cause := "") -> void:
	if is_defeated:
		return
	engage() # being hit counts as noticing
	if immune_to_damage or _absorbs(amount, from_position):
		_on_damage_shrugged(amount, from_position)
		return
	lose_health(amount, from_position)


## The one route health comes off. `take_damage` is only the common driver of
## it; a boss beaten by something other than weapons calls this directly.
func lose_health(amount: int, from_position := Vector3.ZERO) -> void:
	if is_defeated:
		return
	health = maxi(health - amount, 0)
	boss_health_changed.emit(health, max_health)
	_refresh_bar()
	_check_summons()
	_on_damaged(amount, from_position)
	if health <= 0:
		_set_bar_visible(false)
		# The payoff for the whole fight, and it has to read as bigger than the
		# two crumbs an ant leaves.
		FoodBurst.spawn(get_parent(), global_position, boss_crumb_drop, boss_fruit_drop)
		is_defeated = true
		SaveGame.mark_boss_defeated(boss_id)
		defeated.emit()
		_on_defeated()


## Has it dropped past a threshold it has not called at yet?
func _check_summons() -> void:
	if is_defeated or summon_count <= 0 or max_health <= 0:
		return
	var fraction := float(health) / float(max_health)
	for i in summon_at.size():
		if _summoned.has(i):
			continue
		if fraction <= summon_at[i]:
			_summoned[i] = true
			_summon_wave()
			return


## They come down out of the roof around it. Deliberately the ordinary enemies
## rather than copies of the boss: what makes a boss a boss here is HOW you beat
## it, and a small one that could be killed the normal way would teach the wrong
## answer to its own fight.
func _summon_wave() -> void:
	var level := get_parent()
	if level == null or not level.is_inside_tree():
		return
	Snd.sfx("locked", -2.0, 0.15)
	Fx.impact_text(level, global_position + Vector3(0, 2.2, 0),
		Color(1.0, 0.6, 0.35), "IT'S CALLING FOR HELP!", 0.9)
	# load(), not preload(). preload resolves at COMPILE time, and the ant scene
	# carries a script that reaches back into the same class graph this file is
	# part of, so the scene could be mid-parse when it is asked for and comes
	# back as a "non-existent resource". The symptom is an ant that silently
	# cannot be instantiated, which is not obviously about this line at all.
	var scene := load("res://enemies/ant/ant_3d.tscn") as PackedScene
	if scene == null:
		return
	for i in summon_count:
		var add := scene.instantiate()
		level.add_child(add)
		var t: float = (float(i) + 0.5) / float(summon_count)
		var drop := global_position + Vector3(
			lerpf(-summon_spread, summon_spread, t), summon_height, 0.0)
		(add as Node3D).global_position = drop
		Fx.spark_burst(level, drop, Color(0.9, 0.7, 0.4))


# --- subclass hooks ----------------------------------------------------------

func _on_engaged() -> void:
	pass


func _on_damaged(_amount: int, _from_position: Vector3) -> void:
	pass


func _on_defeated() -> void:
	pass


## Reject THIS hit, as opposed to all of them. `immune_to_damage` is a standing
## state; this is per-blow, for a boss that can be hurt but only from somewhere
## specific — see MantisBoss3D, which guards its front.
func _absorbs(_amount: int, _from_position: Vector3) -> bool:
	return false


## Hit while immune, or absorbed. Somewhere to say "that did nothing" out loud,
## so the player learns where the answer isn't.
func _on_damage_shrugged(_amount: int, _from_position: Vector3) -> void:
	pass
