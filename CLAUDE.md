# Cockroach Colonization — CLAUDE.md

2.5D action-platformer (Godot 4.7.1, GDScript): toy-style cockroach Harry in a giant
dangerous house. 3D rendering, gameplay locked to the X/Y plane. Ships as an HTML5 web
build on GitHub Pages. Design brief: **GAME.md** (says 2D — superseded by the 3D pivot,
see docs/ARCHITECTURE.md). Deferred work: **BACKLOG.md**. Audio briefs: **docs/audio-brief.md**.

- Live: https://droptop.github.io/cockroach-colonization/ (repo must stay PUBLIC or Pages dies)
- Repo: github.com/droptop/cockroach-colonization (main = source, gh-pages = build only)
- Levels (chained via `next_scene`): drain → street → kitchen → counter → granny kitchen
  → tabletop. **All six are boss-gated.**

## Commands

```bash
godot --path .                                                  # run (desktop)
godot --headless --path . --import                              # reimport after asset/script adds
for t in tests/*.gd; do godot --headless --path . --script "$t"; done   # whole suite (32)
python3 tools/generate_audio.py                                 # regenerate placeholder SFX
./deploy_web.sh <path-to-godot>                                 # export + delta-deploy to gh-pages
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
  helpers, `_style_hints()`. **Exit gate**: `ExitState` enum + `boss_path` (empty = open,
  so nothing regresses by default). Raises/drops arena walls — down the instant the player
  dies, or death seals him out of an unfinished fight.
  Each level .tscn = Block3D geometry (the only collidable pieces) + instanced
  pickups/enemies/`Hints`; its .gd = `_build_decor()` non-collidable dressing.
- `enemies/` — spider, ant, fly: standalone CharacterBody3D FSMs (deliberately no shared base).
- `enemies/base_boss_3d.gd` — thin contract: health, `arena_bounds()`, `engaged`/`defeated`.
  Owns NO FSM and no attacks on purpose; what makes a boss a boss is *how* you beat it, and
  sharing that turns bosses into re-skinned enemies. **Six bosses, six verbs**: rat = *when*
  to hit · Granny = don't be hit (patience drains on her MISSES) · cat = *what* to hit (the
  paw) · Spider Queen = hit something *else* first (the webs) · mantis = from *where*
  (frontal guard) · wasp = stand *where* (bait it into syrup).
- `world/encounter.gd` (`Encounter`) — static fairness rules for enemies with no shared
  base: nothing commits to an attack from further than `ON_SCREEN_X` (6.5, measured off the
  real camera rig), and at most `MAX_ATTACKERS` (2) attack at once. The token count is a
  scene-tree GROUP, not a counter, so an enemy killed mid-lunge cannot leak a slot.
- `world/hazards/hazard_pool_3d.gd` — ONE volume behind acid, spray, venom and water.
  Radius derived from the visible mesh in a single function, so the hurtbox can never
  exceed what you can see. `GrannyHazard` is level-scoped, NOT a boss.
- `world/props3d/` — @tool scripts that BUILD their own meshes/collision (Block3D, Bin3D,
  Pipe3D, ParallaxBackdrop, LightShaft3D, Checkpoint3D, BreakableBlock3D). All visuals
  procedural; zero imported models shipped. Block3D styles: speckle/grain/checker/brick/
  asphalt/concrete, each with generated normal + baked AO maps.
- `world/props3d/hint_bubble_3d.gd` — static styler `Level3D` applies to each `Label3D`
  under `Hints`: wraps the text and puts a rounded panel behind it. Hints stay plain
  Label3D nodes editable in the editor; one file changes how all 18 look.
- `world/fx.gd` (Fx) — static one-shots: `impact_text`, `spark_burst`, `ghost`,
  `hit_flash` (material_overlay, never touches real materials), `hit_stop` (on a timer
  that IGNORES time_scale — without that flag, time_scale 0 locks the game), `impact()`.
- `items/rewards/` — hearts/wing shards (LEFT behind if he's full) and `LostGhost3D`
  (crumbs, fruit **and weight**, waiting where he fell).
- `autoload/` — GameManager (signal bus, babies_banked, achievements), AudioManager
  (SFX pool/music/wings, buses built at runtime), `snd.gd` (Snd) + `settings.gd` +
  `save_game.gd` static facades. `SFX` maps a hook to one sample; `SFX_VARIANTS` adds
  extra takes that `play_sfx` picks among at random, for the sounds that repeat hardest
  (`step`, `whoosh`). Never for looped keys: those hold one stream with a loop point.
- `ui/hud/` — hearts, wing bar, weapon/shield labels, touch controls, and the pause menu
  (MUSIC / SOUND FX / MESSAGES / RESUME). `ui/title/` — CONTINUE vs NEW GAME.
- `ui/fonts/` — Iron Dice Grit; Regular is the default, Bold/Black per-Label overrides.
- User art lands in `user_added_images/` → copy into `art/` before wiring; raw asset kits
  stay in their own staging folder (`iron-dice-font /` — the trailing space is real).

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
  compile-time globals under `--script`; direct refs break every dependent script. Same for
  `GameManager` — guard with `get_node_or_null("/root/GameManager")`.
- **Weapons/shields are level-scoped**; pickups respawn (~14s), like food.
- **Wing energy is the universal resource**: flying drains it, ANY hit costs 18, food
  refills and also fattens (slower/heavier) — intended tension. Weight buys knockback
  resistance, +1 damage, and access to breakable walls.
- **Deploys are delta-pushes**: force-pushing the wasm fresh hits "remote end hung up";
  clone gh-pages, overwrite, commit, push.
- **Font weights**: Black = display moments, Bold = HUD readouts + title CTA, Regular =
  default and quiet secondary text. User's explicit call.

## Gotchas / do NOT

- **Pushes lie**: git can print "Everything up-to-date" while the push failed. ALWAYS
  verify `git ls-remote origin <branch>` vs local SHA — even when a deploy script says
  "Deployed". For the web build, diff the served `index.pck` md5 against the built one.
- **An Area3D does NOT report a `StaticBody3D`** in `get_overlapping_bodies()` (nor a
  frozen RigidBody3D). It sees `CharacterBody3D` and `AnimatableBody3D`. Every attack
  volume is an Area, so anything damageable must be one of those two — `AnimatableBody3D`
  extends StaticBody3D and collides identically, so it's a drop-in. This SHIPPED: the
  Queen's webs, the cat's paw and both breakable walls were unhittable for weeks.
- **Driving damage with `thing.take_damage(...)` in a test proves nothing** about whether
  a player can hit it. That convenience hid the bug above across four suites. If a thing
  is meant to be hit, at least one test must press the attack button.
- **`play_sfx()` returns SILENTLY on an unknown key** — a typo is an inaudible bug, not an
  error. `audio_hooks_test` now scans the source for unregistered names and orphaned files.
- **Browsers swallow Escape**, so any action bound only to Escape is unreachable in the
  shipped build. The pause menu (and the audio toggles inside it) was unreachable this way.
  `input_map_test` guards it.
- **A scripted `str.replace` that doesn't match fails SILENTLY.** Assert on every replace
  and re-read to verify. Prefer ordered-occurrence over line numbers — line numbers go
  stale mid-session. Shell: `python3 - <<PY ... PY` then `git commit` on the next LINE
  commits even when the Python died — chain with `&&`.
- **A child's `_ready` runs BEFORE its parent's** — a node can't add siblings during its
  own `_ready`. Use `call_deferred` (why the Queen spun zero webs).
- **An Area3D's overlaps only refresh on a physics step.** Moving an area and querying it
  the same frame sweeps where it *used* to be. Tests driving attacks must wait in REAL
  SECONDS, and should wait for the *event*, not a fixed interval.
- **Headless idle-frame count ≠ real time**: `_process` in `--script` mode runs far faster
  than 60/s. Never assume N frames ≈ N/60 s.
- **GDScript compiles function bodies lazily**: a clean `--import` won't catch a type error
  inside a function body. Run something that exercises the code.
- Don't parent procedural limb meshes to the visual root — attach to their pivots.
- Don't overlap glow/decor meshes with wall faces (z-fighting) — offset ≥0.05.
- Don't re-enable DirectionalLight shadows. Don't set fly_acceleration ≤ gravity (26).
- Export uses `export_filter="all_resources"` — Godot ships EVERY file under the project
  root, including staging folders and `tests/`. Add `exclude_filter` entries, and keep
  orphaned assets out (3 dead music wavs were 2.5 MB of the build).
- `.gitignore` excludes `build/`; never commit build output to main.

## Testing

`tests/` holds 32 headless suites, all `extends SceneTree`, printing `ok`/`FAIL` and
exiting non-zero. Anything that kills a boss or writes settings must repoint
`SaveGame.save_path` / `Settings.settings_path` at a scratch file first.

Write assertions that fail for the *right* reason, and prefer generic invariants over
feature tests — the perf budget, reachability, destructible-reachable, audio-registry and
input-map checks each caught a real shipped bug that every feature test passed.

## Immediate next steps

The user **plays the live gh-pages build** and reports from it; those reports are the
primary signal. Do not claim the game is unplayed.

- **Pending answer**: whether MUSIC/SOUND FX read OFF in the user's browser (the cause of
  "all audio disappeared" — the toggles were unreachable until `P` was bound).
- **Real audio is in** as of 2026-08-20: 45 user recordings cover 35 of 38 hooks. Only
  `rat_cry`, `mantis_cry` and `mantis_hurt` are still synthesised placeholders. A file
  still drops in over `audio/sfx_<name>.wav` with no code change. See docs/audio-brief.md.
- **Spider Queen tuning**: now beatable (one flight per anchor, ~3 flights + a fruit).
  Whether that's fun needs a play, not another guess.
- Eyeball Iron Dice Grit at HUD sizes (13–14 px) in a browser.
