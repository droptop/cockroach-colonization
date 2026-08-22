# BACKLOG

Deferred work, in PRIORITY ORDER (reordered 2026-08-22). Not auto-loaded:
CLAUDE.md points here.
Design brief: GAME.md · system map: docs/implementation-audit.md · audio: docs/audio-brief.md.

Completed epics and their acceptance criteria were condensed out on 2026-08-17;
recoverable from git history if a decision needs re-reading.

**The ordering principle: nothing outranks making the game finishable.** Until
it is, every other improvement lands on a game nobody can complete. Priorities 1
and 2 are that. Everything below them is a better game, not a finished one.

Items are numbered 1 to 49 straight through, so an item's number IS its rank.
The whole list in one block is at the bottom, under "Everything, in order".

---

## Priority 1: Finishability. The whole game is blocked on these.

**Nobody has finished this game.** Three bosses have never been reached, and
four separate lockouts were found on 2026-08-21, so assume more.

1. ~~**Completability tests for the other five levels.**~~ **DONE 2026-08-22.**
   `tests/support/level_completable.gd` is the shared harness;
   drain/street/kitchen/counter/tabletop each have one. Every one beats its
   boss by pressing the attack button, WALKS to the exit, and waits for the next
   scene. All five pass, so **the game is completable end to end.** Verified to
   fail for the right reason by putting the Queen back on `collision_layer = 0`
   and the cat's paw with her: both went to "6 -> 6 health in 90s".
2. **Cat level: not a lockout.** The tabletop test beats the cat by hitting the
   PAW, walks to the door and completes the game, so the route works and the
   EXIT signs are fine. What the user hit is therefore not a broken level: the
   most likely cause is that nothing tells you the cat itself is immune and the
   paw is the only target. That is item 7, not a bug here. Worth watching them
   play it before spending anything else on it.
3. **`smoke_test_3d` fails on main**, and did before the 2026-08-22 session
   (identical numbers on a clean checkout: x -33.32, health 4/8, food 0). He is
   stuck around x -33 taking damage and eating nothing. Cheap to diagnose, and
   it outranks its own size: while it is red, "the suite passes" means less
   every time anyone says it.
4. **Audit boss summons on rat, cat, wasp, Queen.** Added to all six on
   2026-08-20 and it made Granny mathematically unbeatable. Wasp and Queen are
   the risky ones: both fights are positional and adds trample positioning.
   Small check, large blast radius.

## Priority 2: Bugs that break play but do not lock it.

5. **Baby enemies get stuck in props** on the cat level (salt shakers).
6. **Checkpoints and exits obscured by props.** Generalise the Granny doorway
   check to every checkpoint and every exit in all six levels.

## Priority 3: Nobody can play what they cannot read.

7. **Nothing teaches the combos.** Mega smash and backflip kick are unmentioned
   anywhere, so most players never learn they exist. Nor is any BOSS rule
   taught, and writing the completability tests turned up how much of that
   there is: the cat is immune and only the paw counts; the mantis guards a 150
   degree frontal cone so only an overhead pogo lands; the Queen cannot be hurt
   until every web is cut.
8. **The wasp fight cannot be worked out by playing it.** `_impact` tests
   whether the dive HIT HIM before it tests the syrup, so a dive that connects
   bounces off and the wasp is never vulnerable. Standing in the honey, which is
   the obvious reading of "bait it into the syrup", means being hit forever and
   the fight has no opening at all. The real answer is bait it, then step out of
   `dive_radius` before it lands, and nothing says so. Found by the counter
   completability test failing for 90 seconds against a boss that turned out to
   be beatable in 3.
9. **Iron Dice Grit at 13-14 px in a browser**, still never eyeballed.
10. **Is the drain too long?** 51 m to 91 m in one change.

## Priority 4: The fights. This is the game's stated identity.

11. **Spider Queen has no threat**: web that GRABS him, mash left/right to
    escape, babies biting while he is held.
12. **Mantis kit**: eggs that hatch, warp, spinning-blade charge, reaper attack;
    nymphs spread out and guard the gate when the big one dies.
13. **Wasp**: lays eggs that hatch into a swarm and build up if ignored. Honey
    drips from above instead of poison.
14. **Rat/street level too short.** Same treatment the drain got.

## Priority 5: Systems. Strict dependency order; each needs the one above it.

15. **Death bursts into shapes, then into food, energy and COINS.** Enemies
    already `Fx.shatter` into their own meshes and `FoodBurst.spawn` a fountain
    of food. What is missing: wing energy is not part of the burst, coins do
    not exist, and bosses do not shatter at all. Making the shapes RESOLVE into
    pickups unifies three separate death effects into one readable moment, and
    it is also how coins ENTER the game, which is what item 18 waits on.
    **Open decision:** five of the six bosses RETREAT rather than die, each
    with its own retreat animation, and `granny_encounter_test` asserts "she
    retreats rather than dying". Only the rat reaches a DEAD state. The loot
    burst can be given to all six without touching that. Blowing the boss's own
    body apart can only go to the rat unless the other five are changed from
    retreating to dying, which is a design call, not a bug fix.
16. **Baby matrix at level end**: a grid where every square is a banked baby,
    previous levels grey, this level lit. Filling it is the long game.
17. **Leaderboard**: babies, hearts left and kill speed feed a score, enter a
    name. Needs the matrix first.
18. **Shop: coins buy armour, weapons, skins, assistance, shields.** Wants
    three things, in this order:
    1. **Coins**, delivered by item 15. A currency that is NOT food: food is
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

19. **Cat foreleg rig.** Granny's arm chain (shoulder to elbow to hand pivots,
    `_build_arms` in `granny_boss_3d.gd`) is the pattern to copy.
20. **Granny's eyes follow him.** Her head and everything on it now hangs off
    one `head_pivot`, which is exactly what eye-tracking needs.
21. **Granny's swatter** still descends on its own 6 m handle rather than at the
    end of the arm that now swings for it. Her stomp is a thrown shoe already.
22. **Spider gait is goofy.** Less swing, more weight.
23. **Three synthesised hooks**: `rat_cry`, `mantis_cry`, `mantis_hurt`.
24. **Eight delivered recordings unused** (`cut_hurt_2` is likely `mantis_hurt`).
25. Per-enemy movement sounds; baby chirp; weapon-specific swings.
26. A fourth music track.
27. **Export still ships `tests/`** (`export_filter="all_resources"`).
28. Nothing on the tabletop falls when the cat shakes it.
29. Ghost dies with the scene; no bank-at-a-nest step.
30. Hidden rooms beyond the two breakables.
31. Meshy GLB for Harry in staging, not wired in.

## Priority 7: The second half (user's arc, 2026-08-21).

Escalation only works in order; each is a level's worth of work and several
need systems that do not exist.

32. **Glutton level.** The outlier, and the one that could jump the queue to
    around Priority 5: nothing but food until he is too heavy to continue, then
    a GYM to work it off. The only idea so far that makes fullness the SUBJECT
    rather than a tax, and it needs no systems that do not already exist.
    Pairs with the poo bomb.
33. **Roof.** Wind, and a real fall below you.
34. **Trees.** Vertical, branch to branch; climbing and flight already suit it.
35. **Aliens in a flying saucer.** The first non-insect enemy.
36. **Take their craft to the Moon.** Sequence animation, MUST be skippable.
37. **Moonbugs on the Moon.** Needs LOW GRAVITY: jump, flight drain and
    knockback are all tuned against 26 m/s/s and the wing bar is the whole
    economy.
38. **Spacewarp to Mars.** Own hazards; weapons that suit vacuum, not a kitchen
    drawer.
39. Weapons and hazards escalate with it, probably as their own tier.

## Priority 8: Later. Structural, and all cheaper once the game is finishable.

40. Interconnected areas with shortcuts and return paths. Structurally at odds
    with the linear `next_scene` chain: a real change, not a tweak.
41. Boss trophy system + trophy loadout (GAME.md §7); colony hub + trophy room
    (§8/§23).
42. Three keys + Granny's secret + endings (§20-22). The hazard exists, the
    payoff does not.
43. Discrete growth size states with collision changes + small-route gating
    (§14/§17); fullness is currently continuous and collision never changes.
44. More levels: pantry, inside-the-walls, bathroom, basement, garden, deeper
    sewer (§35).
45. Beetle enemy (armoured, attack from behind) + enemy config as Resources.
46. Centipede enemy; spider web attacks.
47. Scout + Brute playable characters (§3); metabolism / size-loss mechanic (§14).
48. Co-op architecture (§24). Keep avoiding player singletons meanwhile.
49. Kage-style Three.js landing/marketing page.

---

## Everything, in order

The whole backlog on one screen. The number is the rank; P is the priority band.

| #  | P | Item |
|----|---|------|
| 1  | 1 | Completability tests for the five levels (DONE 2026-08-22) |
| 2  | 1 | Cat level: not a lockout, the paw route works |
| 3  | 1 | `smoke_test_3d` fails on main |
| 4  | 1 | Audit boss summons on rat, cat, wasp, Queen |
| 5  | 2 | Baby enemies stuck in props (cat level salt shakers) |
| 6  | 2 | Checkpoints and exits obscured by props |
| 7  | 3 | Nothing teaches the combos |
| 8  | 3 | The wasp fight cannot be worked out by playing it |
| 9  | 3 | Iron Dice Grit at 13-14 px in a browser, never eyeballed |
| 10 | 3 | Is the drain too long? |
| 11 | 4 | Spider Queen has no threat: grab web, mash to escape |
| 12 | 4 | Mantis kit: eggs, warp, blade charge, nymphs guard the gate |
| 13 | 4 | Wasp: eggs hatch into a swarm; honey instead of poison |
| 14 | 4 | Rat/street level too short |
| 15 | 5 | Death bursts into shapes, then food, energy and COINS |
| 16 | 5 | Baby matrix at level end |
| 17 | 5 | Leaderboard (needs the matrix) |
| 18 | 5 | Shop: coins buy armour, weapons, skins, assistance, shields |
| 19 | 6 | Cat foreleg rig |
| 20 | 6 | Granny's eyes follow him |
| 21 | 6 | Granny's swatter should hang off the arm that swings for it |
| 22 | 6 | Spider gait is goofy |
| 23 | 6 | Three synthesised hooks: `rat_cry`, `mantis_cry`, `mantis_hurt` |
| 24 | 6 | Eight delivered recordings unused |
| 25 | 6 | Per-enemy movement sounds; baby chirp; weapon-specific swings |
| 26 | 6 | A fourth music track |
| 27 | 6 | Export still ships `tests/` |
| 28 | 6 | Nothing on the tabletop falls when the cat shakes it |
| 29 | 6 | Ghost dies with the scene; no bank-at-a-nest step |
| 30 | 6 | Hidden rooms beyond the two breakables |
| 31 | 6 | Meshy GLB for Harry not wired in |
| 32 | 7 | Glutton level (could jump to Priority 5) |
| 33 | 7 | Roof: wind, and a real fall below you |
| 34 | 7 | Trees: vertical, branch to branch |
| 35 | 7 | Aliens in a flying saucer |
| 36 | 7 | Take their craft to the Moon (skippable sequence) |
| 37 | 7 | Moonbugs on the Moon (needs LOW GRAVITY) |
| 38 | 7 | Spacewarp to Mars |
| 39 | 7 | Weapons and hazards escalate with it |
| 40 | 8 | Interconnected areas with shortcuts and return paths |
| 41 | 8 | Boss trophies + loadout; colony hub + trophy room |
| 42 | 8 | Three keys + Granny's secret + endings |
| 43 | 8 | Discrete growth size states + small-route gating |
| 44 | 8 | More levels: pantry, walls, bathroom, basement, garden, sewer |
| 45 | 8 | Beetle enemy + enemy config as Resources |
| 46 | 8 | Centipede enemy; spider web attacks |
| 47 | 8 | Scout + Brute playable characters; metabolism mechanic |
| 48 | 8 | Co-op architecture |
| 49 | 8 | Kage-style Three.js landing page |

---

## Standing rules

- **Every level ends in a boss** (P0). All six do. Each needs its own identity,
  attack, arena, weakness and defeat mechanic, never a normal enemy with more
  health.
- **Level contract**: EXPLORE → LEARN → ESCALATE → BOSS → REWARD → EXIT, with
  the exit LOCKED → BOSS ACTIVE → BOSS DEFEATED → UNLOCKED → TRANSITION.
- **Performance**: Compatibility renderer, shadows off, 0.75 3D scale, draw
  calls under the per-level budget `tests/perf_budget_test.gd` enforces.
