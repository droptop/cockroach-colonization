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

## Requested, not yet built (2026-08-21)

Everything asked for in play, whether or not it has been started. Ranked
roughly: things that BLOCK play, then fights, then systems, then art.

### Blocking or broken
- **Baby enemies get stuck in props** on the cat level — salt shakers and
  similar. Spawned enemies need somewhere clear to land, or a nudge out of
  geometry. Same family as the flush wedging.
- **Checkpoints obscured by props.** The granny pantry was the extreme case
  (parked on the exit). The doorway check in granny_level_completable_test
  should be generalised to every checkpoint and every exit in every level.

### Fights
- **Spider Queen does nothing to you.** She should shoot a web that GRABS him:
  wrapped, unable to move, mashing left/right to break out, faster mashing =
  quicker escape. Her babies take the chance to bite while he is held. This is
  the single biggest gap — the fight has no threat once you know it.
- **Wasp lays EGGS** that hatch into a swarm which builds up if ignored. The
  first fight that can be lost by doing nothing.
- **Wasp level: drop the poison.** Honey drips from above that knock him down
  instead, which suits the syrup arena already there.
- **Mantis**: eggs that HATCH rather than adds appearing, a warp, a
  spinning-blade charge, a reaper attack. Its nymphs drop in a clump and should
  spread out, then guard the gate once the big one dies.
- **Rat level is too short.** The drain went 51 m to 91 m; the street wants the
  same treatment.

### Systems
- **Baby matrix at the end of every level.** A grid (10x10, or 15x15 if it
  should be hard) where every square is a banked baby. Squares from previous
  levels grey, squares earned in THIS level lit. Filling it is the long game.
- **Leaderboard and score.** Babies banked, hearts remaining and how fast
  enemies were killed all feed a score; enter your name at the end. Needs the
  matrix first, since that is where the count lives.

### Art
- **Granny has no ARMS.** The swatter and spray arrive attached to nothing, and
  her face is now good enough that the absence shows.
- Granny's eyes should follow him; a flower dress.
- Spider legs move goofily — less swing, more weight.
- Wheat should read more like wheat; add corn on the cob.


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

## The second half (user's arc, 2026-08-21)

A whole second act, going UP and then off the planet. Sketched as one arc
because the escalation only works in order, but each is a level's worth of work
and several need systems that do not exist yet.

- **Roof** — battle on the tiles. Wind as a hazard, and a real fall below you.
- **Trees** — vertical, branch to branch. The climbing and flight already suit it.
- **Aliens in a flying saucer** — the first enemy that is not an insect.
- **Take their craft to the Moon.** Cool sequence animation, and it MUST be
  skippable: an unskippable cutscene between you and a retry is a reason to stop
  playing.
- **Moonbugs on the Moon.** Needs LOW GRAVITY, which is a real change: jump,
  flight drain and knockback are all tuned against 26 m/s/s, and the wing bar is
  the whole economy.
- **Spacewarp to Mars, battle Martians.** Its own hazards, and weapons that suit
  vacuum and dust rather than a kitchen drawer.

Weapons and hazards have to escalate with it — a rusty nail does not belong on
Mars — so this arc probably wants its own weapon tier rather than reusing the
house scavenge.

- **The glutton level.** Nothing but food: eat until he is enormous, at which
  point he is too heavy and slow to go on, and has to work it off at a GYM. A
  whole level about the fullness mechanic, which is currently a tension nobody
  is forced to confront. Pairs naturally with the poo bomb, which is the other
  thing weight is good for.

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
