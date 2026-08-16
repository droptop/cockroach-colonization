# Cockroach Colonization — CLAUDE.md

2.5D action-platformer (Godot 4.7, GDScript): cute toy-style cockroach Harry in a giant
dangerous house. 3D rendering, gameplay locked to the X/Y plane. Ships as an HTML5 web
build on GitHub Pages. Full design brief: **GAME.md** (note: brief says 2D — superseded
by the 3D pivot, see docs/ARCHITECTURE.md). Deferred work: **BACKLOG.md**.

- Live game: https://droptop.github.io/cockroach-colonization/ (repo must stay PUBLIC or Pages dies)
- Repo: github.com/droptop/cockroach-colonization (main = source, gh-pages = build only)
- Levels (chained via `next_scene`): drain → street → kitchen → counter → granny kitchen
  → tabletop (current end). Four of the six are **boss-gated** (see below); street and
  counter still open on touch.

## Commands

```bash
godot --path .                                                  # run (desktop)
godot --headless --path . --import                              # reimport after asset/script adds
godot --headless --path . --script tests/smoke_test_3d.gd       # drain traversal
for t in tests/*.gd; do godot --headless --path . --script "$t"; done   # whole suite (18)
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
  ceiling, music, decor helpers (`decor_*`, `hazard_drip`, `decor_checkpoint`,
  `decor_granny_hazard`).
  **Exit gate**: `ExitState` enum (UNLOCKED/LOCKED/BOSS_ACTIVE/BOSS_DEFEATED/TRANSITION)
  + `boss_path`. Empty `boss_path` = open from the start, which is how every level behaved
  before gating, so nothing regresses by default. Also raises/drops **arena walls** — down
  the instant the player dies, back up only when he re-enters, or death seals him out of
  an unfinished fight.
  Each level .tscn = geometry (Block3D StaticBody3D nodes, the only collidable pieces) +
  instanced pickups/enemies; its .gd = `_build_decor()` non-collidable set dressing.
- `world/hazards/` — `DripEmitter3D` (toxic drips) and `GrannyHazard` (fly-swatter slam +
  insecticide cloud, GAME.md §11): pure-script Node3D hazards, no `.tscn`, added via a
  `Level3D` decor helper. Granny is NOT a boss — a level-scoped environmental threat that
  telegraphs then attacks wherever the player currently is (no ground-raycast needed).
- `enemies/` — spider, ant, fly: standalone CharacterBody3D FSMs (deliberately no shared
  base). Rat drops a crown on death → `GameManager.unlock_achievement()`.
- `enemies/base_boss_3d.gd` (`BaseBoss3D`) — thin boss contract: health, `arena_bounds()`,
  and `engaged` / `defeated` / `boss_health_changed`. Owns NO FSM and no attacks on
  purpose; what makes a boss a boss is *how* you beat it, and sharing that is what turns
  bosses into re-skinned enemies. `immune_to_damage` + `lose_health()` let a boss be
  beaten by something other than weapons. **Four bosses, four verbs**:
  rat = *when* to hit · Granny = don't be hit at all (patience drains on her MISSES) ·
  cat = *what* to hit (the paw it leaves behind) · Spider Queen = hit something *else*
  first (cut the webs holding her up).
- `world/props3d/` — @tool scripts that BUILD their own meshes/collision (Block3D,
  Bin3D, Pipe3D, ParallaxBackdrop, LightShaft3D). All placeholder visuals are procedural
  mesh builders; zero imported models shipped so far (a user-generated Meshy GLB
  candidate for Harry exists but isn't wired in — see BACKLOG).
  `LightShaft3D` = fake god ray from a sewer cap/storm drain (additive cone + grain +
  cap mesh), added via `Level3D.decor_light_shaft()`. Block3D texture styles are
  speckle/grain/checker/brick/asphalt/concrete, each with a generated normal map AND a
  baked AO map (cracks/pits self-shadow without costing a light).
- `world/fx.gd` (Fx) — static one-shots: `impact_text`, `spark_burst`, `ghost(.., legs)`,
  `hit_flash` (material_overlay, never touches real materials), `hit_stop` (0.05 s freeze
  on a timer that IGNORES time_scale — without that flag, time_scale 0 locks the game),
  and `Tier`/`impact()` which pick word, colour, size and sparks from the damage so
  blocked/weak/normal/heavy read differently.
- `world/hazards/hazard_pool_3d.gd` (`HazardPool3D`) — ONE volume behind acid puddles,
  Granny's spray, the Queen's venom and the cat's water. Radius and height are derived
  from the visible mesh in a single function, and growth/fade tween *through* it, so the
  hurtbox can never exceed what you can see.
- `items/rewards/` — `RewardPickup3D` (hearts + wing shards, drift toward the player,
  and are LEFT behind rather than swallowed if he is already full) and `LostGhost3D`
  (what he dropped on death: crumbs, fruit **and weight**, waiting where he fell).
- `world/props3d/checkpoint_3d.gd` (`Checkpoint3D`) — moves the respawn point and banks
  what he carries; the lost ghost then holds only what he gathered since.
- `autoload/` — GameManager (signal bus + babies_banked + achievements + web debug
  heartbeat), AudioManager (SFX pool/music/wings), `snd.gd` (Snd) static facade.
- `ui/hud/` — hearts (true half-heart split rendering), wing bar, weapon/shield labels,
  scorecard, touch controls, vignette; `ui/title/` intro.
- `ui/fonts/` — Iron Dice Grit (Regular/Bold/Black), the project's only custom font. Regular
  is the project-wide default (`gui/theme/custom_font` in project.godot); Bold/Black are
  per-Label `theme_override_fonts/font` overrides — see Key decisions for the weight rule.
- User-supplied art lands in `user_added_images/` → copy into `art/` before wiring. Same
  pattern for fonts: raw kit stays in its own staging folder (e.g. `iron-dice-font /` — note
  trailing space in that name), only the weights actually used get copied into `ui/fonts/`.

## Conventions

- Duck-typed interactions: anything with `take_damage(amount, from_pos)` can be hurt,
  `apply_slow(factor)` can be slowed, `collect_food/collect_fruit/add_wing_energy/
  adopt_baby/collect_weapon/collect_shield/restore_health/recover_lost/set_checkpoint`
  on the player. No interfaces. `take_damage(amount, from_pos, cause := "")` — the third
  arg is OPTIONAL on purpose, so the dozen callers that predate it still work; it decides
  the death message (SQUISHED is reserved for crushing).
- `add_wing_energy` and `restore_health` RETURN whether they changed anything, so a
  pickup can say "FULL!" and leave itself for later instead of vanishing silently.
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
- **Font weight hierarchy**: Black = biggest display moments (popup Message, rotate-phone
  overlay), Bold = HUD stat readouts + title CTA, Regular = project default + deliberately
  quiet secondary text (version tag, debug overlay) — user's explicit call over one flat
  weight everywhere or Black everywhere.

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
- **A scripted `str.replace` that doesn't match fails SILENTLY.** This bit three times in
  one session — most nastily when a whole feature (the nail's readiness bonus) looked
  implemented in the source and did nothing, because the edit matched four tabs where the
  file has three. Assert on every replace, and re-read the file to verify the token
  arrived. Same for shell: `python3 - <<PY ... PY` followed by `git commit` on the next
  LINE will commit even when the Python died — chain with `&&`.
- **An Area3D does NOT report a `StaticBody3D` in `get_overlapping_bodies()`** (nor a
  frozen RigidBody3D). It sees `CharacterBody3D` and `AnimatableBody3D`. Every attack
  volume in the game is an Area, so anything damageable must be one of those two —
  `AnimatableBody3D` extends StaticBody3D and collides identically, so it is a drop-in.
  This shipped: the Spider Queen's webs, the cat's paw and both breakable walls were
  StaticBody3D and could not be hit by ANY attack, in a live build, for weeks.
- **Driving damage with `thing.take_damage(...)` in a test proves nothing about whether
  a player can hit it.** That one convenience hid the bug above across four separate
  suites — each happily confirmed the object dies when damaged. If a thing is meant to
  be hit, at least one test must press the attack button. See
  `tests/destructible_reachable_test.gd`.
- **A child's `_ready` runs BEFORE its parent's**, so a node cannot add siblings to its
  parent during its own `_ready` (the parent is still setting up and refuses them). Use
  `call_deferred` — this is why the Spider Queen spun zero webs on the first run.
- **An Area3D's overlaps only refresh on a physics step.** Moving an area and querying it
  in the same frame sweeps where it *used* to be. That's why the down/up attacks get their
  own areas instead of repositioning the forward one — and why tests that drive attacks
  must wait in REAL SECONDS, not frames.
- MP3 music: set `stream.loop = true` at load (AudioManager handles it).
- `.gitignore` excludes `build/`; never commit build output to main (it happened once —
  if a stray "Deploy:" commit appears on main, reset it away).
- Export preset uses `export_filter="all_resources"`, so Godot ships EVERY file under the
  project root, including raw asset-kit staging folders (specimens, unused font
  weights/formats, READMEs). Add an `exclude_filter` entry in `export_presets.cfg` for any
  new staging folder, or it silently bloats the web build.

## Testing

`tests/` holds 18 committed suites, all headless, all `extends SceneTree`. They print
`ok`/`FAIL` per assertion and exit non-zero on failure. Anything that killed a boss or
wrote settings points `SaveGame.save_path` / `Settings.settings_path` at a scratch file
first — otherwise the run pollutes real progress AND its own second run.

Write assertions that would fail for the *right* reason: a death-message test that only
checked a stomp passed against hardcoded "SQUISHED!", because SQUISHED is the correct
answer for a stomp. Several causes in one test is what caught it.

## Immediate next steps

**Nobody has played any of this.** Six levels, four bosses, the pogo, the weight
trade-off, checkpoints and the death-recovery loop were all built and shipped without
anyone touching the controls. Every tuning number in the newer bosses is a guess
(6 patience / 1.15 s telegraph, 6 health / 1.8 s paw window, 3 shield hits, 0.5 s nail
window). 18 suites prove the mechanics work *mechanically*; none can say whether
Granny's telegraph is dodgeable or the tabletop route is navigable. **Playtest before
building more.**

Then, roughly in order:
- Real audio. All 37 sfx are synthesised placeholders (music is real and is not), but
  each is now its OWN placeholder: the old `thud`/`squeak` overloading (16 and 13 jobs)
  was split into 19 named hooks and both dead names deleted. A recording now drops in
  over `audio/sfx_<name>.wav` with no code change. Briefs: **docs/audio-brief.md**;
  generation prompts and which to record as foley live in the same doc's priority list.
- Eyeball Iron Dice Grit at the small HUD sizes (13–14 px) in a browser.
- Bosses for the street and counter — the P0 rule says every level ends in one; four of
  six do.
- Granny has no arms and the cat no foreleg, so swatter/shoe/paw arrive attached to
  nothing. Nothing on the tabletop actually falls when the cat shakes it.
- Resume flow: `SaveGame.furthest_level()` is stored and nothing reads it. Whether the
  title auto-resumes or offers CONTINUE vs NEW GAME is a design call needing a menu.

See [BACKLOG.md](BACKLOG.md) for the full picture and
[docs/implementation-audit.md](docs/implementation-audit.md) for the system map.
