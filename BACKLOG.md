# BACKLOG

Deferred work, in PRIORITY ORDER (reordered 2026-08-22). Not auto-loaded:
CLAUDE.md points here.
Design brief: GAME.md · system map: docs/implementation-audit.md · audio: docs/audio-brief.md.

Completed epics and their acceptance criteria were condensed out on 2026-08-17;
recoverable from git history if a decision needs re-reading.

**The ordering principle: nothing outranks making the game finishable.** Until
it is, every other improvement lands on a game nobody can complete. Priorities 1
and 2 are that. Everything below them is a better game, not a finished one.

Items are numbered 1 to 56 straight through, so an item's number IS its rank.
The whole list in one block is at the bottom, under "Everything, in order".

## Now / Next / Later (wrap-up 2026-08-30)

**Now** (needs the user, not code):
- Play roof through MARS by hand - harness-only so far; live reports outrank suites.
- Say "promote" when preview feels right; STABLE is still the 7-level build.
- Zero-hearts-while-alive (#5): blocked on a reproduction from a live run.

**Next** (code, small):
- #7 baby enemies stuck in salt shakers on the cat level.
- #16 tail: delete the dead CRUMBS / FRUIT HUD labels.

**Later**:
- Levels beyond Mars, if the arc ever continues (colony-defense? new planet?).
- Real recordings for the remaining placeholder SFX (drop-in convention works).
- Co-op (why the player has no singleton).

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
4. ~~**Audit boss summons on rat, cat, wasp, Queen.**~~ **DONE 2026-08-22.**
   `boss_summons_test` forces each wave and checks where it lands. It found one
   real defect and one design question.
   - **THE CAT'S NINE ANTS WERE STRANDED.** `_summon_wave` dropped adds at the
     boss's own position, and the cat sits at z -6, so every ant landed six
     metres behind the plane Harry runs on, unable to reach him or be reached.
     The same trap the food burst in the same file fell into, a few lines away.
     Adds now drop on the play plane, clamped inside the arena.
   - **Every boss calls 3 waves of 3, so 9 ants per fight, all on defaults.**
     Not asserted, because how hard a fight should be is a design call. But it
     is a lot for the two POSITIONAL fights: the wasp needs you stood in syrup
     and then out of it, and the Queen needs you under an anchor. Granny was
     already set to 0 for exactly this reason. Worth deciding per boss rather
     than leaving six bosses on one default.
   - Mantis nymphs are `MantisBoss3D`, and bosses in this game deliberately do
     not implement `stagger()`. Anything counting enemies by that method cannot
     see them: it is why the audit first reported the mantis calling 3 and 0
     arriving.

5. **Zero hearts while still alive**, reported from a live run 2026-08-22 and
   NOT reproduced. `health` is only reduced in `take_damage`, which always calls
   `_die()` at zero; nothing else in the codebase writes to it; the hearts
   widget renders halves correctly; 6000 frames of the drain pit death loop
   produced no alive-on-zero frame. Shielded hits are the only half-damage path
   in the game and remain the main suspect. Needs the level, whether a shield
   was held, and what had just hit him.

6. ~~**"The game feels glitchy now."**~~ **DONE 2026-08-22.** Not the sharing:
   Pages is static files and there is no server. Every banked baby FOLLOWS YOU
   INTO EVERY LEVEL wearing the full player model at 0.4 scale, 21 meshes each
   including glints 8 mm across, and they cluster on the player where the camera
   is pointed. Eight of them took the tabletop from 6.19 draws/m to 11.94
   against a 6.5 ceiling, so the game got heavier the better you had played.
   A cheap 5-draw baby visual fixes it; `baby_cost_test` guards the margin, and
   `perf_budget_test` is now hermetic (it was reading the local save, so its
   numbers drifted with whatever had last been played).
   ~~**STILL OPEN:** even at 5 draws a full eight babies puts the tabletop at
   6.69/m, over the 6.5 ceiling, because that level is 6.19 on its own.~~
   **RESOLVED 2026-08-28 as a side effect of extending every level:** the
   tabletop's new breakfast end widened its span, and the level now measures
   4.40/m bare, about 5.1/m with eight babies. No cap, trim, or ceiling change
   was needed.

## Priority 2: Bugs that break play but do not lock it.

7. **Baby enemies get stuck in props** on the cat level (salt shakers).
8. ~~**Checkpoints and exits obscured by props.**~~ **DONE 2026-08-22.**
   `landmarks_clear_test` checks all 16 landmarks across the six levels and they
   are all clear, so there was nothing to fix — but it took four versions to ask
   the question properly, and the wrong ones are the useful part:
   - ignoring z reported the drain's 12 m BACKGROUND wall as burying a
     checkpoint it stands five metres behind;
   - measuring against the landmark's own z looked right and was worse: a crate
     planted at z 0.2, squarely in the player's path, counted as "behind" a
     checkpoint SIGN at z 1.4 and was waved through;
   - light-shaft beams are script-less children of `LightShaft3D`, so they look
     like loose decor, and the drain hangs one 0.7 m in front of its own exit;
   - a prop whose top is below the landmark is floor, not wall.
   The settled rule: an EXIT sits at z 0 and is blocked by bulk on the play
   plane (the pantry case); a checkpoint SIGN sits forward at z 1.2-1.4 and can
   only be hidden by something nearer the camera still. Verified by planting a
   pantry-sized box on the kitchen door and watching it fail.

9. ~~**The drain's shaft is a capped dead end...**~~ **DONE 2026-08-29: walkway pipe raised 8.0 to 8.6 (the user's number); climb goes somewhere.** Original:
   Answered 2026-08-22, and it is NOT a lockout. `ShaftWallRight` tops out at
   y 7.40, and `drain_level.gd` runs a SOLID pipe at y 8.00 from x 29 to 37
   (radius 0.45, so its underside is 7.55) straight over it. Clearance: 0.15 m.
   Harry climbs the shaft beautifully - 1.2 m to 7.22 m in 2.7 seconds - and
   then stops dead with his head under the pipe, still clinging, forever.
   Flight does not help: `_apply_flight` returns early while `is_climbing`, and
   releasing the wall to break the climb still leaves the pipe in the way.
   The intended route is the pipes themselves (y 3.4, then 5.2, then 8.0),
   walking the top of that same pipe across to the UpperLedge. So the level is
   passable and the shaft is scenery you can climb into and get stuck at the top
   of. Raising the x 29-37 pipe to about y 8.6 would give a climber roughly
   0.75 m to mantle out, without costing it its job as a bridge. A level-design
   call, not a bug fix.
10. **DONE 2026-08-28 — THE WALKER.** `levels_walkable_test` walks all seven
    levels spawn to boss arena with real inputs only (run, ray-and-jump,
    climb, dash, fly), harness-funded on health and wings because the
    question is geometry, not combat. The flakiness that killed the first
    attempt is answered by a deterministic escalation ladder (climb -> fly ->
    retreat-further-and-fly, rungs reset per window) and real-second holds:
    two consecutive full runs produced identical numbers. It sits in the
    deploy gate. Found on its second run: a lethal 1m seam between the
    street's alley and pavement (closed), and live proof of item 9 - the
    drain shaft IS a dead-end trap, but the level passes by backing off and
    flying the pipe route (36s, one escalation).
    Original note: The completability tests beat every boss and
   reach every exit, but they PUT Harry next to the boss to do it, and
   `smoke_test_3d` only walks the drain's opening. The part in between - the
   level, where the player spends nearly all their time - is untested. A wall he
   cannot climb halfway through would pass all six suites.
   Attempted 2026-08-22 and NOT shipped, because the driver is flaky: street
   reached the arena twice and stalled at x 21.9 on the third run, which means
   enemies and hazards knock the result about. A flaky test is worse than none.
   What it did show, twice: street, kitchen, counter, granny and tabletop are
   all walkable spawn-to-arena, and the DRAIN stalls at x 35.2 against
   `ShaftWallRight` (x 36.3, 6.6 m tall), which the route to the Queen requires
   climbing. Whether a player can make that climb is UNVERIFIED - three times
   today a level looked broken and was this harness driving badly. Worth
   answering, by hand if necessary, because it is the first level in the game.

## Priority 3: Nobody can play what they cannot read.

11. ~~**Nothing teaches the BOSS RULES.**~~ **DONE 2026-08-23.** Every boss now
    carries a one-line `boss_rule`, shown on the HUD when the fight starts and
    again, at the swing, whenever a hit is shrugged off. The cat's "NOT THERE!"
    and Granny's "SHE'S TOO BIG!" were both anchored to the BOSS, which put them
    7.5 m up and 6 m back and 6.6 m up a counter respectively: the player swung,
    nothing happened, and the explanation appeared where nobody was looking.
    `boss_rules_taught_test` checks each rule exists, fits a HUD line, is ASCII,
    and ACTUALLY REACHES THE HUD on engage. Still open: the COMBOS below.
12. ~~**Nothing teaches the combos.**~~ **DONE 2026-08-23.** The drain's pogo
    hint now covers the MEGA SMASH (same input, off a real drop) and a new
    `HintBackflip` at the climber wave covers the BACKFLIP KICK, which is the
    one place in the level that deliberately puts something behind you.
    `combos_taught_test` checks both are taught somewhere, by INPUT rather than
    wording, so the copy stays free to change.
    **It also found two dead hints.** `street_level.tscn` declared
    `[node name="Hints"]` TWICE, and `_style_hints` does
    `get_node_or_null("Hints")` and walks that one node, so everything in the
    second block was orphaned: three hints in the file, ONE reaching the player.
    The two lost were the dash and the mantis's frontal guard, which is one of
    the four boss rules you cannot work out by playing. Merged, and the test now
    asserts every hint in a level is actually collected.
13. **Nothing teaches the combos.** PLACEHOLDER Mega smash and backflip kick are unmentioned
   anywhere, so most players never learn they exist. Nor is any BOSS rule
   taught, and writing the completability tests turned up how much of that
   there is: the cat is immune and only the paw counts; the mantis guards a 150
   degree frontal cone so only an overhead pogo lands; the Queen cannot be hurt
   until every web is cut.
14. **DONE 2026-08-28.** `_impact` checks the syrup BEFORE the hit now: a
    dive that clips him while landing in the honey still sticks, so standing
    in the syrup - the obvious reading of the bait - costs a hit instead of
    being a dead end. The old `wasp_boss_test` assertion encoded the bug as
    a feature and now asserts the rule.
    Original note: `_impact` tests
   whether the dive HIT HIM before it tests the syrup, so a dive that connects
   bounces off and the wasp is never vulnerable. Standing in the honey, which is
   the obvious reading of "bait it into the syrup", means being hit forever and
   the fight has no opening at all. The real answer is bait it, then step out of
   `dive_radius` before it lands, and nothing says so. Found by the counter
   completability test failing for 90 seconds against a boss that turned out to
   be beatable in 3.
15. ~~**Iron Dice Grit at 13-14 px in a browser.**~~ **DONE 2026-08-23.** Finally
    eyeballed, by rendering a level at the export's real 1280x720. It is fine:
    Iron Dice Grit is a pixel face and "FLYING POWER" at 13 px is crisp. The
    only other 13-14 px labels are the debug readout and the title's "early
    prototype". No change made.
16. **CRUMBS / FRUIT / BABIES are dead UI.** **HALF DONE 2026-08-28:** BABIES
    got its home on the HUD (the shop's baby grid and the matrix are built on
    it), and a COINS readout joined it. CRUMBS and FRUIT are still hidden dead
    weight: delete them or find them a job.
    Original note: `_on_food_changed` writes
    `"CRUMBS %d"` into `_food_label` on every pickup, into a label that is
    `visible = false` in `hud.tscn` and that nothing ever turns on. Same for
    `$Fruit` and `$Babies`. All three sit within 2 px of where the Weapon and
    Shield labels now are. NOT a bug: `git log -L` points at 851ffc5, whose
    message says "CRUMBS/FRUIT/BABIES hidden", so it was deliberate when hints
    moved onto the HUD line. What is left is dead weight: three labels and their
    signal handlers updated for nothing. Either delete them or give BABIES a
    home, since the player currently has no idea how many they are carrying and
    the matrix (item 18) is built on that number.
17. **Is the drain too long?** 51 m to 91 m in one change.

## Priority 4: The fights. This is the game's stated identity.

18. ~~**Spider Queen has no threat**: web that GRABS him, mash left/right to
    escape, babies biting while he is held.~~ **DONE 2026-08-28, on the
    user's call.** She shoots a silk glob (a `Projectile3D` with
    `wrap_seconds`, so reflect weapons can bat it back); a hit WRAPS him -
    no moving, flying or swinging - and alternating left/right presses
    shaves it down (0.6s wiggled vs 1.6s passive, `spider_queen_threat_test`).
    Her summons are her own brood now: two baby spiders per wave (shrunk on
    the visual's PARTS - the parent's scale is animation-owned - at 1 health,
    full hitbox), and her legs kick against the silk while she hangs and
    carry her while she hunts. Whiffed swings near ANY active boss re-show
    its rule (the "z-index" report was this silence).
19. **MOSTLY DONE 2026-08-28**: the spinning-blade charge (every fourth
    attack, unguarded, dizzy at the far wall for the longest punish window),
    the WARP (two quick hits while it has footing and it blinks to your far
    side - cooldown-gated, never out of an earned punish), and nymphs
    guarding the gate when the big one dies (an escort out, not a second
    lock). `mantis_kit_test` plays all three. Still open: eggs that hatch,
    and the reaper attack.
20. **Wasp**: lays eggs that hatch into a swarm and build up if ignored. Honey
    drips from above instead of poison.
21. ~~**Rat/street level too short.**~~ **DONE 2026-08-28 in the extend-all-levels pass** (the walker later found and closed the alley seam the extension introduced).

## Priority 5: Systems. Strict dependency order; each needs the one above it.

22. ~~**Death bursts into shapes, then into food, energy and COINS.**~~
    **DONE 2026-08-28, both halves.** Coins ride the burst (earlier today),
    and now BOSSES SHATTER: all seven creature bosses come apart into their
    own meshes on defeat, resolving into the treats-and-coins burst - the
    user made the retreat-vs-die design call the item was parked on. Granny
    and the cat walk away by design (people and pets are not blown up);
    `boss_shatter_test` locks all nine behaviors. **CLOSED 2026-08-29:** wing
    shards ride the fountain too (`wing_shard_3d.tscn`, 15 energy, 10 s decay:
    a kill refunds flight, pressing on beats hoarding) - small enemies drop 1,
    bosses `boss_shard_drop` = 3. Item 22 is DONE end to end.
    Original note:
    **COINS DONE 2026-08-28:** they ride the same `FoodBurst` fountain
    (enemies 1, bosses `boss_coin_drop` = 6), plus a few placed per level;
    balance and upgrades persist in SaveGame for the run. Still open here:
    wing energy in the burst, and bosses do not shatter. Enemies
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
23. ~~**Baby matrix at level end**: a grid where every square is a banked baby,
    previous levels grey, this level lit. Filling it is the long game.~~
    **DONE 2026-08-28.** THE COLONY MATRIX: the shop grid is per-level rows
    now (DRAIN / STREET / ... / PANTRY), one square per baby that level's
    door banked, the just-finished level's rescues lit. Provenance lives in
    SaveGame as a ledger reconciled against the untouched total on every
    write: gains credit the level in play, losses (babies die with him and
    return as ghosts) drain the NEWEST level's row first. `baby_matrix_test`
    covers the ledger math and a real drain run crediting its own door.
24. ~~**Leaderboard**: babies, hearts left and kill speed feed a score, enter a
    name.~~ **DONE 2026-08-28, on the user's call ("its so easy to finish").**
    LOCAL arcade board, like a cabinet's: Pages is static so there is no
    server; a global one wants a small Vercel function later. Score = babies
    x500 + coins EARNED x25 (spending at the stash never costs points) +
    half-hearts left x75. Three-initial wheel on the ending screen, top ten
    in `user://leaderboard.cfg` (its own file - NEW GAME wipes the run, never
    the glory), ties lose to the sitting entry, HI-SCORE line on the title.
    Kill speed still unscored: nothing times the run yet.
25. **Shop: coins buy armour, weapons, skins, assistance, shields.**
    **FIRST PASS DONE 2026-08-28:** THE STASH (`ui/shop/`) sits between every
    pair of levels; coins buy six RUN-persistent upgrades (extra heart, wing
    tank, thick shell, power hits, funny sounds, ridiculous hat — the user's
    list). Purchases survive death, NEW GAME wipes them. The three decisions
    below were settled by that: currency exists, persistence = the run,
    shop = a screen between levels. Still open: skins beyond the hat,
    assistance, and anything weapon/shield-shaped (level-scoped on purpose).
    Original plan:
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

26. **Cat foreleg rig.** Granny's arm chain (shoulder to elbow to hand pivots,
    `_build_arms` in `granny_boss_3d.gd`) is the pattern to copy.
27. **Granny's eyes follow him.** Her head and everything on it now hangs off
    one `head_pivot`, which is exactly what eye-tracking needs.
28. **Granny's swatter** still descends on its own 6 m handle rather than at the
    end of the arm that now swings for it. Her stomp is a thrown shoe already.
29. **Spider gait is goofy.** Less swing, more weight. The QUEEN's legs
    animate now (2026-08-28: paired gait pivots, struggle kicks); the small
    spider's own gait is still the goofy one this item means.
30. **Three synthesised hooks**: `rat_cry`, `mantis_cry`, `mantis_hurt`.
31. **Eight delivered recordings unused** (`cut_hurt_2` is likely `mantis_hurt`).
32. Per-enemy movement sounds; baby chirp; weapon-specific swings.
33. A fourth music track.
34. **Export still ships `tests/`** (`export_filter="all_resources"`).
35. Nothing on the tabletop falls when the cat shakes it.
36. Ghost dies with the scene; no bank-at-a-nest step.
37. Hidden rooms beyond the two breakables.
38. Meshy GLB for Harry in staging, not wired in.

## Priority 7: The second half (user's arc, 2026-08-21).

Escalation only works in order; each is a level's worth of work and several
need systems that do not exist.

**ITINERARY CONFIRMED by the user 2026-08-28, in this order:** roof (DONE,
magpie) -> roof garden (DONE 2026-08-28: level 9 at dawn, walls stop the
wind as the roof's lesson made architecture, lily-pad pond, and THE SNAIL -
ninth verb, FLIP it: only the fork's launch tips it, two tips turn it over,
the soft side is the fight, and its slime slowly claims the arena) ->
tree (DONE 2026-08-28: level 10, the arc goes vertical - a leaning trunk
climbed branch to branch with soft falls and gripping amber sap, and THE
OWL in the crown: tenth verb, FREEZE - it strikes at any movement under
its stare, swings included, and reaching its perch unseen is the whole
fight; it flutters between two perches as it is hurt. Plus LEVEL SELECT
(TESTING) on the title, the user's call: pick a level, GO) ->
alien abduction (DONE 2026-08-29: level 11, the saucer's beam sweeps the night
field and HOLDS like webs, the exit is the parked beam; THE PROBE, verb 11 =
REFLECT, only its own zap spooned back pierces the shimmer) ->
moon (DONE 2026-08-29: level 12, gravity 8, Earth in the sky; THE DUST WORM,
verb 12 = UNBURY - hunts footsteps like Dune, smack the mound, it dives after
two bites) ->
spaceship (DONE 2026-08-29: level 13, chrome decks, specimen jars; THE
JANITOR-BOT, verb 13 = CLOG - suction drags junk, only a SMACKED can jams the
fan, it restocks its own ammo) ->
Mars (DONE 2026-08-29: level 14, THE END. THE WAR TRIPOD, verb 14 = TOPPLE -
eye out of reach, break three knees, two topples to fell it. The colony
begins). THE ITINERARY IS COMPLETE - 14 levels, suite at 68, all on preview;
STABLE still awaits the user's promote.

39. ~~**Glutton level.**~~ **DONE 2026-08-28 - it jumped the queue as
    predicted, on the user's ask for a level after the cat.** THE PANTRY,
    level 7, chained after the tabletop: gorge half (shelves of food, a soft
    panel only a HEAVY bite opens), gym half (Z / poo bomb taught), and THE
    TOAD at the door - the seventh boss, verb = what you FEED it: immune to
    everything, beaten by dropping poo bombs in tongue range until its
    appetite (the boss bar) is gone, so the gorge, the gym and the boss are
    one loop. `pantry_level_completable_test` feeds it with real button
    presses and rides out to the ENDING. Still open from the original note:
    exercise stations, if the bomb alone proves too thin a gym.
40. ~~**Roof.** Wind, and a real fall below you.~~ **DONE 2026-08-28.**
    Level 8: WIND as the antagonist (`Wind3D`, GrannyHazard-shaped - a
    seeded CALM/RISING/GUST cycle, gusts own the AIR while chimneys are
    taught shelter via an upwind ray; the player answers through a per-frame
    `apply_wind` contract that fails safe to still air). THE MAGPIE holds
    the gable: eighth boss, eighth verb - it only lands to GLOAT. It steals
    coins on the swoop, gloats over them in reach, tumbles when dodged, and
    every hit shakes the hoard back out of it.
41. **Trees.** Vertical, branch to branch; climbing and flight already suit it.
42. **Aliens in a flying saucer.** The first non-insect enemy.
43. **Take their craft to the Moon.** Sequence animation, MUST be skippable.
44. **Moonbugs on the Moon.** Needs LOW GRAVITY: jump, flight drain and
    knockback are all tuned against 26 m/s/s and the wing bar is the whole
    economy.
45. **Spacewarp to Mars.** Own hazards; weapons that suit vacuum, not a kitchen
    drawer.
46. Weapons and hazards escalate with it, probably as their own tier.

## Priority 8: Later. Structural, and all cheaper once the game is finishable.

47. Interconnected areas with shortcuts and return paths. Structurally at odds
    with the linear `next_scene` chain: a real change, not a tweak.
48. Boss trophy system + trophy loadout (GAME.md §7); colony hub + trophy room
    (§8/§23).
49. Three keys + Granny's secret + endings (§20-22). The hazard exists, the
    payoff does not.
50. Discrete growth size states with collision changes + small-route gating
    (§14/§17); fullness is currently continuous and collision never changes.
51. More levels: pantry, inside-the-walls, bathroom, basement, garden, deeper
    sewer (§35).
52. Beetle enemy (armoured, attack from behind) + enemy config as Resources.
53. Centipede enemy; spider web attacks.
54. Scout + Brute playable characters (§3); metabolism / size-loss mechanic (§14).
55. Co-op architecture (§24). Keep avoiding player singletons meanwhile.
56. Kage-style Three.js landing/marketing page.

---

## Everything, in order

The whole backlog on one screen. The number is the rank; P is the priority band.

| #  | P | Item |
|----|---|------|
| 1  | 1 | Completability tests for the other five levels |
| 2  | 1 | Cat level: cannot get past it |
| 3  | 1 | `smoke_test_3d` fails on main |
| 4  | 1 | Audit boss summons on rat, cat, wasp, Queen |
| 5  | 1 | Zero hearts while still alive, reported from a live run 202... |
| 6  | 1 | "The game feels glitchy now." DONE 2026-08-22 |
| 7  | 2 | Baby enemies get stuck in props on the cat level (salt shak... |
| 8  | 2 | Checkpoints and exits obscured by props |
| 9  | 2 | The drain's shaft is a capped dead end, and it looks like t... |
| 10 | 2 | NOTHING WALKS A LEVEL. The completability tests beat every... |
| 11 | 3 | Nothing teaches the BOSS RULES. DONE 2026-08-23 |
| 12 | 3 | Nothing teaches the combos |
| 13 | 3 | Nothing teaches the combos |
| 14 | 3 | The wasp fight cannot be worked out by playing it |
| 15 | 3 | Iron Dice Grit at 13-14 px in a browser |
| 16 | 3 | CRUMBS / FRUIT / BABIES are dead UI. `_on_food_changed` writes |
| 17 | 3 | Is the drain too long? 51 m to 91 m in one change |
| 18 | 4 | Spider Queen has no threat: web that GRABS him, mash left/r... |
| 19 | 4 | Mantis kit: eggs that hatch, warp, spinning-blade charge, r... |
| 20 | 4 | Wasp: lays eggs that hatch into a swarm and build up if ign... |
| 21 | 4 | Rat/street level too short |
| 22 | 5 | Death bursts into shapes, then into food, energy and COINS.... |
| 23 | 5 | Baby matrix at level end: a grid where every square is a ba... |
| 24 | 5 | Leaderboard: babies, hearts left and kill speed feed a scor... |
| 25 | 5 | Shop: coins buy armour, weapons, skins, assistance, shields |
| 26 | 6 | Cat foreleg rig |
| 27 | 6 | Granny's eyes follow him |
| 28 | 6 | Granny's swatter still descends on its own 6 m handle rathe... |
| 29 | 6 | Spider gait is goofy |
| 30 | 6 | Three synthesised hooks: `rat_cry`, `mantis_cry`, `mantis_h... |
| 31 | 6 | Eight delivered recordings unused (`cut_hurt_2` is likely `... |
| 32 | 6 | Per-enemy movement sounds; baby chirp; weapon-specific swings |
| 33 | 6 | A fourth music track |
| 34 | 6 | Export still ships `tests/` (`export_filter="all_resources"`) |
| 35 | 6 | Nothing on the tabletop falls when the cat shakes it |
| 36 | 6 | Ghost dies with the scene; no bank-at-a-nest step |
| 37 | 6 | Hidden rooms beyond the two breakables |
| 38 | 6 | Meshy GLB for Harry in staging, not wired in |
| 39 | 7 | Glutton level |
| 40 | 7 | Roof |
| 41 | 7 | Trees |
| 42 | 7 | Aliens in a flying saucer |
| 43 | 7 | Take their craft to the Moon |
| 44 | 7 | Moonbugs on the Moon |
| 45 | 7 | Spacewarp to Mars |
| 46 | 7 | Weapons and hazards escalate with it, probably as their own... |
| 47 | 8 | Interconnected areas with shortcuts and return paths |
| 48 | 8 | Boss trophy system + trophy loadout (GAME.md §7); colony hu... |
| 49 | 8 | Three keys + Granny's secret + endings (§20-22) |
| 50 | 8 | Discrete growth size states with collision changes + small-... |
| 51 | 8 | More levels: pantry, inside-the-walls, bathroom, basement,... |
| 52 | 8 | Beetle enemy (armoured, attack from behind) + enemy config... |
| 53 | 8 | Centipede enemy; spider web attacks |
| 54 | 8 | Scout + Brute playable characters (§3); metabolism / size-l... |
| 55 | 8 | Co-op architecture (§24) |
| 56 | 8 | Kage-style Three.js landing/marketing page |

---

## Standing rules

- **Every level ends in a boss** (P0). All six do. Each needs its own identity,
  attack, arena, weakness and defeat mechanic, never a normal enemy with more
  health.
- **Level contract**: EXPLORE → LEARN → ESCALATE → BOSS → REWARD → EXIT, with
  the exit LOCKED → BOSS ACTIVE → BOSS DEFEATED → UNLOCKED → TRANSITION.
- **Performance**: Compatibility renderer, shadows off, 0.75 3D scale, draw
  calls under the per-level budget `tests/perf_budget_test.gd` enforces.
