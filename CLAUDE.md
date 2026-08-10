# Cockroach Colonization — CLAUDE.md

2.5D action-platformer (Godot 4.7, GDScript): cute toy-style cockroach Harry in a giant
dangerous house. 3D rendering, gameplay locked to the X/Y plane. Ships as an HTML5 web
build on GitHub Pages. Full design brief: **GAME.md** (note: brief says 2D — superseded
by the 3D pivot, see docs/ARCHITECTURE.md). Deferred work: **BACKLOG.md**.

- Live game: https://droptop.github.io/cockroach-colonization/ (repo must stay PUBLIC or Pages dies)
- Repo: github.com/droptop/cockroach-colonization (main = source, gh-pages = build only)
- Levels (chained via `next_scene`): drain → street → kitchen → counter (current end).

## Commands

```bash
godot --path .                                                  # run (desktop)
godot --headless --path . --import                              # reimport after asset/script adds
godot --headless --path . --script tests/smoke_test_3d.gd      # drain traversal test
python3 tools/generate_audio.py                                 # regenerate all SFX wavs
godot --headless --path . --export-release "Web" build/web/index.html   # web export
./deploy_web.sh <path-to-godot>                                 # export + delta-deploy to gh-pages
```

Godot 4.7.1 **is installed** on this Mac at `~/Applications/Godot.app/Contents/MacOS/Godot`
(not on PATH — use the full path, or alias `godot` to it). Web export templates for 4.7.1
are in `~/Library/Application Support/Godot/export_templates/`. If a future session finds
neither present, re-fetch from godotengine.org or GitHub releases + `xattr -dr
com.apple.quarantine`.

## Architecture

- `player/player_3d.gd` — ALL movement/combat/growth/weapon/shield tuning as @exports.
  Self-contained (no player singleton — co-op later). Weapon loadout: `collected_weapons`
  (cycled with N/M), `WEAPON_STATS` dict (damage/cooldown/reach per id), held-weapon prop
  is a pivot rebuilt from `WeaponVisuals.build_weapon()` on change. Shield: `has_shield` +
  `shield_kind` ("cap"/"pan", cosmetic only — both halve damage via `take_damage`).
  `apply_slow(factor)` is a duck-typed hook (like `take_damage`) hazards call every frame
  to slow the player; self-clears if not re-applied.
- `items/weapon_visuals.gd` (`WeaponVisuals`) — static mesh builder shared by ground
  pickups (`items/weapons/*_pickup_3d.gd`) and the player's held/worn visuals, so what's
  on the floor is exactly what Harry holds, just scaled up.
- `world/levels/level_3d.gd` — level base: spawn/death/exit wiring, level chaining,
  ceiling, music, decor helpers (`decor_*`, `hazard_drip`, `decor_granny_hazard`).
  Each level .tscn = geometry (Block3D StaticBody3D nodes, the only collidable pieces) +
  instanced pickups/enemies; its .gd = `_build_decor()` non-collidable set dressing.
- `world/hazards/` — `DripEmitter3D` (toxic drips) and `GrannyHazard` (fly-swatter slam +
  insecticide cloud, GAME.md §11): pure-script Node3D hazards, no `.tscn`, added via a
  `Level3D` decor helper. Granny is NOT a boss — a level-scoped environmental threat that
  telegraphs then attacks wherever the player currently is (no ground-raycast needed).
- `enemies/` — spider, ant, fly, rat boss: standalone CharacterBody3D FSMs (deliberately
  no shared base). Rat drops a crown on death → `GameManager.unlock_achievement()`.
- `world/props3d/` — @tool scripts that BUILD their own meshes/collision (Block3D,
  Bin3D, Pipe3D, ParallaxBackdrop). All placeholder visuals are procedural mesh builders;
  zero imported models shipped so far (a user-generated Meshy GLB candidate for Harry
  exists but isn't wired in — see BACKLOG).
- `world/fx.gd` (Fx) — static one-shots: impact_text, spark_burst, ghost.
- `autoload/` — GameManager (signal bus + babies_banked + achievements + web debug
  heartbeat), AudioManager (SFX pool/music/wings), `snd.gd` (Snd) static facade.
- `ui/hud/` — hearts (true half-heart split rendering), wing bar, weapon/shield labels,
  scorecard, touch controls, vignette; `ui/title/` intro.
- User-supplied art lands in `user_added_images/` → copy into `art/` before wiring.

## Conventions

- Duck-typed interactions: anything with `take_damage(amount, from_pos)` can be hurt,
  `apply_slow(factor)` can be slowed, `collect_food/collect_fruit/add_wing_energy/
  carry_baby/collect_weapon/collect_shield` on the player. No interfaces.
- Damage never physically collides player↔enemy (separate layers; Hitbox Areas deal contact).
- Collision layers: 1 world, 2 player, 3 enemy, 4 hazard, 5 pickup.
- Tunables are @exports; keep them out of hard-coded logic.
- Web-safe text only in world/HUD labels (ASCII arrows etc. — default font has no ● ♥ →).
- One-off verification: write a throwaway `check_*.gd` SceneTree script to the session
  scratchpad, run via `godot --headless --script`, delete when done. Don't commit these —
  they're confidence checks for one change, not regression tests (those belong in `tests/`).

## Key decisions (and why)

- **Compatibility renderer + shadows OFF + 0.75 3D scale**: software-GL browsers choke
  on shadow maps (was <1fps). Flat-lit low-poly + baked-in normal-map textures instead.
- **`Snd.sfx()` facade, never `AudioManager.` directly in gameplay code**: autoloads
  don't exist as compile-time globals under the `--script` test harness; direct refs
  break EVERY dependent script's compilation. Same reasoning applies to `GameManager` —
  guard with `get_node_or_null("/root/GameManager")` in anything that runs unconditionally
  (e.g. HUD `_ready()`), not the bare global, or it breaks headless tests too.
- **Weapons/shields are level-scoped**, resetting on death/respawn like food/growth already did.
- **Weapon/shield pickups respawn** (~14s) like food, instead of being one-time.
- **Procedural textures + normal maps** (`Block3D.textured_material`): speckle/grain/
  checker/brick generated from FastNoiseLite at load; tinted per surface; triplanar.
- **Wing energy is the universal resource**: flying drains it, ANY hit costs 18, food
  refills (crumbs +14/fruit +45), food also fattens (slower/heavier) — intended tension.
- **Deploys are delta-pushes**: force-pushing the 40MB wasm fresh hits "remote end hung
  up"; clone gh-pages, overwrite, commit, push (usually only index.html+pck change).

## Gotchas / do NOT

- **Pushes lie**: git can print "Everything up-to-date" while the push silently failed.
  ALWAYS verify: `git ls-remote origin <branch>` vs local SHA, or clone fresh and check
  the commit log — do this even when a deploy script prints "Deployed".
- **Test harness has no autoloads** (SceneTree `--script` mode). See Snd/GameManager note above.
- **GDScript compiles function bodies lazily**: `--import` parses top-level declarations
  (enough to register `class_name` globals) but won't catch a type error buried in a
  function body — that only surfaces when the script is actually instantiated/run. Don't
  trust a clean `--import` alone; run a real scene/script that exercises the new code.
- **Headless SceneTree idle-frame count ≠ fixed real time**: `_process` frames in
  `--headless --script` mode can run much faster than 60/s (nothing throttles them).
  Don't assume "N frames ≈ N/60 seconds" for timing-based test waits — use generous
  margins, or key off `get_tree().create_timer(...).timeout` directly.
- Session scratchpad is wiped between sessions — never keep the Godot binary or the
  pages-clone only there. Durable checks belong in `tests/` (still not rebuilt — see BACKLOG).
- Don't parent procedural leg/limb meshes to the visual root — attach to their pivots
  (the "spider has no legs" bug).
- Don't overlap glow/decor meshes with wall faces (z-fighting flicker) — offset ≥0.05.
- Don't re-enable DirectionalLight shadows. Don't set fly_acceleration ≤ gravity (26).
- MP3 music: set `stream.loop = true` at load (AudioManager handles it).
- `.gitignore` excludes `build/`; never commit build output to main (it happened once —
  if a stray "Deploy:" commit appears on main, reset it away).

## Immediate next steps

See [BACKLOG.md](BACKLOG.md) "Now" for the full list. Top items: rebuild the lost headless
checks as committed `tests/` files, a playtest/balance pass (weapons, Granny, level 4
platforming), decide the leftover `cockroach-colonization-play` repo's fate, reskin
kitchen's exit decor to match its new "onto the counter" text.
