# BACKLOG

Deferred work. Not auto-loaded — CLAUDE.md points here.
Design brief: GAME.md · system map: docs/implementation-audit.md · audio: docs/audio-brief.md.

Completed epics and their acceptance criteria were condensed out on 2026-08-17;
recoverable from git history if a decision needs re-reading.

## Now

- **Real audio: 3 sounds left.** 45 recordings landed 2026-08-20. Outstanding:
  `rat_cry` and `mantis_cry` (boss wind-up telegraphs) and `mantis_hurt`, all three still
  synthesised. 12 delivered files are unused and want a decision: `cut_hurt_2` (likely
  `mantis_hurt`), `random_death`, `granny_swat2`, `dull_drop`, `wings2`, `acid_drop` and
  `fly_flutter` (both want new hooks), and four Granny voice lines plus `huh` with no
  idle/taunt hook to hang them on.
- **Confirm the audio toggles.** Whether MUSIC/SOUND FX read OFF in the user's browser —
  the cause of "all audio disappeared", now reachable again via `P`.
- **Playtest the Spider Queen.** Beatable since the AnimatableBody3D fix: one flight per
  anchor, ~3 flights plus the arena fruit. Fun or not needs a play, not another guess.
- **Playtest the cat and the breakable walls.** Same bug class, unhittable until today —
  nobody has beaten either.
- **Iron Dice Grit at 13–14 px** in a browser; never eyeballed at HUD sizes.

## Next

- Granny has no arms and the cat no foreleg — swatter/shoe/paw arrive attached to nothing.
- Nothing on the tabletop actually falls when the cat shakes it.
- Per-enemy movement sounds, so an approach is identifiable without looking.
- Weapon-specific swings — nine weapons share one `whoosh`, now with four takes.
- Baby chirp; babies follow Harry and are silent.
- Dedicated Shell Bash move rather than reusing the normal attack.
- Pipe Crawl / Baby Boost — need narrow passages and a reason for the baby to matter.
- Ghost dies with the scene: can't be chased across a level transition, and there is no
  "bank it at a nest" step beyond the level exit.
- Spider Queen has no wall-crawling or repositioning — her arena is static.
- `glide` (Z) is still mapped and unused, if an ability wants a home.
- Meshy GLB candidate for Harry exists in staging, not wired in.
- Hint bubble size is approximated from character count; real text metrics would tighten it.
- Damage readability format — bar vs radial vs pie (audit open decision 7).
- A fourth music track; six levels share three.
- Export still ships `tests/` (`all_resources`); the two staging folders are excluded now.
- Hidden rooms beyond the two breakables, which both sit behind the spawn.

## Later

- Interconnected areas with shortcuts and return paths — structurally at odds with the
  linear `next_scene` chain. A real change, not a tweak.
- Boss trophy system + trophy loadout (GAME.md §7); colony hub + trophy room (§8/§23).
- Three keys + Granny's secret + endings (§20–22) — the hazard exists, the payoff does not.
- Discrete growth size states with collision changes + small-route gating (§14/§17);
  fullness is currently continuous and collision never changes.
- More levels: pantry, inside-the-walls, bathroom, basement, garden, deeper sewer (§35).
- Beetle enemy (armoured, attack from behind) + enemy config as Resources.
- Centipede enemy; spider web attacks.
- Scout + Brute playable characters (§3); metabolism / size-loss mechanic (§14).
- Co-op architecture (§24) — keep avoiding player singletons meanwhile.
- Kage-style Three.js landing/marketing page.

## Standing rules

- **Every level ends in a boss** (P0). All six do. Each needs its own identity, attack,
  arena, weakness and defeat mechanic — never a normal enemy with more health.
- **Level contract**: EXPLORE → LEARN → ESCALATE → BOSS → REWARD → EXIT, with the exit
  LOCKED → BOSS ACTIVE → BOSS DEFEATED → UNLOCKED → TRANSITION.
- **Performance**: Compatibility renderer, shadows off, 0.75 3D scale, draw calls under the
  per-level budget `tests/perf_budget_test.gd` enforces.
