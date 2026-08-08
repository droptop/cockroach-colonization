# Architecture decisions

## 2026-08-08 — 3D pivot

Per the designer's direction (chunky low-poly 3D reference art), the game moved
from 2D rendering to **3D with gameplay locked to the X/Y plane**
(`axis_lock_linear_z` on all CharacterBody3D). Decisions:

- `player/player_3d.gd` is a straight port of the tuned 2D controller
  (metres instead of pixels, +Y up). The 2D version stays in the repo as
  reference until the 3D feel is signed off.
- Placeholder characters/props are **built in code** (@tool scripts creating
  primitive meshes): `roach_visual_3d.gd` (procedurally animated legs/antennae),
  `spider_visual_3d.gd`, `world/props3d/` (Block3D, Bin3D, Pipe3D). No imported
  assets yet — swap for real models later without touching gameplay.
- `world/levels/level_3d.gd` base class: spawn/death/exit wiring + level
  chaining via `next_scene`, plus decor helper functions. Levels:
  drain -> street -> kitchen.
- Spider3D is self-contained (no shared BaseEnemy with 2D) — forcing a common
  base across 2D/3D fights both.
- **Shadow mapping is OFF** in all levels: it destroyed performance on
  software-GL browsers (the web target), and flat-lit low-poly reads fine.
  3D renders at 0.75 scale (`rendering/scaling_3d/scale`).

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
