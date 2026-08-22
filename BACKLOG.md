# BACKLOG

Deferred work, in PRIORITY ORDER (reordered 2026-08-22). Not auto-loaded:
CLAUDE.md points here.
Design brief: GAME.md · system map: docs/implementation-audit.md · audio: docs/audio-brief.md.

Completed epics and their acceptance criteria were condensed out on 2026-08-17;
recoverable from git history if a decision needs re-reading.

**The ordering principle: nothing outranks making the game finishable.** Until
it is, every other improvement lands on a game nobody can complete. Priorities 1
and 2 are that. Everything below them is a better game, not a finished one.

Items are numbered 1 to 50 straight through, so an item's number IS its rank.
The whole list in one block is at the bottom, under "Everything, in order".

---

## Priority 1: Finishability. The whole game is blocked on these.

**The game can now be finished, and it ends.** Proven end to end by tests that
play it (item 1), and the missing ending that made the last exit look broken is
built (item 2). Nobody has finished it BY HAND yet, so the play reports still
outrank everything in here.

1. ~~**Completability tests for the other five levels.**~~ **DONE 2026-08-22.**
   `tests/support/level_completable.gd` is the shared harness;
   drain/street/kitchen/counter/tabletop each have one. Every one beats its
   boss by pressing the attack button, WALKS to the exit, and waits for the next
   scene. All five pass, so **the game is completable end to end.** Verified to
   fail for the right reason by putting the Queen back on `collision_layer = 0`
   and the cat's paw with her: both went to "6 -> 6 health in 90s".
2. ~~**Cat level: cannot get past it.**~~ **DONE 2026-08-22.** It was never the
   cat. The tabletop is the LAST level, its `next_scene` is empty, and walking
   into the unlocked exit called `complete_level()` (a signal with no listener)
   and showed a message with duration 0.0, i.e. forever. The game had no ending,
   so finishing it was indistinguishable from a door that would not open. There
   is an ending screen now, and every level must LAND somewhere in the tests.
3. ~~**`smoke_test_3d` fails on main.**~~ **DONE 2026-08-22.** Stale, exactly as
   suspected: it jumped at x positions calibrated for a 51 m drain that spawned
   him near the origin, and the drain is 91 m spawning at x -37. It finds edges
   with a ray now. NOTE the second bug, which nearly got logged as a trap in the
   outfall that does not exist: the rewrite held jump for a FRAME COUNT, and
   headless frames run far faster than 60/s, so the hold was long enough to jump
   and nowhere near long enough to CLIMB. Hold durations in tests must be in
   REAL SECONDS. Suite is 44 of 44.
4. **Audit boss summons on rat, cat, wasp, Queen.** The last Priority 1 item,
   and much cheaper than it was: summons were added to all six on 2026-08-20 and
   made Granny mathematically unbeatable, but there is now a harness that PLAYS
   each fight. `pre_fight_checks()` and a before/after count of what is on the
   floor turn this from inspection into proof, the way the granny test already
   does it. Wasp and Queen are the risky ones: both fights are positional and
   adds trample positioning.
5. **Zero hearts while still alive**, reported from a live run 2026-08-22 and
   NOT reproduced. `health` is only reduced in `take_damage`, which always calls
   `_die()` at zero; nothing else in the codebase writes to it; the hearts
   widget renders halves correctly; 6000 frames of the drain pit death loop
   produced no alive-on-zero frame. Shielded hits are the only half-damage path
   in the game and remain the main suspect. Needs the level, whether a shield
   was held, and what had just hit him.

## Priority 2: Bugs that break play but do not lock it.

6. **Baby enemies get stuck in props** on the cat level (salt shakers).
7. **Checkpoints and exits obscured by props.** Generalise the Granny doorway
   check to every checkpoint and every exit in all six levels.

## Priority 3: Nobody can play what they cannot read.

8. **Nothing teaches the combos.** Mega smash and backflip kick are unmentioned
   anywhere, so most players never learn they exist. Nor is any BOSS rule
   taught, and writing the completability tests turned up how much of that
   there is: the cat is immune and only the paw counts; the mantis guards a 150
   degree frontal cone so only an overhead pogo lands; the Queen cannot be hurt
   until every web is cut.
9. **The wasp fight cannot be worked out by playing it.** `_impact` tests
   whether the dive HIT HIM before it tests the syrup, so a dive that connects
   bounces off and the wasp is never vulnerable. Standing in the honey, which is
   the obvious reading of "bait it into the syrup", means being hit forever and
   the fight has no opening at all. The real answer is bait it, then step out of
   `dive_radius` before it lands, and nothing says so. Found by the counter
   completability test failing for 90 seconds against a boss that turned out to
   be beatable in 3.
10. **Iron Dice Grit at 13-14 px in a browser**, still never eyeballed.
11. **Is the drain too long?** 51 m to 91 m in one change.

## Priority 4: The fights. This is the game's stated identity.

12. **Spider Queen has no threat**: web that GRABS him, mash left/right to
    escape, babies biting while he is held.
13. **Mantis kit**: eggs that hatch, warp, spinning-blade charge, reaper attack;
    nymphs spread out and guard the gate when the big one dies.
14. **Wasp**: lays eggs that hatch into a swarm and build up if ignored. Honey
    drips from above instead of poison.
15. **Rat/street level too short.** Same treatment the drain got.

## Priority 5: Systems. Strict dependency order; each needs the one above it.

16. **Death bursts into shapes, then into food, energy and COINS.** Enemies
    already `Fx.shatter` into their own meshes and `FoodBurst.spawn` a fountain
    of food. What is missing: wing energy is not part of the burst, coins do
    not exist, and bosses do not shatter at all. Making the shapes RESOLVE into
    pickups unifies three separate death effects into one readable moment, and
    it is also how coins ENTER the game, which is what item 19 waits on.
    **Open decision:** five of the six bosses RETREAT rather than die, each
    with its own retreat animation, and `granny_encounter_test` asserts "she
    retreats rather than dying". Only the rat reaches a DEAD state. The loot
    burst can be given to all six without touching that. Blowing the boss's own
    body apart can only go to the rat unless the other five are changed from
    retreating to dying, which is a design call, not a bug fix.
17. **Baby matrix at level end**: a grid where every square is a banked baby,
    previous levels grey, this level lit. Filling it is the long game.
18. **Leaderboard**: babies, hearts left and kill speed feed a score, enter a
    name. Needs the matrix first.
19. **Shop: coins buy armour, weapons, skins, assistance, shields.** Wants
    three things, in this order:
    1. **Coins**, delivered by item 16. A currency that is NOT food: food is
       deliberately a tax as well as a reward (it fattens him), so it cannot
       double as money.
    2. **Persistence across levels.** Weapons and shields are LEVEL-SCOPED on
       purpose (see CLAUDE.md), and a shop selling a permanent weapon breaks
       that on day one. Decide first: does a purchase last the level, the run,
       or forever? "Forever" also has to survive the six-level chain and a
       death.
    3. **The shop itself**, as a screen between levels rather than a shopfront
       inside one, so it does not need a safe room built into every level.
    Skins and "assistance" (a hired baby? a bought revive?) are the cheapest of
    the five and the least entangled with the combat economy: worth doing first
    as the proof the currency works.

## Priority 6: Art and audio polish.

20. **Cat foreleg rig.** Granny's arm chain (shoulder to elbow to hand pivots,
    `_build_arms` in `granny_boss_3d.gd`) is the pattern to copy.
21. **Granny's eyes follow him.** Her head and everything on it now hangs off
    one `head_pivot`, which is exactly what eye-tracking needs.
22. **Granny's swatter** still descends on its own 6 m handle rather than at the
    end of the arm that now swings for it. Her stomp is a thrown shoe already.
23. **Spider gait is goofy.** Less swing, more weight.
24. **Three synthesised hooks**: `rat_cry`, `mantis_cry`, `mantis_hurt`.
25. **Eight delivered recordings unused** (`cut_hurt_2` is likely `mantis_hurt`).
26. Per-enemy movement sounds; baby chirp; weapon-specific swings.
27. A fourth music track.
28. **Export still ships `tests/`** (`export_filter="all_resources"`).
29. Nothing on the tabletop falls when the cat shakes it.
30. Ghost dies with the scene; no bank-at-a-nest step.
31. Hidden rooms beyond the two breakables.
32. Meshy GLB for Harry in staging, not wired in.

## Priority 7: The second half (user's arc, 2026-08-21).

Escalation only works in order; each is a level's worth of work and several
need systems that do not exist.

33. **Glutton level.** The outlier, and the one that could jump the queue to
    around Priority 5: nothing but food until he is too heavy to continue, then
    a GYM to work it off. The only idea so far that makes fullness the SUBJECT
    rather than a tax, and it needs no systems that do not already exist.
    Pairs with the poo bomb.
34. **Roof.** Wind, and a real fall below you.
35. **Trees.** Vertical, branch to branch; climbing and flight already suit it.
36. **Aliens in a flying saucer.** The first non-insect enemy.
37. **Take their craft to the Moon.** Sequence animation, MUST be skippable.
38. **Moonbugs on the Moon.** Needs LOW GRAVITY: jump, flight drain and
    knockback are all tuned against 26 m/s/s and the wing bar is the whole
    economy.
39. **Spacewarp to Mars.** Own hazards; weapons that suit vacuum, not a kitchen
    drawer.
40. Weapons and hazards escalate with it, probably as their own tier.

## Priority 8: Later. Structural, and all cheaper once the game is finishable.

41. Interconnected areas with shortcuts and return paths. Structurally at odds
    with the linear `next_scene` chain: a real change, not a tweak.
42. Boss trophy system + trophy loadout (GAME.md §7); colony hub + trophy room
    (§8/§23).
43. Three keys + Granny's secret + endings (§20-22). The hazard exists, the
    payoff does not.
44. Discrete growth size states with collision changes + small-route gating
    (§14/§17); fullness is currently continuous and collision never changes.
45. More levels: pantry, inside-the-walls, bathroom, basement, garden, deeper
    sewer (§35).
46. Beetle enemy (armoured, attack from behind) + enemy config as Resources.
47. Centipede enemy; spider web attacks.
48. Scout + Brute playable characters (§3); metabolism / size-loss mechanic (§14).
49. Co-op architecture (§24). Keep avoiding player singletons meanwhile.
50. Kage-style Three.js landing/marketing page.

---

## Everything, in order

The whole backlog on one screen. The number is the rank; P is the priority band.

| #  | P | Item |
|----|---|------|
| 1  | 1 | Completability tests for the other five levels (DONE 2026-08-22) |
| 2  | 1 | Cat level: cannot get past it (DONE: it was the missing ending) |
| 3  | 1 | `smoke_test_3d` fails on main (DONE: stale constants) |
| 4  | 1 | Audit boss summons on rat, cat, wasp, Queen |
| 5  | 1 | Zero hearts while still alive, reported from a live run 202... |
| 6  | 2 | Baby enemies get stuck in props on the cat level (salt shak... |
| 7  | 2 | Checkpoints and exits obscured by props |
| 8  | 3 | Nothing teaches the combos |
| 9  | 3 | The wasp fight cannot be worked out by playing it |
| 10 | 3 | Iron Dice Grit at 13-14 px in a browser, still never eyeballed |
| 11 | 3 | Is the drain too long? 51 m to 91 m in one change |
| 12 | 4 | Spider Queen has no threat: web that GRABS him, mash left/r... |
| 13 | 4 | Mantis kit: eggs that hatch, warp, spinning-blade charge, r... |
| 14 | 4 | Wasp: lays eggs that hatch into a swarm and build up if ign... |
| 15 | 4 | Rat/street level too short |
| 16 | 5 | Death bursts into shapes, then into food, energy and COINS.... |
| 17 | 5 | Baby matrix at level end: a grid where every square is a ba... |
| 18 | 5 | Leaderboard: babies, hearts left and kill speed feed a scor... |
| 19 | 5 | Shop: coins buy armour, weapons, skins, assistance, shields |
| 20 | 6 | Cat foreleg rig |
| 21 | 6 | Granny's eyes follow him |
| 22 | 6 | Granny's swatter still descends on its own 6 m handle rathe... |
| 23 | 6 | Spider gait is goofy |
| 24 | 6 | Three synthesised hooks: `rat_cry`, `mantis_cry`, `mantis_h... |
| 25 | 6 | Eight delivered recordings unused (`cut_hurt_2` is likely `... |
| 26 | 6 | Per-enemy movement sounds; baby chirp; weapon-specific swings |
| 27 | 6 | A fourth music track |
| 28 | 6 | Export still ships `tests/` (`export_filter="all_resources"`) |
| 29 | 6 | Nothing on the tabletop falls when the cat shakes it |
| 30 | 6 | Ghost dies with the scene; no bank-at-a-nest step |
| 31 | 6 | Hidden rooms beyond the two breakables |
| 32 | 6 | Meshy GLB for Harry in staging, not wired in |
| 33 | 7 | Glutton level |
| 34 | 7 | Roof |
| 35 | 7 | Trees |
| 36 | 7 | Aliens in a flying saucer |
| 37 | 7 | Take their craft to the Moon |
| 38 | 7 | Moonbugs on the Moon |
| 39 | 7 | Spacewarp to Mars |
| 40 | 7 | Weapons and hazards escalate with it, probably as their own... |
| 41 | 8 | Interconnected areas with shortcuts and return paths |
| 42 | 8 | Boss trophy system + trophy loadout (GAME.md §7); colony hu... |
| 43 | 8 | Three keys + Granny's secret + endings (§20-22) |
| 44 | 8 | Discrete growth size states with collision changes + small-... |
| 45 | 8 | More levels: pantry, inside-the-walls, bathroom, basement,... |
| 46 | 8 | Beetle enemy (armoured, attack from behind) + enemy config... |
| 47 | 8 | Centipede enemy; spider web attacks |
| 48 | 8 | Scout + Brute playable characters (§3); metabolism / size-l... |
| 49 | 8 | Co-op architecture (§24) |
| 50 | 8 | Kage-style Three.js landing/marketing page |

---

## Standing rules

- **Every level ends in a boss** (P0). All six do. Each needs its own identity,
  attack, arena, weakness and defeat mechanic, never a normal enemy with more
  health.
- **Level contract**: EXPLORE → LEARN → ESCALATE → BOSS → REWARD → EXIT, with
  the exit LOCKED → BOSS ACTIVE → BOSS DEFEATED → UNLOCKED → TRANSITION.
- **Performance**: Compatibility renderer, shadows off, 0.75 3D scale, draw
  calls under the per-level budget `tests/perf_budget_test.gd` enforces.
