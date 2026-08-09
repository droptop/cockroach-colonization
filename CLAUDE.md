# Cockroach Colonization — CLAUDE.md

2.5D action-platformer (Godot 4.7, GDScript): cute toy-style cockroach Harry in a giant
dangerous house. 3D rendering, gameplay locked to the X/Y plane. Ships as an HTML5 web
build on GitHub Pages. Full design brief: **GAME.md** (note: brief says 2D — superseded
by the 3D pivot, see docs/ARCHITECTURE.md). Deferred work: **BACKLOG.md**.

- Live game: https://droptop.github.io/cockroach-colonization/ (repo must stay PUBLIC or Pages dies)
- Repo: github.com/droptop/cockroach-colonization (main = source, gh-pages = build only)

## Commands

```bash
godot --path .                                                  # run (desktop)
godot --headless --path . --import                              # reimport after asset/script adds
godot --headless --path . --script tests/smoke_test_3d.gd      # drain traversal test
python3 tools/generate_audio.py                                 # regenerate all SFX wavs
godot --headless --path . --export-release "Web" build/web/index.html   # web export
./deploy_web.sh <path-to-godot>                                 # export + delta-deploy to gh-pages
```

Godot is NOT installed on this Mac and no Homebrew. Download 4.7.x from godotengine.org
(or GitHub releases zip + `xattr -dr com.apple.quarantine`). Web export templates for
4.7.1 are installed in `~/Library/Application Support/Godot/export_templates/`.

## Architecture

- `player/player_3d.gd` — ALL movement/combat/growth tuning as @exports. Self-contained
  (health, food, wings, babies live on the instance; no player singleton — co-op later).
- `world/levels/level_3d.gd` — level base: spawn/death/exit wiring, level chaining
  (`next_scene`), ceiling, music, decor helpers (`decor_*`, `hazard_drip`). Levels:
  drain → street → kitchen; each level .tscn = geometry (Block3D nodes) + instances,
  its .gd = `_build_decor()` set dressing.
- `enemies/` — spider, ant, fly, rat boss: standalone CharacterBody3D FSMs (deliberately
  no shared base). `enemy_health_bar.gd` green/orange/red bars.
- `world/props3d/` — @tool scripts that BUILD their own meshes/collision (Block3D,
  Bin3D, Pipe3D, ParallaxBackdrop). Placeholder visuals are all procedural `_draw`-style
  mesh builders; zero imported models so far.
- `world/fx.gd` (Fx) — static one-shots: impact_text, spark_burst, ghost.
- `autoload/` — GameManager (signal bus + babies_banked + web debug heartbeat),
  AudioManager (SFX pool/music/wings), `snd.gd` (Snd) static facade.
- `ui/hud/` — hearts, wing bar, scorecard, touch controls, vignette; `ui/title/` intro.
- User-supplied art lands in `user_added_images/` → copy into `art/` before wiring.

## Conventions

- Duck-typed interactions: anything with `take_damage(amount, from_pos)` can be hurt,
  `collect_food/collect_fruit/add_wing_energy/carry_baby` on the player. No interfaces.
- Damage never physically collides player↔enemy (separate layers; Hitbox Areas deal contact).
- Collision layers: 1 world, 2 player, 3 enemy, 4 hazard, 5 pickup.
- Tunables are @exports; keep them out of hard-coded logic.
- Web-safe text only in world/HUD labels (ASCII arrows etc. — default font has no ● ♥ →).

## Key decisions (and why)

- **Compatibility renderer + shadows OFF + 0.75 3D scale**: software-GL browsers choke
  on shadow maps (was <1fps). Flat-lit low-poly + baked-in normal-map textures instead.
- **`Snd.sfx()` facade, never `AudioManager.` directly in gameplay code**: autoloads
  don't exist as compile-time globals under the `--script` test harness; direct refs
  break EVERY dependent script's compilation.
- **Procedural textures + normal maps** (`Block3D.textured_material`): speckle/grain/
  checker/brick generated from FastNoiseLite at load; tinted per surface; triplanar.
- **Wing energy is the universal resource**: flying drains it, ANY hit costs 18, food
  refills (crumbs +14/fruit +45), food also fattens (slower/heavier) — intended tension.
- **Deploys are delta-pushes**: force-pushing the 40MB wasm fresh hits "remote end hung
  up"; clone gh-pages, overwrite, commit, push (usually only index.html+pck change).

## Gotchas / do NOT

- **Pushes lie**: git can print "Everything up-to-date" while the push silently failed.
  ALWAYS verify: `git ls-remote origin <branch>` vs local SHA; retry until they match.
- **Test harness has no autoloads** (SceneTree `--script` mode). See Snd note above.
- Session scratchpad is wiped between sessions — never keep the Godot binary, test
  scripts, or the pages-clone only there. Durable checks belong in `tests/`.
- Don't parent procedural leg/limb meshes to the visual root — attach to their pivots
  (the "spider has no legs" bug).
- Don't overlap glow/decor meshes with wall faces (z-fighting flicker) — offset ≥0.05.
- Don't re-enable DirectionalLight shadows. Don't set fly_acceleration ≤ gravity (26).
- MP3 music: set `stream.loop = true` at load (AudioManager handles it).
- `.gitignore` excludes `build/`; never commit build output to main (it happened once —
  if a stray "Deploy:" commit appears on main, reset it away).

## Immediate next steps

1. Weapons update (user-approved): bottle-cap shield-bash prototype first → see BACKLOG.md.
2. Recreate the lost headless checks (climb/flight/death/rat/baby/title) as files in `tests/`.
3. Playtest pass on rat difficulty + fly dive fairness; user supplies street/kitchen backdrops next.
