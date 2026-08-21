# BACKLOG

Deferred work. Not auto-loaded — CLAUDE.md points here.
Design brief: GAME.md · system map: docs/implementation-audit.md · audio: docs/audio-brief.md.

Completed epics and their acceptance criteria were condensed out on 2026-08-17;
recoverable from git history if a decision needs re-reading.

## Now

Ordered by what actually blocks the game being good, not by effort.

**P0 — nobody has ever finished this game.**
- **Playtest the cat, the mantis, the wasp and the tabletop.** The drain and Granny have
  now had real play; the last three bosses have not, and two of the six were literally
  unbeatable until this week (the cat's paw and the Queen were both invisible to every
  attack in the game). Assume the same class of bug is sitting in the ones nobody has
  reached. This is the single highest-value thing left.
- **Is the drain too long now?** It went from 51 m to 91 m in one change. A first level
  that outstays its welcome costs more players than any bug here.

**P1 — things the player cannot discover.**
- **Nothing teaches the combos.** Mega smash (down + attack after a fall) and backflip
  kick (attack while holding away) exist and are not mentioned anywhere. An ability
  nobody finds may as well not be built.
- **Iron Dice Grit at 13–14 px** in a browser, still never eyeballed at HUD sizes.

**P2 — audio gaps, all small.**
- Three hooks still synthesised: `rat_cry`, `mantis_cry`, `mantis_hurt` — all three are
  boss telegraphs, i.e. the sounds that teach you when to move.
- Eight delivered files still unused: `cut_hurt_2` (likely the missing `mantis_hurt`),
  `acid_drop` and `fly_flutter` (both want new hooks), `granny_murmur`, `granny_swat2`,
  `dull_drop`, `huh`, `wings2`.
- A fourth music track: six levels share three, plus Kettle Quest.

## Next

- Granny has no arms and the cat no foreleg — swatter/shoe/paw arrive attached to nothing.
- Nothing on the tabletop actually falls when the cat shakes it.
- Per-enemy movement sounds, so an approach is identifiable without looking.
- Weapon-specific swings: nine weapons share one `whoosh` (four takes). A knife and a
  rubber band should not sound alike.
- Baby chirp; babies follow Harry and are silent.
- Dedicated Shell Bash move rather than reusing the normal attack.
- Pipe Crawl / Baby Boost — need narrow passages and a reason for the baby to matter.
- Ghost dies with the scene: can't be chased across a level transition, and there is no
  "bank it at a nest" step beyond the level exit.
- Spider Queen has no wall-crawling. She stalks the ledge now, but never leaves it.
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
