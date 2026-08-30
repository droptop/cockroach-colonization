# WORKLOG

## 2026-08-28 → 30 — drain to MARS: the itinerary completes

The biggest span of the project. Seven new levels shipped (roof garden was 9;
then tree, abduction, moon, ship, mars), seven new bosses each with a new verb
(owl=freeze, probe=reflect, worm=unbury, janitor=clog, tripod=topple - plus
magpie=gloat, snail=flip from the 28th), and the game now ENDS on the red
planet: 14 levels, 14 bosses, suite 50 → 70, every deploy gated and md5-verified.

Shipped besides levels:
- Run clock: banked per level at the door, M:SS on the ending, a point per
  second under 40:00 par on the board. Untimed scores unchanged.
- Shop: TWIN EGGS replaced funny sounds (fresh rescues double at the door);
  two-press buys got the orange ARE YOU SURE treatment; level select became a
  3-column grid after 14 levels ran it off the screen (level_select_test locks
  the class: every button inside the viewport).
- Brood eggs (#19/#20 closed): deniable spawns for mantis and wasp, mantis
  REAPER, wasp honey weather (sticky, never wounding), nymphs stripped of the
  boss guard and reaper they had inherited.
- Wing shards in BOSS bursts only (#22 closed - rewards_test refused the
  small-enemy cut: they already pay exactly one heart-or-shard).
- Mars: oval dunes in three depths (moved behind the play plane after they
  swallowed Harry), its own fauna (dust hopper, gasbag - no house bugs), and
  the tripod WALKS: hip-pivot stilts, three-beat gait, footfall thud/dust/shake.
- Four user recordings wired: checkpoint (own key), YUM (eating), jump
  (drop-in), coin (kind-aware pickup ring). Drain pipe raised to 8.6 (#9).
- Comic bursts 30 percent see-through; ending screen split into two columns.

Bugs the process caught before the user did: abduction's exit floated over a
4 m death pit (walker rolled the unlucky hop phase); honey over the counter
checkpoint + take_damage(0) still shoving = "running forward by itself off the
restart"; a mid-dune parked behind Mars's door.

Lessons that cost an hour each, now in CLAUDE.md/memory:
- Two `:=` parse errors masqueraded as an ENGINE HANG: compile cascade kills
  dependent tests, timeout-less harness loops spin, piped stdout buffers the
  errors into silence. `script -q` (pty) exposed it in one run.
- AnimatableBody3D sync_to_physics swallows code teleports (eggs at x 0).
- Never edit repo files while a pipeline runs; stage in scratchpad, install
  between runs with assert-on-every-replace scripts. Commit via -F heredoc -
  a quoted phrase inside -m truncated a message and killed a pipeline.
- Boss balance rule that emerged: cap damage per vulnerable window (worm 2,
  janitor 3, tripod 3) or a fast mash empties a boss in one opening.

Late additions (after the first wrap-up, same day):
- The user's painted Mars sky wired via ParallaxBackdrop (z -9.5, gentle
  follow); boxy procedural hills/volcano/moons/stars retired; draws 117 -> 114.
- user_added_images/ was shipping ~5 MB of never-loaded source art inside the
  wasm; added to the export exclude list (zero runtime references, verified).

Unfinished / needs the user:
- Roof through Mars: harness-only, no human has played them.
- STABLE is still the 7-level build; promote on the user's word.
- Zero-hearts (#5) still needs a live reproduction.

## 2026-08-22 / 23 — the game gets an ending, and four tests that lied

Two days driven entirely by play reports. Every report was real; three of my own
diagnoses were not, which is the part worth keeping.

**THE GAME HAD NO ENDING.** "The exit opens after defeating cat but then we cant
go through" was not the exit. The tabletop is the last level, `next_scene` is
empty, and walking in called `complete_level()` — a signal with NO LISTENER —
and showed a message with duration 0.0, i.e. forever. Finishing the game was
indistinguishable from a broken door. There is an ending screen now.

**Completability, end to end.** `tests/support/level_completable.gd` plus one
test per level: beat the boss with real button presses, WALK to the exit, wait
for the next scene. All six pass. Verified by restoring the two bugs that
shipped (Queen on `collision_layer = 0`, cat's paw with her): both went "6 -> 6
health in 90s".

**Four tests of mine passed for the wrong reason.** This is the theme.
- The tabletop's last assertion was "the last level completes rather than
  chaining on" — it passed on a flag it had already checked and asked nothing.
  Under it, the game had no ending at all.
- `perf_budget_test` read `user://save.cfg`, so it measured whatever had last
  been played. On this machine that was 0 or 1 banked babies, and it never saw
  the state a real player is in.
- `landmarks_clear_test` waved through a crate planted squarely on a checkpoint.
  Only found because I planted one to check the test bit, and it did not.
- `spider_queen_webs_reachable_test` passed in every configuration, so its
  "fix" proved nothing.
Deliberately breaking a test is the only thing that caught any of these.

**Babies were the "glitchy" report.** Not the sharing — Pages is static files.
Every banked baby follows you into every level wearing the FULL PLAYER MODEL at
0.4 scale: 21 meshes each, glints 8 mm across. They cluster on the player, where
the camera is. Eight took the tabletop from 6.19 draws/m to 11.94 against a 6.5
ceiling, so the game got heavier the better you played. A dedicated 5-draw baby
visual fixed it; `baby_cost_test` guards the margin.

**Boss summons audited.** The cat's nine ants dropped at the boss's position and
the cat sits at z -6, so every one landed six metres behind the play plane,
unable to reach him or be reached. Same trap the food burst fell into a few
lines above in the same file.

**Nothing taught any boss rule.** Four of six cannot be worked out by playing.
Every boss now carries a `boss_rule`, shown on engage and again AT THE SWING
when a hit is shrugged — the cat's "NOT THERE!" and Granny's "SHE'S TOO BIG!"
were both anchored to the boss, 7.5 m up and 6 m back, where nobody was looking.
Then the combos test found `street_level.tscn` declaring `[node name="Hints"]`
TWICE: three hints in the file, ONE reaching the player, and the two dead ones
were the dash and the mantis's frontal guard. Dead the whole time, correctly
worded, at the correct position.

**Also:** Granny got a body, arms and a survival countdown, and stopped leaving
her hair behind (my regression — the fade collected MeshInstance3D and her curls
had just been batched into a MultiMesh). Her fruit and the cat's landed
unreachably at the boss; `spoils_origin()` puts spoils on the player's floor.
Food: ice cream cones, a tilted grape bunch, corn, watermelon. Three levels got
a foreground layer; `depth_layers_test` guards it. `smoke_test_3d` passes for
the first time in weeks.

**Two deploy channels**, answering "can we push a stable version to a URL":
`/` is stable, `/preview/` is the working build, one gh-pages branch. Preview is
the default; `--promote` copies the played preview to stable rather than
re-exporting. Promoted at end of day.

Decisions:
- Test hold durations are in REAL SECONDS. A frame-count hold is a fraction of a
  second headless: long enough to jump, nowhere near long enough to CLIMB.
- A boss's spoils anchor to the PLAYER's floor, never to the boss.
- Granny is a countdown, not a patience bar. The clock is the real rule.
- The webs came down 3.4 m -> 2.8 m as a FORGIVENESS change, not a lockout fix.
- A flaky test is worse than none: the spawn-to-boss traversal test was written
  and NOT shipped.

**Late additions, after the wrap-up was first written.** Checkpoints and exits:
`landmarks_clear_test` covers all 16 across six levels, all clear. It took FOUR
versions, and the wrong ones are the lesson: ignoring z flagged the drain's
background wall; measuring against the landmark's own z waved through a crate
planted squarely in the player's path, because checkpoint SIGNS sit forward at
z 1.4 while an EXIT sits at z 0; light-shaft beams are script-less children of
`LightShaft3D` and look exactly like decor.

The font (item 15) is FINE at 13 px, finally checked by rendering a level at the
export's real 1280x720 rather than reasoning about it. No change made.

That render turned up dead UI: CRUMBS / FRUIT / BABIES are written to on every
pickup and never shown. `git log -L` says 851ffc5 hid them deliberately when the
hints moved onto the HUD line, so it is leftovers rather than a bug — but the
player has no idea how many babies they are carrying, and the matrix is built on
that number. Logged, not changed.

Unfinished, and the user's calls:
- Zero hearts while still alive. Reported, NOT reproduced. `take_damage` is the
  only path that lowers health and it always dies at 0; shielded hits are the
  only half-damage path and remain the suspect. Needs level, shield, cause.
- Tabletop is 6.69 draws/m with 8 babies against a 6.5 ceiling. Trim its decor,
  cap followers, or raise the ceiling.
- The drain shaft dead-ends 0.15 m under a solid pipe at y 8.0. Raising it to
  ~8.6 would let a climber mantle out. Not a lockout: the pipes are the route.
- Nothing walks a level spawn-to-boss. Real coverage gap, test not shippable yet.
- Suite 39 -> 50, green.

## 2026-08-21 — the silence, four lockouts, and a lot of art

Longest session so far, driven entirely by play reports. Four separate things
made the game unfinishable, and every one of them passed the test suite.

**Audio, finally.** Runtime-created Music/SFX buses are SILENT in the web
export: context running, driver AudioWorklet, `plays` climbing, zero samples.
Works perfectly on desktop, which is what wrongly cleared them mid-hunt. Proven
by a control — a minimal 4.7.1 web export on the default bus is audible in the
same browser. Everything plays on Master now; muting is a gate in AudioManager.
Found by tapping `ctx.destination` with an AnalyserNode: peak output 0.

**Four lockouts, all invisible to a green suite:**
- Spider Queen on `collision_layer = 0` — unhittable by anything, ever.
- Granny made unbeatable BY ME: summons added at 70/50/20% health, and her
  health is patience that drains when she MISSES, so dodging well summoned ants
  into the one fight built on not being hit.
- Seven of ten checkpoints dead: trigger at z 1.2–1.4, play plane at z 0.
- Granny's pantry built at x 52 with the exit at x 53 — a 3 m cupboard parked
  on the doorway.

Every boss test poked bosses directly instead of playing the level. New
`granny_level_completable_test` dodges her, walks to the door under its own
power, and waits for the next scene to load.

**Content:** drain 51 m → 91 m with a new outfall opening; climber-wave
gauntlet; drain flush hazard; mega smash + backflip kick combos; poo bomb
(fullness-gated, on Z); slingshot replaces the rubber band; boss summons;
mantis nymphs; enemies shatter into their own meshes on death and bump off
Harry instead of standing inside him.

**Art:** cut nail, held-by-the-neck bottle, red perforated swatter, banded spray
can, low-poly spider with knees and eight eyes, Granny's sandal/curls/specs/
gritted teeth and a fade-out death with a pantry payoff, mantis wings + tibial
spines + roar, cat body/muzzle/brows/claws, hexagonal honey, wheat-sheaf crumbs,
signed EXIT doorways in every level.

**Audio content:** 45 recordings wired, level-up riff, Kettle Quest, enemy_die.

Decisions:
- Never reintroduce custom audio buses without testing the WEB build.
- Desktop passing proves nothing about web audio.
- Granny never summons; her verb is dodging.
- Bosses are pulled inside their arena before the gates drop.
- Arena colliders are FREED, not "disabled" — process_mode does not touch
  collision and `disabled` is refused mid-physics.

Unfinished:
- Cat level: user still could not finish it as of end of session. Exit signs
  shipped since; unverified.
- Summon audit outstanding on rat, cat, wasp, Queen — Granny proved the risk.
- Suite 32 → 38.

## 2026-08-15 / 16 — audit, then most of the backlog

Started with a repo audit (docs/implementation-audit.md) and a restructured BACKLOG,
then worked the recommended order. Everything below is committed, deployed and verified
on gh-pages.

Art: sewer retint to blue-grey with asphalt/concrete surfaces, baked AO and mipmaps on
all procedural textures; LightShaft3D god rays from manholes and storm drains; depth
layers (foreground silhouettes, midground pipework, MultiMesh rubble) after the user
said the level "still looks basic" — the diagnosis was that everything sat on one plane
in front of a painted backdrop.

Systems: boss-gated progression (BaseBoss3D + Level3D ExitState + arena walls); combat
readability (shared hit flash, damage tiers, blocked feedback); one shared HazardPool3D
with hurtbox matched to the visible pool (fixing a confirmed defect); versioned SaveGame;
audio buses with music/SFX toggles and a pause menu; baby companion reworked from
passenger to follower; rusty nail reskin with a readiness window; bottle-cap helmet with
durability; cause-specific death messages; hearts and wing shards as rewards.

Hollow Knight pass: most of the movement brief was ALREADY the shipped tuning. Added the
pogo, hit-stop, attack buffering, corner correction, the up attack, weapon identities,
and — the brief's sharpest note — benefits for being heavy, so food is a build choice
rather than a punishment. Then the lost-ghost recovery loop and checkpoints.

Content: Granny Level 1 (kitchen floor), the tabletop, and four bosses with four
different verbs — rat (when to hit), Granny (don't be hit), cat (what to hit), Spider
Queen (hit something else first).

Bugs worth remembering:
- Arena locking sealed the player OUT of an unfinished fight if he died inside it. No
  test caught it because every test killed the boss, never the player.
- A scripted str.replace failing silently shipped a feature that did nothing.
- A child's _ready runs before its parent's, so the Queen spun zero webs.

Unfinished: see CLAUDE.md "Immediate next steps". The headline is that none of it has
been played.


Append-only. Newest first.

## 2026-08-13

Done:
- Iron Dice Grit (user-supplied font, 3 weights: Regular/Bold/Black) integrated
  project-wide, replacing Godot's default font everywhere.
- Regular set as the project-wide default via `gui/theme/custom_font` in project.godot —
  no per-node edits needed for most labels.
- Black applied to the biggest display text: HUD `Message` popup (36px) and the
  `RotateLabel` phone-rotate overlay (30px).
- Bold applied to mid-tier emphasis: HUD stat labels (Food/Fruit/Babies/Weapon/Shield,
  "FLYING POWER") and the title screen's "press SPACE / tap to start" prompt.
- Left Regular (default) on deliberately quiet text: title screen's "early prototype"
  version tag, HUD debug overlay.
- Only the weights actually used got copied into new `ui/fonts/`; raw kit stays in its own
  staging folder (`iron-dice-font /`, trailing space in the name) — excluded from the web
  export via a new `export_presets.cfg` exclude_filter, since `export_filter=all_resources`
  would otherwise have shipped unused Bold/otf/woff2 duplicates + README/specimen files.
- Verified via reimport + a scratchpad headless script (scene-load + font-load checks)
  after each font addition, per existing convention.
- Exported web build and deployed to gh-pages; verified via `git ls-remote` per the
  existing push-verification rule.

Decisions:
- Font weight hierarchy (Black/Bold/Regular by text role, not by a single flat weight or
  Black-everywhere) — user's explicit call; see CLAUDE.md Key decisions.
- Raw font kit kept as unwired staging, mirroring the existing `user_added_images/` → `art/`
  pattern, rather than deleting it or pointing resources straight at it.

Unfinished / carry-over:
- New fonts only headless-verified (scene/font resource loads) — never eyeballed in an
  actual browser for kerning/legibility at real HUD sizes.
- Session briefly started in the wrong repo (a different project's Claude session, pointed
  at Juan Coleman Website) before being redirected here — no impact on this repo, flagging
  in case it recurs.

## 2026-08-10

Done:
- Godot 4.7.1 installed locally (official GitHub release + quarantine-clear) — wasn't on
  this Mac before; now at `~/Applications/Godot.app`. Enables real headless verification
  (--import, smoke tests, exports) instead of static code review only.
- Weapons system shipped: pin (drain), fork/knife (kitchen), bottle-cap shield (street) —
  pickup auto-equips, N/M cycles collected weapons, per-weapon damage/cooldown/reach,
  shield halves damage (hearts bar now renders true split half-hearts).
- Weapons round 2: shared `WeaponVisuals` builder so held/ground meshes match exactly
  (bigger, angled 45° forward); bottle cap reworked as a TorusMesh halo; new pan shield
  (kitchen, held in front, same effect as the cap); broken-bottle weapon (drain); attack
  swing animation on the held prop; weapons/shields now respawn (~14s); baby eggs added
  to street + kitchen (previously drain-only).
- Rat boss now drops a crown on death → "THE KING OF COCKROACHES" achievement banner.
- Level 4 (the counter) shipped: kitchen now chains onward instead of ending the run;
  Granny hazard (fly-swatter slam + insecticide cloud, both telegraphed, target the
  player's current position) as a level-scoped non-boss threat per GAME.md §11;
  sugar-bowl finale carries the old "Phase 1 complete" message.
- Fixed a real placement bug: Pin1/Pan1 sat just outside jump-free reach — worked out the
  actual geometry (player collision height vs pickup radius vs floor height), cross-
  checked against known-good crumb placements, fixed both.
- Every round: reimport clean, `smoke_test_3d.gd` passes, plus one-off headless check
  scripts (scratchpad, not committed) that force-triggered new mechanics to confirm real
  effects, not just "does it load." Caught two compile-time-invisible bugs this way: a
  `GrannyHazard` type-inference error `--import` didn't catch (GDScript compiles function
  bodies lazily), and an unguarded `GameManager` reference in HUD that would've broken
  under the autoload-less test harness.
- Deployed to gh-pages 3x, each verified via a fresh clone (not just trusting script
  output), per the existing push-verification rule.

Decisions:
- Shield `kind` (cap vs pan) is cosmetic only — both halve damage the same way; kind just
  picks the mesh/position (halo above head vs held in front).
- Granny always targets the player's current position for both attacks, not a random
  arena spot — avoids needing ground-raycast logic for arbitrary placement.
- Weapons/shields are level-scoped and reset on death, matching the existing food/growth
  reset convention.

Unfinished / carry-over:
- Headless checks (climb/flight/death/rat/baby/title) still not rebuilt as committed
  `tests/` files.
- Kitchen's exit decor still visually reads as the old pantry-crack glow even though the
  text now says "onto the counter" (cosmetic mismatch, flagged not fixed).
- User's Meshy-generated cockroach GLB (10,366 tris, untextured, unrigged) inspected but
  not wired in — style-match and rig/animation decision still open.
- Level 4 verified headless only, not human-playtested — Granny frequency/telegraph
  fairness and obstacle difficulty need a real pass.

## 2026-08-09

Done:
- Backlog spec round (from user's cockroach-game-update-backlog.md):
  - Fixed spider legs invisible (parented to body root instead of hip pivots).
  - Fixed z-fighting flicker (glow windows/skirting intersected wall faces).
  - Rat boss hardening: void snap-back, mirrored rear-up telegraph when facing left.
  - Enemy ledge avoidance: spiders/ants raycast ahead, turn at edges, won't chase off ledges.
- Hollow-Knight combat feel: white slash arc on attack, Q bound as attack key,
  POW/CRACK/BONK popup text + spark bursts + camera shake on confirmed hits only,
  enemy health bars (green→orange→red), death ghosts on all enemy deaths.
- Dark/arty pass (kage-inspired): vignette shader, darker envs + thicker fog,
  drifting motes per level, street moon, environment glow/bloom on emissives.
- User art integrated: painted drain backdrop on parallax quad (ParallaxBackdrop);
  title screen with COCKROACH COLONISATION / A COLECLAN GAME artwork.
- User music integrated (MP3, looped): Lanterns In The Drain (drain), Burrow Lantern
  (street), Mire King Shuffle (kitchen); generated WAV music removed, SFX wavs kept.
- Rat boss crowned (gold band + ruby) per user: "crown = on the rat".
- Baby rescue: drain eggs hatch on approach, babies ride Harry's back, lost as ghosts
  on death, banked at level exit (GameManager.babies_banked persists across levels).
- Growth tradeoff: food fattens (crumbs +1u, fruit +2u) → bigger, slower, weaker jump,
  worse flight; stage messages; resets on death. Fruit split into own scorecard stat.
- HUD scorecard: hearts / CRUMBS / FRUIT / BABIES riding-vs-safe.
- Ops: repo briefly private (user action) → Pages auto-disabled → 404; user re-publicized,
  Pages re-enabled, site restored at original URL. Established push-verification rule
  (git push can silently fail while printing "Everything up-to-date"; verify ls-remote).
  Accidental build-files commit on main reset away. Final deploy (title+music) pushed
  and confirmed on gh-pages.

Decisions:
- Weapons system approved as next focused update; bottle-cap shield-bash prototype first.
- Babies bank at exit (not passive score). Growth/flight tension intentional.
- MengTo kage repo = mood reference only (Three.js, not portable to Godot).

Unfinished / carry-over:
- Headless check scripts (climb/flight/death/rat/baby/title) lost with session scratchpad —
  need recreating in tests/.
- Leftover repo droptop/cockroach-colonization-play — delete or repurpose (user call).
- Live-site CDN check for the final title+music deploy not re-run (push itself confirmed).
- docs/TODO.md contents consolidated into BACKLOG.md; TODO.md left as a pointer.

## 2026-08-08 (summary, backfilled)

- 3D pivot: drain/street/kitchen chained levels, toy-style Harry, procedural textures
  (speckle/grain/checker/brick + normal maps), wing flight + energy bar, wall climbing,
  respawning food, mobile touch controls, ants/flies/toxic drips, rat boss, procedural
  audio (SFX + 3 composed loops), sealed level bounds, delta-based deploy script.

## 2026-08-07 (summary, backfilled)

- Phase 1 2D prototype built, tested, pushed to github.com/droptop/cockroach-colonization,
  web-exported and published to GitHub Pages.

## 2026-08-17 — playtest bugs: three unhittable things, silent audio, wall text

First session driven by real play reports rather than the backlog. Three of them were
genuine shipped bugs, and one had been live for weeks.

**Unhittable destructibles (the big one).** "You can't cut the cords" was not tuning —
an `Area3D` does not report a `StaticBody3D` in `get_overlapping_bodies()`, and every
attack volume in the game is an Area. `WebAnchor3D`, `CatPaw3D` and `BreakableBlock3D`
were all StaticBody3D, so the Spider Queen and the cat could not be beaten by any means
and the weight-opens-routes mechanic did nothing. One-word fix each to
`AnimatableBody3D` (extends StaticBody3D, collides identically, visible to areas).
Nothing caught it because all four relevant suites drove damage by calling
`take_damage()` directly, which bypasses the attack volume entirely.

**All audio missing.** Not a regression: Escape was the ONLY binding for `pause`, and
browsers swallow Escape, so the pause menu — and the MUSIC/SOUND FX toggles inside it —
was unreachable in the shipped build. The setting persists in IndexedDB, so anyone who
switched audio off could never switch it back. Bound `P`. Verified in the live build
that X fires attacks (focus is fine) while Escape does nothing.

**Hints "in the wall".** Bare Label3D nodes, no backing, no wrapping — the Queen hint is
66 characters at font size 60 and ran past both screen edges. `HintBubble3D` wraps them
and puts a rounded panel behind; longest went from spanning the level to 3.4 m. Applied
by `Level3D` at load rather than rewriting six .tscn files, so hints stay editable
Label3D nodes. Added MESSAGES ON/OFF beside the audio toggles.

Also: split `thud` (16 call sites) and `squeak` (13) into 19 named hooks with distinct
placeholders, so the five bosses no longer share one hurt and one death sound, and a
recording drops in with no code change; deleted both dead names. Removed 2.5 MB of
orphaned music placeholder wavs. Added `Encounter` (no attacks from off-camera, max 2
attackers at once) — which found that flies had been spitting from off-screen since the
spoon landed. Straw and pebble finished the 9-weapon roster at 6 distinct verbs.

Decisions:
- Destructibles use `AnimatableBody3D`, not StaticBody3D. Non-negotiable now.
- Any action bound only to Escape is unreachable in the shipped build.
- `thud`/`squeak` deleted rather than kept as fallbacks — the export ships everything.
- Hint styling lives in one styler, not in six scenes.
- Generic invariant tests keep earning their keep: destructible-reachable, audio-registry
  (unregistered names play SILENTLY), orphaned-audio and input-map checks all added, all
  verified by breaking the thing on purpose and watching them fail.

Suite 30 → 32. Everything committed, deployed and verified against the served pck md5.

Unfinished / needs the user:
- Whether MUSIC/SOUND FX actually read OFF in their browser — the audio hunt ends there.
- 34 sounds to record or generate; prompts and foley list delivered as PDFs.
- Spider Queen, cat and breakable walls have still never been beaten by anyone.
