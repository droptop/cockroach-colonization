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

var health := 8
var is_defeated := false
## Where the boss started — the centre of its arena. Set in `_ready`, so
## subclasses must call `super()` before using it.
var arena_origin := Vector3.ZERO

var _engaged := false


func _ready() -> void:
	health = max_health
	arena_origin = global_position


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
	_on_engaged()


func take_damage(amount: int, from_position: Vector3) -> void:
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
	_on_damaged(amount, from_position)
	if health <= 0:
		is_defeated = true
		SaveGame.mark_boss_defeated(boss_id)
		defeated.emit()
		_on_defeated()


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
