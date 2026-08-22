# BACKLOG

Deferred work. Not auto-loaded — CLAUDE.md points here.
Design brief: GAME.md · system map: docs/implementation-audit.md · audio: docs/audio-brief.md.

Completed epics and their acceptance criteria were condensed out on 2026-08-17;
recoverable from git history if a decision needs re-reading.

## Now

**Nobody has finished this game.** Three bosses have never been reached, and
four separate lockouts were found today, so assume more.

- **Cat level unfinished.** User could not get past it. EXIT signs shipped
  since; unverified.
- **Audit summons on rat, cat, wasp, Queen.** Added to all six yesterday; it
  made Granny unbeatable. Wasp and Queen are the risky ones — both fights are
  positional and adds trample positioning.
- **Completability tests for the other five levels.** The granny one found what
  every boss test missed. Would have caught the Queen, the checkpoints and the
  pantry.
- **Baby enemies get stuck in props** on the cat level (salt shakers).
- **Checkpoints obscured by props.** Generalise the granny doorway check to
  every checkpoint and exit.
- **Is the drain too long?** 51 m → 91 m in one change.
- **Nothing teaches the combos.** Mega smash and backflip kick are unmentioned.
- Iron Dice Grit at 13–14 px in a browser; still never eyeballed.
- **`smoke_test_3d` fails on main** and did before the 2026-08-22 session (same
  numbers on a clean checkout: x -33.32, health 4/8, food 0). He is stuck
  around x -33 taking damage and eating nothing. The suite has not been green
  for a while and the worklog does not mention it.

## Next

**Fights**
- Spider Queen has no threat: web that GRABS him, mash left/right to escape,
  babies biting while he is held.
- Wasp lays eggs that hatch into a swarm and build up if ignored.
- Wasp level: honey drips from above instead of poison.
- Mantis: eggs that hatch, warp, spinning-blade charge, reaper attack; nymphs
  spread out and guard the gate when the big one dies.
- Rat/street level too short — same treatment the drain got.

**Systems**
- Baby matrix at level end: grid where every square is a banked baby, previous
  levels grey, this level lit. Filling it is the long game.
- Leaderboard: babies, hearts left and kill speed feed a score, enter a name.
  Needs the matrix first.
- **Shop: coins buy armour, weapons, skins, assistance, shields.** Wants three
  things the game does not have yet, in this order:
  1. **Coins.** A currency that is not food. Food is deliberately a tax as well
     as a reward (it fattens him), so it cannot double as money. Dropped by
     enemies and hidden in levels; banked like babies are.
  2. **Persistence across levels.** Weapons and shields are LEVEL-SCOPED on
     purpose (see CLAUDE.md), and a shop that sells a permanent weapon breaks
     that on day one. Decide first: does a purchase last the run, the level, or
     forever? "Forever" also has to survive the six-level chain and a death.
  3. **The shop itself.** A screen between levels rather than a shopfront in
     one, so it does not need a safe room built into every level.
  Skins and "assistance" (a hired baby? a bought revive?) are the cheapest of
  the five to add and the least entangled with the combat economy — worth
  doing first as the proof the currency works.

**Art**
- Granny has no ARMS; swatter and spray attach to nothing.
- Granny's eyes follow him; flower dress.
- Spider gait is goofy — less swing, more weight.
- Wheat should read more like wheat; add corn on the cob.
- Cat and Granny still lack a foreleg/arm rig generally.

**Smaller**
- Three synthesised hooks: `rat_cry`, `mantis_cry`, `mantis_hurt`.
- Eight delivered recordings unused (`cut_hurt_2` is likely `mantis_hurt`).
- A fourth music track.
- Per-enemy movement sounds; baby chirp; weapon-specific swings.
- Nothing on the tabletop falls when the cat shakes it.
- Ghost dies with the scene; no bank-at-a-nest step.
- Export still ships `tests/` (`all_resources`).
- Hidden rooms beyond the two breakables.
- Meshy GLB for Harry in staging, not wired in.

## The second half (user's arc, 2026-08-21)

Escalation only works in order; each is a level's worth of work and several
need systems that do not exist.

- Roof — wind, and a real fall below you.
- Trees — vertical, branch to branch; climbing and flight already suit it.
- Aliens in a flying saucer — first non-insect enemy.
- Take their craft to the Moon. Sequence animation, MUST be skippable.
- Moonbugs on the Moon. Needs LOW GRAVITY: jump, flight drain and knockback are
  all tuned against 26 m/s/s and the wing bar is the whole economy.
- Spacewarp to Mars. Own hazards; weapons that suit vacuum, not a kitchen drawer.
- Weapons/hazards escalate with it — probably its own tier.
- **Glutton level**: nothing but food until he is too heavy to continue, then a
  GYM to work it off. The only idea so far that makes fullness the subject
  rather than a tax. Pairs with the poo bomb.

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
