# Cockroach Colonization — CLAUDE.md

2.5D action-platformer (Godot 4.7.1, GDScript): toy-style cockroach Harry in a giant
dangerous house. 3D rendering, gameplay locked to the X/Y plane. Ships as an HTML5 web
build on GitHub Pages. Design brief: **GAME.md** (says 2D — superseded by the 3D pivot,
see docs/ARCHITECTURE.md). Deferred work: **BACKLOG.md**. Audio briefs: **docs/audio-brief.md**.

- Live: https://droptop.github.io/cockroach-colonization/ (repo must stay PUBLIC or Pages dies)
- **Two channels on gh-pages**: `/` stable, `/preview/` working. Deploys go to
  preview; `--promote` copies the played preview to stable.
- Repo: github.com/droptop/cockroach-colonization (main = source, gh-pages = build only)
- Levels (chained via `next_scene`): drain → street → kitchen → counter → granny kitchen
  → tabletop. **All six are boss-gated.**
- **Budget for this file: 215 lines** (was 200; raised 2026-08-23 on the user's call to
  capture everything). Loaded every session, so length is a real cost — but the Gotchas
  below are each a bug that actually shipped, and cutting them costs more than it saves.
  Prune stale steps and prose first, never a gotcha.

## Commands

```bash
godot --path .                                                  # run (desktop)
godot --headless --path . --import                              # reimport after asset/script adds
for t in tests/*.gd; do godot --headless --path . --script "$t"; done   # whole suite (50)
python3 tools/generate_audio.py                                 # regenerate placeholder SFX
./deploy_web.sh <godot>                # export + delta-deploy to the PREVIEW url
./deploy_web.sh <godot> --promote      # copy that preview to the stable url
```

Godot 4.7.1 is at `~/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH). Web export
templates in `~/Library/Application Support/Godot/export_templates/`. If missing, re-fetch
from godotengine.org + `xattr -dr com.apple.quarantine`.

## Architecture

- `player/player_3d.gd` — ALL movement/combat/growth/weapon/shield tuning as @exports.
  Self-contained (no player singleton — co-op later). 9 weapons in `WEAPON_STATS` across
  6 verbs (melee/launch/ready/charge/reflect/throw), cycled N/M. Shield halves damage.
- `items/weapon_visuals.gd` — mesh builder shared by ground pickups and held visuals.
- `world/levels/level_3d.gd` — level base: spawn/death/exit, chaining, music, `decor_*`
  helpers, `_style_hints()`, `ending_scene` for the last level. **Exit gate**: `ExitState`
  + `boss_path` (empty = open, so nothing regresses by default). Arena walls drop the
  instant the player dies, or death seals him out of an unfinished fight.
  Each level .tscn = Block3D geometry (the only collidable pieces) + instanced
  pickups/enemies/`Hints`; its .gd = `_build_decor()` non-collidable dressing.
- `enemies/` — spider, ant, fly: standalone CharacterBody3D FSMs (deliberately no shared
  base). All answer `stagger()`; bosses deliberately do not.
- `world/encounters/climber_wave_3d.gd` — run-up gauntlets that climb up over a ledge.
- `enemies/base_boss_3d.gd` — thin contract: health, `arena_bounds()`, `engaged`/`defeated`.
  Owns NO FSM and no attacks on purpose; what makes a boss a boss is *how* you beat it, and
  sharing that turns bosses into re-skinned enemies. **Six bosses, six verbs**: rat = *when*
  to hit · Granny = don't be hit (SURVIVE a countdown; she cannot be hurt) · cat = *what*
  to hit (the paw) · Queen = hit something *else* first (the webs) · mantis = from *where*
  (frontal guard) · wasp = stand *where* (bait into syrup, then MOVE).
  Each carries a `boss_rule`, shown on engage and at the swing when a hit is shrugged.
- `world/encounter.gd` (`Encounter`) — static fairness rules for enemies with no shared
  base: no attacks from beyond `ON_SCREEN_X` (6.5), at most `MAX_ATTACKERS` (2) at once,
  `bump()` to shove an enemy off Harry. The token count is a scene-tree GROUP, not a
  counter, so an enemy killed mid-lunge cannot leak a slot.
- `world/hazards/` — `hazard_pool_3d.gd` is ONE volume behind acid, spray, venom and
  water; its radius derives from the visible mesh so the hurtbox can never exceed what you
  see (min height 0.2, or he wades through untouched). Also `drip_emitter_3d.gd`,
  `drain_flush_3d.gd`. `GrannyHazard` is level-scoped, NOT a boss.
- `world/props3d/` — @tool scripts that BUILD their own meshes/collision (Block3D, Pipe3D,
  LightShaft3D, Checkpoint3D, BreakableBlock3D...). Zero imported models. Block3D styles:
  speckle/grain/checker/brick/asphalt/concrete, with generated normal + AO.
- Hints are hand-placed `Label3D` nodes under `Hints`, read for text and position only:
  `Level3D` shows the nearest one on a HUD line rather than in the world.
- `world/fx.gd` (Fx) — static one-shots: `impact_text`, `spark_burst`, `ghost`, `shatter`
  (breaks a thing into its own meshes), `hit_flash` (material_overlay), `hit_stop` (on a
  timer that IGNORES time_scale — without that flag, time_scale 0 locks the game).
- `items/rewards/` — hearts/wing shards (LEFT behind if he's full) and `LostGhost3D`.
  `items/food/food_burst.gd` is the death fountain; burst food never respawns.
  `items/babies/baby_visual_3d.gd` is a CHEAP 5-draw roach: followers are on screen in
  every level at once, so they must never wear the player model (21 draws each).
- `autoload/` — GameManager (signal bus, babies_banked, achievements), AudioManager
  (SFX pool/music/wings, buses built at runtime), `snd.gd` (Snd) + `settings.gd` +
  `save_game.gd` static facades. `SFX` maps a hook to one sample; `SFX_VARIANTS` adds
  extra takes that `play_sfx` picks among at random, for the sounds that repeat hardest
  (`step`, `whoosh`). Never for looped keys: those hold one stream with a loop point.
- `ui/hud/` — hearts, wing bar, weapon/shield labels, proximity hint line, touch controls,
  pause menu (MUSIC / SOUND FX / MESSAGES / RESUME). `ui/title/` — CONTINUE vs NEW GAME.
- `ui/fonts/` — Iron Dice Grit; Regular default, Bold/Black per-Label overrides.
- User art lands in `user_added_images/` → copy into `art/` before wiring. Raw asset kits
  stay in staging folders, excluded from export (`iron-dice-font /` — the trailing space
  is real — and `Roach Game SFX/`). New recordings drop in over `audio/sfx_<name>.wav`
  with no code change.

## Conventions

- Duck-typed, no interfaces: `take_damage(amount, from_pos, cause := "")` (third arg
  OPTIONAL so older callers still work; picks the death message), `apply_slow(factor)`,
  `collect_*`/`restore_health`/`recover_lost`/`set_checkpoint` on the player.
- `add_wing_energy` / `restore_health` RETURN whether they changed anything, so a pickup
  can say "FULL!" and stay put rather than vanishing silently.
- Damage never physically collides player↔enemy (separate layers; Hitbox Areas deal contact).
- Collision layers: 1 world, 2 player, 3 enemy, 4 hazard, 5 pickup.
- Tunables are @exports. Web-safe ASCII only in world/HUD labels.
- One-off checks: throwaway `check_*.gd` in the scratchpad, run headless, delete. Don't
  commit them — regressions belong in `tests/`.

## Key decisions (and why)

- **Compatibility renderer + shadows OFF + 0.75 3D scale**: software-GL browsers choke on
  shadow maps (was <1fps). Flat-lit low-poly + baked normal/AO textures instead.
- **`Snd.sfx()` facade, never `AudioManager.` in gameplay code**: autoloads aren't
  compile-time globals under `--script`. Same for `GameManager` — guard with
  `get_node_or_null("/root/GameManager")`.
- **Weapons/shields are level-scoped**; pickups respawn (~14s), like food.
- **Wing energy is the universal resource**: flying drains it, ANY hit costs 18, food
  refills and fattens (slower/heavier) — intended tension. Weight buys knockback
  resistance, +1 damage, breakable walls.
- **Deploys are delta-pushes**: force-pushing the wasm fresh hits "remote end hung up";
  clone gh-pages, overwrite, commit, push. Preview by default, `--promote` for stable.
- **Font weights**: Black = display moments, Bold = HUD readouts + title CTA, Regular =
  default and quiet secondary text. User's explicit call.

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
- **A test that reads `user://save.cfg` is not hermetic and its numbers drift.**
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

`tests/` holds 50 headless suites, all `extends SceneTree`, printing `ok`/`FAIL` and
exiting non-zero. Anything that kills a boss or writes settings must repoint
`SaveGame.save_path` / `Settings.settings_path` at a scratch file first.

**Completability tests** (`tests/support/level_completable.gd`, which the glob skips, plus
one per level) BEAT the boss with real button presses, WALK to the exit and wait for the
next scene. Boss tests that POKE the boss all passed while Granny was unbeatable, the
Queen unhittable and the pantry parked on the door.

Write assertions that fail for the *right* reason, and prefer generic invariants over
feature tests — the perf budget, reachability, destructible-reachable, audio-registry and
input-map checks each caught a real shipped bug that every feature test passed.

## Immediate next steps

The user **plays the live build**; those reports are the primary signal.

- **Completable AND it ends** (2026-08-23), proven by tests that play every level to
  the exit. Nobody has finished it by HAND.
- **Every boss states its rule** on engage and at the swing when a hit is shrugged.
- **Open, the user's calls**: zero-hearts-while-alive (NOT reproduced; shielded hits
  suspected); tabletop 6.69 draws/m with 8 babies vs a 6.5 ceiling; the drain shaft
  dead-ends 0.15 m under a solid pipe at y 8.0.
- Deferred work: **BACKLOG.md**, in priority order, 1 to 55.
