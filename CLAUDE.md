# Cockroach Colonization — CLAUDE.md

2.5D action-platformer (Godot 4.7.1, GDScript): toy-style cockroach Harry, drain to MARS.
3D rendering, gameplay locked to the X/Y plane; ships as HTML5 on GitHub Pages. Brief:
**GAME.md** (2D — superseded, see docs/ARCHITECTURE.md). Deferred: **BACKLOG.md**.

- Live: https://droptop.github.io/cockroach-colonization/ (repo must stay PUBLIC or Pages
  dies). Repo: github.com/droptop/cockroach-colonization (main = source, gh-pages = build
  only; `/` stable, `/preview/` working; deploys hit preview, `--promote` copies over).
- Levels (chained via `next_scene`): drain → street → kitchen → counter → granny kitchen
  → tabletop → pantry → roof → roof garden → tree → abduction → moon → ship → mars.
  **All fourteen are boss-gated**; mars ends at the ending screen (leaderboard).
- **Budget for this file: 215 lines** (user's call, 2026-08-23). Loaded every session, so
  length is a real cost — but each Gotcha below is a bug that actually shipped. Prune
  stale steps and prose first, never a gotcha.

## Commands

```bash
godot --path .                                                  # run (desktop)
godot --headless --path . --import                              # reimport after asset/script adds
for t in tests/*.gd; do godot --headless --path . --script "$t"; done   # whole suite (70)
python3 tools/generate_audio.py                                 # regenerate placeholder SFX
./deploy_web.sh <godot>                # export + delta-deploy to the PREVIEW url
./deploy_web.sh <godot> --promote      # copy that preview to the stable url
```

Godot 4.7.1: `~/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH). Web export
templates: `~/Library/Application Support/Godot/export_templates/` (if missing, re-fetch
+ `xattr -dr com.apple.quarantine`).

## Architecture

- `player/player_3d.gd` — ALL movement/combat/growth/weapon/shield tuning as @exports.
  Self-contained (no player singleton — co-op later). 9 weapons in `WEAPON_STATS` across
  6 verbs, cycled N/M; shields halve damage. `items/weapon_visuals.gd` builds the meshes.
- `world/levels/level_3d.gd` — level base: spawn/death/exit, chaining, music, `decor_*`
  helpers, run clock (banked at the door), `ending_scene`. **Exit gate**: `ExitState` +
  `boss_path` (empty = open). Arena walls drop the instant the player dies. Each .tscn =
  Block3D geometry (the only collidables) + pickups/enemies/`Hints`; .gd = `_build_decor()`.
- `enemies/` — spider, ant, fly + Mars-only hopper, gasbag: standalone CharacterBody3D
  FSMs (deliberately no shared base). All answer `stagger()`; bosses do not.
  `climber_wave_3d.gd` = ledge gauntlets. `brood_egg_3d.gd` = deniable spawn (crack it
  or it hatches; hatch is a Callable so no class-name cycles).
- `enemies/base_boss_3d.gd` — thin contract: health, `arena_bounds()`, `engaged`/`defeated`.
  Owns NO FSM and no attacks on purpose; what makes a boss a boss is *how* you beat it, and
  sharing that turns bosses into re-skinned enemies. **Fourteen bosses, fourteen verbs**:
  rat=when · Granny=don't-be-hit · cat=what · Queen=else-first · mantis=from-where ·
  wasp=stand-where · toad=feed · magpie=gloat · snail=flip · owl=freeze · probe=reflect ·
  worm=unbury · janitor=clog · tripod=topple. Each carries a `boss_rule` (shown on engage
  and shrugged swings); late bosses cap damage per vulnerable window or a mash one-shots.
- `world/encounter.gd` (`Encounter`) — static fairness rules: no attacks beyond
  `ON_SCREEN_X` (6.5), `MAX_ATTACKERS` 2, `bump()`. The token count is a scene-tree
  GROUP, not a counter, so an enemy killed mid-lunge cannot leak a slot.
- `world/hazards/` — `hazard_pool_3d.gd` is ONE volume behind acid/spray/venom/water/sap;
  radius derives from the visible mesh (min height 0.2, or he wades through untouched).
  Also `drip_emitter_3d.gd`, `drain_flush_3d.gd`, `wind_3d.gd`. `GrannyHazard` is
  level-scoped, NOT a boss.
- `world/props3d/` — @tool scripts that BUILD their own meshes/collision (Block3D, Pipe3D,
  LightShaft3D, Checkpoint3D, BreakableBlock3D...). Zero imported models. Block3D styles:
  speckle/grain/checker/brick/asphalt/concrete, with generated normal + AO.
- Hints: hand-placed `Label3D`s under `Hints`; `Level3D` shows the nearest on a HUD line.
- `world/fx.gd` (Fx) — static one-shots: `impact_text`, `spark_burst`, `ghost`, `shatter`
  (breaks a thing into its own meshes), `hit_flash` (material_overlay), `hit_stop` (on a
  timer that IGNORES time_scale — without that flag, time_scale 0 locks the game).
- `items/rewards/` — hearts/wing shards (LEFT behind if he's full), COINS (never "full",
  never expire; enemies drop 1, bosses `boss_coin_drop`), `LostGhost3D`. `food_burst.gd`
  is the death fountain; burst food never respawns. `baby_visual_3d.gd` is a CHEAP 5-draw
  roach: followers ride every level at once, never the 21-draw player model.
- `autoload/` — GameManager (signal bus, babies_banked, achievements), AudioManager (SFX
  pool/music/wings), `snd.gd` (Snd) + `settings.gd` + `save_game.gd` + `leaderboard.gd`
  static facades. `SFX` maps hook→sample; `SFX_VARIANTS` adds random extra takes for the
  hardest-repeating sounds. Never for looped keys: one stream with a loop point.
- `ui/hud/` — hearts, wing bar, weapon/shield/COINS/BABIES labels, hint line, touch
  controls, pause menu. `ui/title/` — CONTINUE vs NEW GAME + LEVEL SELECT (TESTING).
  `ui/shop/` — THE STASH between levels: coins buy RUN-scoped upgrades via
  `Player3D._apply_upgrades`/`twin_egg_bank`; NEW GAME clears them. Two-press buys
  (ARE YOU SURE?); colony matrix; statics on `ShopScreen` carry `next_scene`.
- `ui/fonts/` — Iron Dice Grit; Regular default, Bold/Black per-Label overrides.
- User art: stage in `user_added_images/`, ship a copy as `art/backgrounds/<level>_bg.jpeg`,
  wire a `ParallaxBackdrop` in `_build_decor` (9 of 14 levels painted). RETIRE the decor
  the painting replaces — anything deeper than the quad is invisible. Quads 50x33.3;
  60 wide on ~90 m levels (street, counter) or the edge shows at the far door. Crop
  letterbox bars off renders. ALL staging folders are export-excluded: `iron-dice-font /`
  (trailing space is real), `Roach Game SFX/`, `user_added_images/`. New recordings drop
  in over `audio/sfx_<name>.wav` with no code change (new SOUNDS need a registry key).

## Conventions

- Duck-typed, no interfaces: `take_damage(amount, from_pos, cause := "")` (third arg
  OPTIONAL; picks the death message), `apply_slow`, `apply_wind`, `web_wrap`,
  `collect_*`/`restore_health`/`recover_lost`/`set_checkpoint` on the player.
- `add_wing_energy`/`restore_health` RETURN whether they changed ("FULL!" pickups stay put).
- Damage never physically collides player↔enemy (separate layers; Hitbox Areas deal contact).
- Collision layers: 1 world, 2 player, 3 enemy, 4 hazard, 5 pickup.
- Tunables are @exports. Web-safe ASCII only in world/HUD labels.
- One-off checks: throwaway `check_*.gd` in the scratchpad, run headless, delete —
  regressions belong in `tests/`.

## Key decisions (and why)

- **Compatibility renderer + shadows OFF + 0.75 3D scale**: software-GL browsers choke on
  shadow maps (was <1fps). Flat-lit low-poly + baked normal/AO textures instead.
- **`Snd.sfx()` facade, never `AudioManager.` in gameplay code**: autoloads aren't
  compile-time globals under `--script`. Same for `GameManager`: `get_node_or_null`.
- **Weapons/shields are level-scoped**; pickups respawn (~14s), like food.
- **Wing energy is the universal resource**: flying drains it, ANY hit costs 18, food
  refills and fattens (slower/heavier) — intended tension. Weight buys knockback
  resistance, +1 damage, breakable walls, poo bombs.
- **Deploys are delta-pushes** (fresh force-push hits "remote end hung up": clone
  gh-pages, overwrite, commit, push) **and GATED on hittability** (user's call,
  2026-08-28): `deploy_web.sh` refuses to export until `hittable_on_plane_test`,
  `destructible_reachable_test` and every completability suite pass. `SKIP_TESTS=1`
  bypasses; never silently. The shipped wasm is drivable at `?gdtest=1` (GameManager
  publishes `window.__gd`, consumes `window.__gd_cmd`) — close "not possible" reports by
  observing the SERVED build, not by theory.
- **Font weights** (user's call): Black = display, Bold = HUD + title CTA, Regular = rest.

## Gotchas / do NOT

- **Runtime-created audio buses are SILENT in the web export.** `AudioServer.add_bus()`
  with players routed onto the new buses works on desktop (Master peaks at 8.3 dB) and
  produces ZERO samples on web, with no error. Everything plays on **Master**; muting is a
  gate in AudioManager (`_sfx_on` / `_music_on`). Never reintroduce custom buses without
  testing the WEB build — **desktop passing proves nothing about web audio**, which is
  what wrongly cleared them halfway through that hunt.
- **A boss on `collision_layer = 0` cannot be hit by anything.** An Area3D reports only
  bodies on a layer it masks. The Spider Queen and the cat both shipped this way. Guarded
  by the placed-boss check in `destructible_reachable_test`.
- **Boss tests that poke the boss prove nothing about finishing a level.** All of them
  passed while Granny was unbeatable and the Queen unhittable. A completability test beats
  the boss as a player does, WALKS to the exit, and waits for the next scene to load.
- **Things placed relative to a boss end up wherever the boss is.** Granny stands 6 m up
  a counter and the cat sits at z -6, so their spoils, food bursts AND summoned ants all
  landed unreachable. Anchor to the player's floor and the play plane: `spoils_origin()`.
- **`body_entered` fires on the way IN and never again.** Beat a boss while stood on the
  exit and the door opens behind you with nothing left to trigger it. Re-check overlaps
  when the exit unlocks.
- **Arena colliders must be FREED, not disabled.** `process_mode` does not touch
  collision, and assigning `CollisionShape3D.disabled` mid-physics is refused while
  queries flush. Both leave an invisible wall behind a lifted gate.
- **Pushes lie**: git can print "Everything up-to-date" while the push failed. ALWAYS
  verify `git ls-remote origin <branch>` vs local SHA — even when a deploy script says
  "Deployed". For the web build, diff the served `index.pck` md5 against the built one.
- **AnimatableBody3D with `sync_to_physics` ON swallows `global_position` teleports**
  outside a physics step (brood eggs all sat at x 0). Turn it off on code-placed bodies.
- **An Area3D does NOT report a `StaticBody3D`** in `get_overlapping_bodies()` (nor a
  frozen RigidBody3D). It sees `CharacterBody3D` and `AnimatableBody3D`. Every attack
  volume is an Area, so anything damageable must be one of those two. This SHIPPED on the
  Queen's webs, the cat's paw and both breakable walls.
- **Driving damage with `thing.take_damage(...)` in a test proves nothing** about whether
  a player can hit it. That convenience hid the bug above across four suites. If a thing
  is meant to be hit, at least one test must press the attack button.
- **`play_sfx()` returns SILENTLY on an unknown key** — a typo is an inaudible bug.
  `audio_hooks_test` scans for unregistered names and orphaned files, and must be told
  about any wrapper that forwards a hook name (e.g. Granny's `_say`).
- **Browsers eat keys** (Escape, Tab, F1/F3/F5/F6/F7/F11/F12, Backspace), so any action
  bound only to one is unreachable in the shipped build. Escape did it to the pause menu,
  F3 to the debug overlay. Every action needs a plain-letter or digit spare;
  `input_map_test` guards the class.
- **A scripted `str.replace` that doesn't match fails SILENTLY.** Assert on every replace.
  Prefer ordered-occurrence over line numbers. Shell: `python3 - <<PY ... PY` then
  `git commit` on the next LINE commits even when the Python died — chain with `&&`.
- **A `:=` parse error in a `class_name` script masquerades as an ENGINE HANG.**
  `var x := dict.key` or `:= arr[i]` (Variant → cannot infer) kills the script, the
  compile cascade kills every test touching it, the harness phase-loop retries a null
  forever, and PIPED stdout buffers the errors into silence. An hour of ghost-hunting,
  twice; `script -q` (a pty flushes live) exposed it in one run. Annotate the type,
  and give harness wait-loops a timeout.
- **A child's `_ready` runs BEFORE its parent's** — a node can't add siblings during its
  own `_ready`. Use `call_deferred` (why the Queen spun zero webs).
- **An Area3D's overlaps only refresh on a physics step.** Moving an area and querying it
  the same frame sweeps where it *used* to be. Tests driving attacks must wait in REAL
  SECONDS, and should wait for the *event*, not a fixed interval.
- **Headless idle-frame count ≠ real time**: `_process` in `--script` mode runs far faster
  than 60/s. Never assume N frames ≈ N/60 s. Hold DURATIONS in tests must be in real
  seconds: a 70-frame "hold jump" is long enough to JUMP and nowhere near long enough to
  CLIMB, which produced three separate false reports of levels being impassable.
- **GDScript compiles function bodies lazily**: a clean `--import` won't catch a type error
  inside a function body. Run something that exercises the code.
- **A duplicate `[node name="X"]` in a .tscn silently orphans the second block.** Level
  code reaches these by name (`_style_hints` does `get_node_or_null("Hints")` and walks
  that ONE node), so a scene declaring `Hints` twice loses everything in the second
  declaration. The street had 3 hints and delivered 1 for weeks; the two lost were
  correctly worded, correctly placed, and dead. `combos_taught_test` counts labels in the
  scene against labels the level collected.
- **A test that reads `user://save.cfg` is not hermetic and its numbers drift.** And the
  player reads bought UPGRADES off the save on spawn, so EVERY test that spawns him (or a
  level) needs the scratch save, not just the ones that write.
  `Level3D` spawns one follower per banked baby into EVERY level, so `perf_budget_test`
  silently measured whatever had last been played. Repoint `SaveGame.save_path` at a
  scratch file AND set the state you mean to measure.
- Don't parent procedural limb meshes to the visual root — attach to their pivots.
- Don't overlap glow/decor meshes with wall faces (z-fighting) — offset ≥0.05.
- Don't re-enable DirectionalLight shadows. Don't set fly_acceleration ≤ gravity (26).
- Export uses `export_filter="all_resources"` — Godot ships EVERY file under the project
  root, including staging folders and `tests/`. Add `exclude_filter` entries, and keep
  orphaned assets out (3 dead music wavs were 2.5 MB of the build).
- `.gitignore` excludes `build/`; never commit build output to main.

## Testing

`tests/` holds 70 headless suites, all `extends SceneTree`, printing `ok`/`FAIL` and
exiting non-zero; completability suites share `tests/support/level_completable.gd`.

Write assertions that fail for the *right* reason; prefer generic invariants — the perf,
reachability, destructible, audio-registry and input-map checks each caught a shipped bug.

## Immediate next steps

The user **plays the live build**; those reports are the primary signal.

- **Itinerary COMPLETE** (2026-08-30): 14 levels on PREVIEW, every live report closed.
- **Backdrops: 9 of 14 painted** (2026-09-01). Missing: kitchen (the user's render
  arrived as a 256px thumbnail — needs a full-size re-save), tabletop, roof garden,
  abduction, moon. Wire them exactly like the last seven (see User art, above).
- **STABLE is still the 7-level build.** Promote the moment the user says so.
- **Open**: zero-hearts-while-alive (#5, NOT reproduced; shielded hits suspected).
