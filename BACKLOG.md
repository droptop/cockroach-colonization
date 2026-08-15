# BACKLOG

Deferred work only. Done items get deleted, not archived (history lives in WORKLOG.md).

Structured into epics after the 2026-08-15 audit — see
[docs/implementation-audit.md](docs/implementation-audit.md) for the architecture map,
the reuse matrix (what to extend vs. what to build), risks, and open design decisions.

**Before implementing anything below, read the audit's reuse matrix.** Most of these
items extend a system that already exists. Do not create parallel systems for weapons,
health, boss health, damage, audio, FX, level transitions, save state, companion
following, input, or UI.

---

# P0 — Core gameplay / progression

## Boss-Gated Progression (design rule)

**Every playable level must culminate in a Big Boss encounter. The next-level exit
stays locked until that boss is defeated.**

Each Big Boss must have its own identity, attack behaviour, arena logic, readable
weakness, defeat mechanic, boss-health presentation where appropriate, defeat
sequence, post-boss reward, and exit-unlock event.

Bosses must **not** be normal enemies with more health. *How* the player wins should
differ meaningfully between bosses — e.g. dodge and punish, environmental
manipulation, break armour, destroy anchors, bait attacks, timing counters, a specific
weapon, an arena hazard, surviving phases, or exposed weak points. Those are examples,
not a checklist; pick one identity per boss.

Boss defeat must integrate with the existing save/checkpoint/progression architecture
rather than inventing a second one.

*Status*: **the gate itself is built** (2026-08-15). `Level3D` now carries an
`ExitState` enum and a `boss_path` export; `enemies/base_boss_3d.gd` (`BaseBoss3D`)
supplies the `engaged` / `defeated` / `boss_health_changed` contract; the rat adopts it
(FSM untouched); the kitchen declares it; the HUD grows a boss bar on engage. Covered
by `tests/boss_gate_test.gd`.

*Still open*:
- Bosses for the drain, street and counter — those three levels declare no boss, so
  their exits are open, which is the deliberate no-regression default rather than the
  finished design. See open decision 4 in the audit.
- ~~Cross-session persistence~~ — done. `SaveGame` records defeats by `boss_id`;
  a level whose boss is already beaten removes it and starts UNLOCKED.
- Arena locking (walling the player into the fight) — `BaseBoss3D.arena_bounds()`
  exposes the bounds, but nothing consumes them yet.
- Post-boss reward/payoff beyond the rat's existing fruit-and-crown drop.

**Acceptance criteria**
- ~~A level's exit cannot trigger a scene change while its boss is alive.~~ done, tested
- ~~Touching the exit zone before boss defeat produces a readable "locked" response, not silence.~~ done
- ~~Defeating the boss emits one event that unlocks the exit, and unlocking is idempotent.~~ done, tested
- ~~Levels with no boss assigned still complete exactly as they do today.~~ done, tested
- ~~A boss defeated in a previous session does not have to be re-fought after a reload.~~ done 2026-08-15, tested

## Reusable level progression contract

Every level should conceptually follow
**EXPLORE → LEARN → ESCALATE → BOSS → REWARD → EXIT**, with exit state
**LOCKED → BOSS ACTIVE → BOSS DEFEATED → EXIT UNLOCKED → TRANSITION**.

This should eventually be a reusable system on `Level3D`, not custom logic copied into
each level script. Do not implement it speculatively — build it when the first two
bosses need it, so the abstraction is drawn from two real cases rather than one.

**Acceptance criteria**
- Exit state is one enum on `Level3D`, readable by the HUD and by tests.
- A level opts into gating by declaring its boss; levels that declare none default to unlocked.
- State transitions are one-way within a life and cannot skip a step.

## Damage readability (P0 slice)

Damage taken from the rat and other bosses is currently unreadable. The P0 slice is
only: *the player can always tell they were hit and by roughly how much*. Presentation
polish lives in the P1 combat-feel epic.

**Acceptance criteria**
- Every source of player damage produces a visible reaction within one frame of the hit.
- The player can identify a confirmed hit without looking at the health bar.

## Reliable exits

**Acceptance criteria**
- Every exit leads to the correct next level (drain→street→kitchen→counter, then onward).
- No level can be exited by clipping, falling, or re-entering the exit zone twice.
- `counter_level` either chains to a real next level or ends the run deliberately.

## Player / baby transition integrity

**Acceptance criteria**
- The baby survives every current level transition.
- Player state that is meant to carry (see save epic) carries; state that is meant to reset (weapons, growth) resets.

---

# P1 — Combat feel

*Reuse*: `world/fx.gd` (`Fx.impact_text`, `Fx.spark_burst`, `Fx.ghost`),
`player/camera_3d.gd` `shake()`, `enemies/enemy_health_bar.gd`. Only `Spider3D` has a
hit flash — promote it to a shared helper rather than writing three more.

*Landed 2026-08-15*: `Fx.hit_flash` (white overlay via `material_overlay`, so it
can't corrupt a creature's real materials) now fires on all four enemies — the
spider's old `_flash()` was only a scale pop, and ant/fly/rat had nothing at all.
`Fx.Tier` + `Fx.impact()` give blocked/weak/normal/heavy their own words, colours,
sizes and spark tints. Player emits `damaged(amount, blocked)`; the HUD pulses the
screen blue for a block and red for a hit that got through. Boss bar landed with the
P0 gate. Covered by `tests/combat_feedback_test.gd`.

Still open:

- Floating damage values, if they suit the toy style (optional — evaluate against the comic impact words, which may already do the job better).
- Hit-pause (brief freeze frame) on confirmed hits — GAME.md §42.
- Spider death: short knock-up/recoil, body falls naturally, then a small stylised spider ghost floats up and fades. Playful, not graphic. `Fx.ghost` already does the float-and-fade.
- Damage readability *format* decision — bar vs. radial vs. pie (audit open decision 7).
- Real audio for a blocked hit: currently a pitched-up `thud` placeholder.

**Acceptance criteria**
- ~~Player can identify a confirmed hit without looking at the health bar.~~ done
- ~~A blocked hit is visually distinct from an unblocked one.~~ done, tested
- ~~Every enemy reacts visibly when damaged, not only the spider.~~ done, tested
- ~~Boss health is legible without the player having to find the boss on screen.~~ done
- No added screen shake or flashing beyond current levels; nothing strobes. *(damage pulse peaks at alpha 0.22 over 0.33 s and cannot repeat inside the 0.8 s invulnerability window; invulnerability blink is now a short off-beat rather than a 50/50 strobe — still wants a human eye on it.)*

---

# P1 — Weapons

*Landed 2026-08-15.* **Decision taken: the nail is a reskin of `pin`, not a fifth
weapon.** `pin` was already a fast, low-damage scavenged metal spike, and the brief
itself says to reuse existing systems rather than duplicate mechanics. The cycle
stays five entries. Reversible — it is one `WEAPON_STATS` key and one pickup scene.

`rusty_nail` has a proper nail silhouette (flat struck head, tapered shaft), a
distinct **stab** rather than the sickle hook the other weapons swing (a spike that
arcs reads as a club), and a 0.5 s readiness window worth +1 damage that is purely
additive — it is usable on the frame it is picked up and never gated behind the
window. The contextual prompt reads `X - BITE` bare-mouthed and `X - HIT  <weapon>`
armed, with `*READY*` while the window is open. Covered by `tests/rusty_nail_test.gd`.

Still open:

- Bipedal armed stance + fully rigged held-weapon animation. **This is what blocks true bone attachment**: the weapon currently hangs off a pivot on `$Visual`, so it flips and moves with him and stays visible while walking, jumping and attacking, but it is not attached to an arm because there is no rig to attach it to.
- "Carry it for at least five metres" — not implemented as a distance rule. Weapons are level-scoped and reset on death, which is the existing model; a distance or duration limit would be a new mechanic, and it is not obvious it improves on the current one.
- Real audio for the nail's stab: still the shared `bite` sample.

**Acceptance criteria**
- Nail remains attached to the front arm during walk, jump and attack. *(Moves and flips with him and never detaches; genuine bone attachment waits on the rig.)*
- ~~World nail disappears immediately after pickup.~~ done, tested
- ~~Nail appears in hand on the same frame it is collected.~~ done, tested
- ~~Nail cannot respawn twice at the same spawn point.~~ done, tested — one node, hidden and restored
- ~~Prompt reads `X - BITE` with no weapon and `X - HIT` with one, switching on the frame the weapon changes.~~ done, tested

# P1 — Defensive equipment

*Landed 2026-08-15.* The cap is worn ON the head now — the roach visual's head
sits at local (0.24, 0.26) with radius 0.21, so the cap rests at 0.42 at the same
x, tilted, instead of hovering at (0, 0.55) like a halo. Shields gained durability
(`shield_durability`, default 3 blocked hits): each block knocks and flashes the
worn shield, and when it is spent it comes off and tumbles away rather than
quietly vanishing, so the player sees the protection leave. The HUD shows
condition (`SHIELD ##`) rather than mere presence. Covered by `tests/shield_test.gd`.

Still open:

- Protection is still universal halving rather than being keyed to thorns/rocks/falling debris specifically. The brief lists those as examples; making them special cases would mean a damage-type system that does not exist yet.
- Real audio for a block and a break: currently a pitched `thud` and a `splat`.
- Durability is not shown on the shield itself beyond the knock animation — dents or a crumple pass would read better than the HUD counter.

**Acceptance criteria**
- ~~Cap follows the head through every animation state and never detaches.~~ done — parented to the visual, so it flips and squashes with him
- ~~Blocking a hit produces distinct feedback from taking one.~~ done, tested — blue screen pulse, CLANG tier, knock on the shield
- ~~The cap visibly leaves the player when its durability is spent, and damage returns to full immediately after.~~ done, tested

# P1 — Baby companion

*Landed 2026-08-15.* **Decision taken: the baby follows, it no longer rides.** The
brief asks for trailing, catch-up, stuck recovery and transition survival in four
separate places, none of which a passenger can do. Reversible if that was wrong —
`ride()` was ~10 lines.

`items/babies/baby_follower_3d.gd` (`BabyFollower3D`) walks the breadcrumb trail
Harry actually left (`Player3D.trail_point`) rather than beelining at his current
position, so it rounds corners and drops off ledges the way he did. It is not a
physics body at all, which is how "never blocks or overlaps the player" is
guaranteed rather than tuned. Eggs are cracked open at the top with the baby down
inside, and the crown bursts off on hatch. Babies persist across levels by count —
respawned behind him on level start, since `change_scene_to_file` frees everything
regardless. Dying still costs him every follower. Covered by
`tests/baby_follower_test.gd`.

Fixed along the way: any teleport of the player (pit respawn, death respawn) now
clears the breadcrumb trail. Without that, babies walked back toward the hole he
had just fallen down.

Still open:

- Scoring model. `babies_banked` now means "currently following", and the HUD reads `BABIES n`. Whether rescues should also accumulate a lifetime total is a design call.
- Followers don't animate their legs while moving (they bob); the visual is the same procedural roach at 0.4 scale.
- No cap on how many can follow at once, and no queue behaviour when the line gets long.

**Acceptance criteria**
- ~~Baby survives every current level transition.~~ done, tested drain→street
- ~~Baby never occupies the player's collision space.~~ done — it has no collision; the test also tracks closest approach across a walk
- ~~A baby stranded on unreachable geometry rejoins the player within a bounded time.~~ done, tested
- ~~The hatch animation never shows the baby through intact shell.~~ done — the baby is only created after the shell bursts

# P1 — Hazards

*Reuse*: `world/hazards/drip_emitter_3d.gd`. `GrannyHazard._start_spray()` builds a
near-duplicate cloud — unify rather than maintaining two.

*Landed 2026-08-15*: `world/hazards/hazard_pool_3d.gd` (`HazardPool3D`) is now the
single volume behind both acid puddles and Granny's insecticide. Radius and height
are derived from the visible mesh in one function, so they cannot drift; spreading
and fading tween *through* that function rather than scaling the mesh. Drops landing
in an existing pool feed it (spread + reset its clock) instead of stacking a second
disc, capped at `max_radius`. Covered by `tests/hazard_parity_test.gd`, which samples
parity on every frame including mid-animation.

The confirmed defect is fixed: the old puddle had a `1.1 × 0.5 × 1.0` `BoxShape3D`
offset +0.2 Y behind a 0.09-tall disc of radius 0.55, so it damaged the player about
0.45 m above the acid and out to the box corners.

Still open:

- Richer bubbling / sizzling feedback — the pool carries drifting particles and an emissive glow, but no bubbles and no dedicated loop.
- Granny's spray renders as a translucent body rather than particles alone. Deliberate (whatever can hurt you has to show you), but it wants an eye on whether it reads as gas.
- Water hazard, falling/crushing objects — no implementation at all.

**Acceptance criteria**
- ~~Acid cannot damage the player outside the visible puddle.~~ done, tested every frame
- ~~Puddle growth is visible and stops at its cap.~~ done, tested
- ~~Granny's spray and acid puddles share one implementation.~~ done
- ~~Decorative particles never carry collision.~~ true by construction — particles are children of the volume and carry no shape

---

# P1 — Level progression

*Reuse*: `Level3D` `next_scene` chaining, `world/props3d/pipe3d.gd`.

- Clearly visible exit pipe at the end of every level, with an arrow or animated indicator pointing into it.
- Player and baby can enter it; entry/crawl/descent animation plays; the next level triggers only after the transition begins.
- Exit cannot activate early while required objectives or combat remain unfinished (**this is the boss gate — see P0**).
- Sewer bowl / drain / pipe access point at the end of the pantry, visually connecting pantry or kitchen down to the sewer, leading to the correct sewer level.
- Reskin the kitchen's exit decor (still the old pantry-crack glow) to read as climbing onto the counter, matching its updated exit text.
- Checkpoints + versioned save system — GAME.md §43. **Partly landed 2026-08-15**:
  `autoload/save_game.gd` (`SaveGame`) is a versioned `ConfigFile` in `user://`,
  static like `Snd` rather than an autoload so it works under the test harness.
  It persists boss defeats, furthest level, banked babies and achievements, and
  discards a save from another version rather than half-reading it. Covered by
  `tests/save_game_test.gd`.
  Still open:
    - **Mid-level checkpoints** — nothing yet; death still restarts at the level spawn.
    - **Resume flow** — `furthest_level()` is stored but nothing reads it. Whether the
      title screen auto-resumes, offers CONTINUE vs NEW GAME, or always starts at the
      drain is a design call, not a code one. Needs a menu either way.
    - **Baby persistence across transitions** — still blocked, on the rides-vs-follows
      decision rather than on the save layer.
    - A player-facing way to wipe the save (new game).

**Acceptance criteria**
- Every exit leads to the correct next level.
- Boss exit cannot activate before boss completion.
- Progress survives a reload at checkpoint granularity.
- The arrow indicator is visible before the player reaches the pipe.

---

# P1 — Granny Level 1 (kitchen floor)

*Landed 2026-08-15.* `world/levels/granny_kitchen_level.tscn` — white tiled walls,
worn plank floor, cupboard runs with kickboards and knobs, skirting, and a clutter
course of crates, a tin, a cookbook and a stool to climb. Chained after the counter,
which previously dead-ended.

**Open decision 5 resolved: Granny gets a defeat condition, but not a health bar.**
`GrannyBoss3D` is `immune_to_damage` — nothing Harry carries can touch her, and
swinging at her says SHE'S TOO BIG! so the player learns that fast. What drains is
her *patience*, and it only drains when she **misses**. You beat Granny by not being
hit, which is the exact inverse of the rat (beaten by landing hits in his recovery
window). She rises from behind the counter, is visibly shocked, shrieks once, then
cycles swat → stomp → water → spray on a fixed rotation so the encounter is
learnable. Beaten, she retreats rather than dying. Covered by
`tests/granny_encounter_test.gd`.

Attack areas match by construction: `_telegraph_and_strike` draws the disc and
resolves the hit from **one** radius value, so the warning and the damage cannot
disagree. Water leaves a slick (a `HazardPool3D` with zero damage and a slow), and
spray reuses the same pool with a sustained hiss tied to the cloud's lifetime.

Audio hooks are named and pointed at **placeholders** — the real recordings do not
exist. Missing, in priority order:
- `granny_eek` — currently `sfx_squeak.wav`. The one that most needs a real take.
- `granny_spray` — currently `sfx_sizzle.wav`, looped. Wants a real aerosol hiss.
- `granny_stomp` / `granny_swat` — currently both `sfx_thud.wav`, so they sound identical.
- `water_splash` — currently `sfx_splat.wav`.

Still open:

- She is a head, bun, glasses and shoulders — no arms, and the swatter/shoe arrive without a visible limb attached.
- Level ordering: this sits after the counter, so the chain is drain → street → kitchen → counter → granny kitchen. Your note said "kitchen → step one → second level", which may mean it belongs earlier; moving it is one `next_scene` edit either way.
- No cupboards open, nothing is bait-able yet — "bait Granny into damaging the environment" is not implemented; she simply misses.
- Difficulty is unplayed: 6 patience, 1.15 s telegraph, 2.6 s between attacks are guesses.

**Acceptance criteria**
- ~~Granny's attacks are telegraphed and avoidable.~~ done — every attack draws its circle first and waits `telegraph_time`
- ~~Visible attack areas match collision areas for all four attacks.~~ done, tested — one radius drives both
- ~~"Eek!" plays once per encounter.~~ done, tested
- ~~Spray audio stops on pause, death, and scene change.~~ done — the loop channel is PAUSABLE, and the pool stops it on fade and on `_exit_tree`
- ~~Granny audio respects the SFX toggle.~~ done — everything routes through the SFX bus

# P1 — Granny Level 2 (tabletop)

*Landed 2026-08-15.* `world/levels/tabletop_level.tscn` — plate, saucer, cup,
salt and pepper, cutlery, napkin and vase as platforms, with crumbs, sugar and a
tea ring as dressing. Chained after the Granny kitchen. Deliberately not the
floor layout reskinned: the route is a scramble up and across scattered objects
rather than a run along flat boards, and the danger comes from the **sides** —
the table ends are a death drop, banded in hazard stripes and called out by a
hint before he can find one the hard way.

**The Big Boss Cat has its own verb again.** `CatBoss3D` is `immune_to_damage`;
what can be hurt is the **paw** it leaves on the table after a swipe, and only
while that paw is down. `CatPaw3D` sits on the enemy layer so the player's normal
bite area finds it with no special casing, glows while it is vulnerable, and says
TOO FAST! when struck after it lifts. So the fight is: bait a swipe, be somewhere
you can reach the paw, punish it. That is three distinct boss verbs across three
bosses — *when* to hit (rat), *don't be hit* (Granny), *what* to hit (cat).
Covered by `tests/cat_boss_test.gd`.

Attacks cycle swipe → shake → swipe → pounce. The pounce has no weak point (pure
dodge) and the table-shake cannot be dodged at all — it damages and throws him —
so the swipe stays the only way in. Ambience: eyes tracking him from the dark
beyond the table, and a dusty paw print left earlier.

Still open:

- No knocked-over props yet; the shake jolts the camera and throws Harry, but nothing on the table actually moves or falls.
- The cat is a head — no visible foreleg connects it to the paw that lands.
- The pounce reuses a duplicate of the head mesh as the lunging shape, which is cheap but means the eyes lunge too.
- Difficulty unplayed: 6 health, 1.8 s paw window, 2.4 s between attacks are guesses.
- `burrow_lantern.mp3` is borrowed from the street; the tabletop has no music of its own.

**Acceptance criteria**
- ~~The tabletop cat boss can be completed without collision or progression problems.~~ done, tested
- ~~The level's route cannot be completed using the kitchen-floor traversal pattern.~~ done — the path climbs crockery and the flat runs are short
- Cat ambience never overlaps HUD-critical or hazard-critical screen space. *(Eyes sit far back at z=-10.5 and the print is on the table; never eyeballed on a real screen.)*
- ~~Table edges read as lethal before the player falls off one.~~ done — striped banding at both lips plus a hint at spawn

# P2 — Rewards

- Defeated flies drop small hearts or power rewards — hearts when restoring health, the existing energy visual when restoring another resource. *Reuse the rat's death-drop pattern (`rat_boss_3d.gd:_die()` spawns fruit + crown).*
- Rewards either move toward the player or are collected manually.
- Clear collection feedback; respect maximum health and energy limits.
- Fruit variety (apple core, berry, grape) with distinct wing-energy values.

**Acceptance criteria**
- Fly rewards are never granted silently.
- Collecting at max health/energy gives visible "no effect" feedback rather than nothing.

---

# P2 — Death presentation

*Reuse*: `Fx.ghost` and `player/player_3d.gd:_spawn_ghost()` — the float-up-and-fade
already exists.

- Cockroach ghost floats upward before fading or transitioning to the restart screen.
- If a ghost-level progression value exists, higher values rise higher; clamp so the ghost stays visible; keep the duration reasonable; guarantee a minimum rise at level zero. **No such progression value exists today** — expose a configurable constant and treat inventing one as a design decision (audit, decision 6).
- Spider ghost on spider death (see P1 combat feel).
- Cause-specific death messages: drop `SQUISHED!` as the generic (currently hardcoded in `ui/hud/hud.gd`). Reserve `SQUISHED` for Granny's foot, swatter or another crushing attack; `SPRAYED`/`POISONED` for insecticide; cause-appropriate messages for acid, enemies and falling.
  - *Implementation note*: needs a damage-source tag threaded through the duck-typed `take_damage(amount, from_position)`. Keep any new parameter optional — every enemy, drip and hazard calls it.

**Acceptance criteria**
- Death by crushing says SQUISHED; death by insecticide does not.
- The ghost is visible for its whole rise at every configured height.

---

# P2 — Audio / settings

*Landed 2026-08-15.* `AudioManager` now creates Music and SFX buses at runtime
(no `.tres` to drift out of sync) and routes the pool, music player and wing
channel onto them. Toggling mutes the bus rather than stopping the player, so
music resumes where it was and can never restart doubled. `autoload/settings.gd`
(`Settings`) persists both flags to `user://settings.cfg`, deliberately separate
from `SaveGame` — starting a new game must not turn the music back on. The pause
menu is built in code on first use and uses plain `Button`s, so Godot's own focus
navigation supplies keyboard and controller movement and touch gets tapping, with
no bespoke input handling to keep in sync. Covered by `tests/audio_settings_test.gd`.

Still open:

- Main-menu copy of the controls — they currently live only in the pause menu; the title screen is still "press any key".
- Volume sliders (mute only, for now). The brief says preserve sliders if present; there were none.
- Accessible labels beyond the visible ON/OFF text — no screen-reader story yet.
- Granny's Eek/spray hooks respecting the SFX toggle: they will, since everything routes through the SFX bus, but the sounds themselves don't exist yet.

**Acceptance criteria**
- ~~Music mute persists after restarting the game.~~ done, tested
- ~~Muting SFX leaves music playing and vice versa.~~ done, tested
- ~~Turning music back on resumes one track, not two.~~ done — muting a bus never stops the player, and `play_music()` already guards on `_current_track`
- Every control is reachable by keyboard, controller and touch. *(Buttons with Godot focus nav — mechanically correct and tested for state/immediacy, but never driven by an actual controller or finger.)*

# P2 — Typography

*Status: substantially done.* Iron Dice Grit is wired in `project.godot`
(`gui/theme/custom_font` → Regular) with Bold/Black as per-Label overrides in
`ui/hud/hud.tscn` and `ui/title/title_screen.tscn`. All three weights are real local
`.ttf` files in `ui/fonts/`, and the staging kit is excluded from the web build.

- Visually check legibility/kerning in the deployed build at all HUD sizes, especially the small 13–14 px labels — only headless (scene-load/font-load) verified so far, never eyeballed in a real browser.
- Adjust sizing, spacing, line height, buttons and containers to prevent clipping or overflow.
- Keep a readable sans-serif for long paragraphs / very small text if the grit face proves unreadable at size.
- Remove unused old font imports only after confirming they are no longer required.

**Acceptance criteria**
- Iron Dice Grit loads locally with no external requests.
- Bold and Black are the supplied font files, not synthesised weights.
- No text clips or overflows at 1280×720 or on a phone in landscape.

---

# P2 — Art / environment polish

*Sewer light shafts, grain/dust, and prominent drains/caps landed 2026-08-15* —
`world/props3d/light_shaft3d.gd` (`LightShaft3D`) plus `asphalt`/`concrete` surface
styles and baked AO in `Block3D`. Reuse `decor_light_shaft()` for future sewer levels
rather than writing new beam code.

- Windows may remain in street and above-ground levels; underground levels get their outside light from caps, drains and grates instead.
- Keep sewer covers, drains, pipes and access points visually prominent in every underground level.
- Maintain sufficient contrast between environment, player, enemies, weapons and hazards — the blue-grey sewer palette exists partly to keep green toxic hazards legible.
- Granny level art direction: white tile walls, wooden floor, sitting directly above the sewer.
- Street + kitchen painted backdrops (user supplies art → wire via `ParallaxBackdrop`).
- Wire in the user's Meshy-generated cockroach model as Harry's visual. Needs a style-match call (flat-toy procedural vs. Meshy's smoother sculpt) and either an exported rig+animations or a static swap (which loses the procedural squash/stretch).
- Pill bug buddy companion NPC (character ref exists — docs/ART_DIRECTION.md).

**Acceptance criteria**
- No underground level uses a window as a light source.
- Hazards remain distinguishable from the environment at every level's palette.

---

# P3 — Optimisation and polish

Preserve the current lightweight rendering strategy: GL Compatibility, shadows off,
0.75 3D scale, procedural cached textures, zero imported models. **Do not prematurely
optimise isolated systems without evidence of a problem.**

Principles to apply when adding anything new:

- Reuse materials and meshes; instance repeated objects.
- Favour tiling textures and trim sheets over unique art.
- Avoid unnecessary 4K textures, expensive transparency, excessive particles, and unnecessary real-time lights.
- Prefer a lightweight fake over a volumetric effect when the result is similar (the sewer light shafts are additive cones, not volumetric fog, for exactly this reason).
- Use normal/detail maps instead of extra geometry.
- Pool repeated effects where appropriate.
- Maintain browser and mobile performance.
- Keep gameplay collisions independent from decorative FX.

Open items:

- Comic impact text pooling if perf dips (currently allocates a `Label3D` per hit).
- Budget check on additive transparency: three light-shaft cones with depth-write disabled overdraw; measure on a software-GL browser before adding shafts to more levels.
- Rebuild lost headless checks as committed files in `tests/`: climb, flight, death cycle, rat encounter, baby lifecycle, title screen advance.
- Playtest/balance pass: rat boss difficulty, fly dive fairness, drip density, growth penalties, weapon damage/cooldown feel, shield half-damage feel, Granny attack frequency/telegraph fairness, counter-level platforming difficulty.
- Test desktop and mobile layouts; keyboard, controller and touch controls.
- Mobile: real device testing of touch controls + landscape lock.
- Steam/controller polish, accessibility, localisation scaffolding (GAME.md §36).
- Decide fate of the leftover public repo `droptop/cockroach-colonization-play` — delete or keep as mirror.

---

# Boss Design Candidates

Provisional concepts recorded as design direction. **Not approved for implementation.**

### Sewer / Drain — **Spider Queen**
Possible mechanic: destroy web anchors to expose the boss.
*Architecture note*: `Spider3D` exists with a PATROL/CHASE/ATTACK FSM to build from.
Destructible anchors are a new interaction type — nothing in the project currently has
destructible level geometry, so this needs the most new machinery of the four.

### Street — **King Rat**
Possible mechanic: dodge charge attacks and punish recovery windows.
*Architecture note*: **lowest-risk boss to do first.** `rat_boss_3d.gd` already has
`CHARGE` and a `RECOVER` state with a 0.9 s window — the punish mechanic is nearly
free. Note the rat currently lives in the **kitchen**, not the street; placing it in
the street means moving or duplicating it.

### Kitchen Floor — **Granny Encounter**
Granny stays a human-scale environmental threat, not a damage sponge. Possible victory:
bait her into damaging the environment, survive her attack sequence, or force a retreat.
*Architecture note*: conflicts with GAME.md §11 ("not initially a traditional boss")
and with the current `GrannyHazard`, which has no health, no defeat state and no
visible body. Needs open decision 5 resolved first.

### Tabletop — **Big Boss Cat**
Possible mechanics: bait paw attacks, use tabletop objects, strike exposed paws/nose
during recovery. Enormous relative to the cockroach — expressed through head, paws,
shadows and surrounding movement rather than a whole cat standing on the table.
Needs a dedicated boss health display, telegraphed paw swipes, pounce/head-lunge,
table-shaking attacks, fair collision and avoidance windows, recoverable attack
windows, strong hit feedback and a clear defeat sequence.
*Architecture note*: entirely new; depends on `BaseBoss3D` and the HUD boss bar.

### Future — **Praying Mantis**
Possible mechanic: frontal defence requires timing, dodging, or attacking exposed
angles. *Architecture note*: GAME.md §7 already designs its trophies (Mantis Shell /
Mantis Sickle), which assumes the boss trophy system below.

---

# Later (unscheduled)

- Boss trophy system + trophy loadout (GAME.md §7); colony hub + trophy room (§8/§23).
- Three keys + Granny's secret + endings (§20–22) — Granny's hazard mechanic exists; the secret-area/ending payoff does not.
- Discrete growth size states with collision-size changes + small-route gating (GAME.md §14/§17 — current fullness is continuous, collision unchanged).
- Additional levels beyond the counter: pantry, inside-the-walls, bathroom, basement, garden, deeper sewer (§35).
- Beetle enemy (armoured, attack from behind) + enemy config as Resources.
- Centipede enemy; spider web attacks.
- Scout + Brute playable characters (§3); metabolism/size-loss mechanic (§14).
- Co-op architecture work (§24) — keep avoiding player singletons meanwhile.
- Kage-style Three.js landing/marketing page for the game.
