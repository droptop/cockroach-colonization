# Architecture decisions

Phase 1 (movement prototype). See GAME.md for the full design brief.

## Decisions so far

- **Godot 4.x, GL Compatibility renderer** — chosen because the game's stated
  target includes running on a website; the Compatibility renderer is the one
  that exports cleanly to HTML5/web later. Desktop-first for Phase 1 per GAME.md.
- **Player is fully self-contained** (`player/player.gd` on a CharacterBody2D).
  Health, food, death and respawn all live on the player instance. Nothing
  reaches into a global "the player" singleton, so co-op stays possible (GAME.md §45).
- **GameManager autoload is a signal bus only** (`level_completed`, debug flag).
  Save/audio managers are deliberately not created yet (Phase 2+).
- **Enemies**: `BaseEnemy` (health/damage/death/flash) + per-enemy AI script with
  a plain enum FSM (`PATROL / CHASE / ATTACK / DEAD`). No FSM framework — the
  spider's states fit in one match statement. Revisit if enemy count grows.
- **Damage flows through duck typing**: anything with `take_damage(amount, from_position)`
  can be hurt; anything with `collect_food(value)` can eat. No shared interface class yet.
- **Collision layers**: 1 world, 2 player, 3 enemy, 4 hazard, 5 pickup.
  Player and enemies do NOT collide with each other physically — contact damage
  goes through the spider's Hitbox Area2D, so nobody gets physics-shoved.
- **Level geometry** is `world/props/platform.gd` (@tool StaticBody2D that draws
  its own rect and builds its own collision shape). Keeps level .tscn files tiny
  and hand-editable. Will be replaced by TileMap when real art arrives.
- **Placeholder visuals are `_draw()` scripts** (roach, spider, crumb), not
  sprites — zero assets to manage until the art direction pass.
- **Camera** is a child of the player: built-in position smoothing + a small
  look-ahead/shake script. If levels later need cameras detached from the
  player (boss rooms), move it out then.

## Tuning

All movement/combat numbers are `@export` vars on `player/player.gd` and
`enemies/spider/spider.gd` — tune them in the Inspector, no code edits needed.
