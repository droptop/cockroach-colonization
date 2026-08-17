# WORKLOG

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
