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
- **Cross-session persistence** — a boss defeated before a reload is currently
  re-fought, because no save system exists. Blocked on the save/checkpoint item.
- Arena locking (walling the player into the fight) — `BaseBoss3D.arena_bounds()`
  exposes the bounds, but nothing consumes them yet.
- Post-boss reward/payoff beyond the rat's existing fruit-and-crown drop.

**Acceptance criteria**
- ~~A level's exit cannot trigger a scene change while its boss is alive.~~ done, tested
- ~~Touching the exit zone before boss defeat produces a readable "locked" response, not silence.~~ done
- ~~Defeating the boss emits one event that unlocks the exit, and unlocking is idempotent.~~ done, tested
- ~~Levels with no boss assigned still complete exactly as they do today.~~ done, tested
- A boss defeated in a previous session does not have to be re-fought after a reload.

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

- Enemy hit reactions: impact flash, particles, recoil on ant, fly and rat (spider already flashes).
- Player damage feedback: animation, sound, health change and a screen effect together.
- Brief invulnerability feedback after a hit (blink exists at `player/player_3d.gd:664` — make it read as protection, not a glitch).
- Visually distinguish blocked / weak / normal / powerful hits.
- Boss health readability — HUD-level bar for bosses, keeping the world-space `EnemyHealthBar` for normal enemies.
- Floating damage values, if they suit the toy style (optional — evaluate against the comic impact words already in use).
- Hit-pause (brief freeze frame) on confirmed hits — GAME.md §42.
- Spider death: short knock-up/recoil, body falls naturally, then a small stylised spider ghost floats up and fades. Playful, not graphic. `Fx.ghost` already does the float-and-fade.

**Acceptance criteria**
- Player can identify a confirmed hit without looking at the health bar.
- A blocked hit is visually distinct from an unblocked one.
- Every enemy reacts visibly when damaged, not only the spider.
- Boss health is legible without the player having to find the boss on screen.
- No added screen shake or flashing beyond current levels; nothing strobes.

---

# P1 — Weapons

*Reuse*: `WEAPON_STATS` (`player/player_3d.gd:80`), `items/weapon_visuals.gd`,
`items/weapons/weapon_pickup_3d.gd`. Do not add a second weapon architecture.

- **Rusty nail** as an equippable melee weapon: distinct attack animation and impact effect, ~0.5 s of communicated readiness/buff feedback that does not make controls feel unresponsive. *Open decision: reskin of the existing `pin`, or a fifth weapon alongside it — see audit.*
- Weapon attachment: nail visible in a front arm during walk, jump and attack, attached to the arm rather than floating. Currently a pivot on `$Visual` that flips with facing but is not bone-attached.
- Bipedal armed stance + fully rigged held-weapon animation (cut from the weapons round for scope). **Blocks true bone attachment above.**
- Contextual prompt: `X — BITE` unarmed, `X — HIT` armed, updating immediately on weapon change. The `weapon_changed` signal already fires; only the HUD label text is new.
- Pickup respawning: nail leaves the world immediately on collection, reappears only after a configurable delay, and never respawns twice at one spawn point. Base behaviour already exists in `weapon_pickup_3d.gd` (`respawn_seconds`, default 14).
- Carry duration: "at least five metres" — reconcile with the existing model, where weapons are level-scoped and reset on death/respawn rather than timed.

**Acceptance criteria**
- Nail remains attached to the front arm during walk, jump and attack.
- World nail disappears immediately after pickup.
- Nail appears in hand on the same frame it is collected — the respawn delay must not delay equipping.
- Nail cannot respawn twice at the same spawn point.
- Prompt reads `X — BITE` with no weapon and `X — HIT` with one, switching on the frame the weapon changes.

---

# P1 — Defensive equipment

*Reuse*: `collect_shield()` / `has_shield` / `shield_kind` (`player/player_3d.gd:528`).
Damage halving already works; do not add a new equipment system for durability.

- Bottle cap worn **on** the head as a helmet, attached to the head animation — not floating above it (current halo sits at `Vector3(0, 0.55, 0)`).
- Protects against suitable hazards: thorns, rocks, falling debris.
- Visible **and** audible feedback when it blocks damage.
- Durability: breaks or is removed when its protection is exhausted.

**Acceptance criteria**
- Cap follows the head through every animation state and never detaches visually.
- Blocking a hit produces distinct feedback from taking one.
- The cap visibly leaves the player when its durability is spent, and damage returns to full immediately after.

---

# P1 — Baby companion

*Reuse*: `items/babies/baby_roach_3d.gd`, `carry_baby()` / `bank_babies()`.
**Note the conflict**: babies currently *reparent onto the player and ride his back*,
and are freed at the exit. "Follows behind" and "survives transitions" both contradict
that. See open decision 2 in the audit before starting.

- Eggs redesigned with cracked openings at the top, stylised cracked-chicken-egg look; baby stays mostly inside until the hatch animation, never protruding through an unbroken shell.
- Baby follows behind the player at a readable trailing distance.
- Baby never blocks or overlaps the player.
- Catch-up behaviour when it falls too far behind.
- Stuck recovery: safe teleport if level geometry traps it permanently.
- Baby comes through every level transition with the player. **Depends on the save/persistence epic.**

**Acceptance criteria**
- Baby survives every current level transition.
- Baby never occupies the player's collision space.
- A baby stranded on unreachable geometry rejoins the player within a bounded time.
- The hatch animation never shows the baby through intact shell.

---

# P1 — Hazards

*Reuse*: `world/hazards/drip_emitter_3d.gd`. `GrannyHazard._start_spray()` builds a
near-duplicate cloud — unify rather than maintaining two.

- Acid drips animate from sewer pipes (exists), landing puddle **grows progressively** while dripping continues, with a capped maximum size.
- Visible puddle and damaging collision must match. **Confirmed defect**: `_spawn_puddle()` uses a `BoxShape3D` of `1.1 × 0.5 × 1.0` offset +0.2 Y, while the visible disc is a cylinder of radius 0.55–0.62 and height 0.09 — the hurtbox stands ~0.45 m above the visible acid and is square rather than round.
- Bubbling / sizzling / steam / glow feedback (smoke particles already exist).
- Puddle shrinks or is removed once the source stops.
- Reuse the same puddle/volume system for Granny's insecticide.

**Acceptance criteria**
- Acid cannot damage the player outside the visible puddle.
- Puddle growth is visible and stops at its cap.
- Granny's spray and acid puddles share one implementation.
- Decorative particles never carry collision.

---

# P1 — Level progression

*Reuse*: `Level3D` `next_scene` chaining, `world/props3d/pipe3d.gd`.

- Clearly visible exit pipe at the end of every level, with an arrow or animated indicator pointing into it.
- Player and baby can enter it; entry/crawl/descent animation plays; the next level triggers only after the transition begins.
- Exit cannot activate early while required objectives or combat remain unfinished (**this is the boss gate — see P0**).
- Sewer bowl / drain / pipe access point at the end of the pantry, visually connecting pantry or kitchen down to the sewer, leading to the correct sewer level.
- Reskin the kitchen's exit decor (still the old pantry-crack glow) to read as climbing onto the counter, matching its updated exit text.
- Checkpoints + versioned save system — GAME.md §43. **Blocks baby persistence and boss-completion persistence.** Minimal viable shape: current level, bosses defeated, babies banked.

**Acceptance criteria**
- Every exit leads to the correct next level.
- Boss exit cannot activate before boss completion.
- Progress survives a reload at checkpoint granularity.
- The arrow indicator is visible before the player reaches the pipe.

---

# P1 — Granny Level 1 (kitchen floor)

*Reuse*: `world/hazards/granny_hazard.gd` (telegraph + swatter + spray already exist),
`Level3D` decor helpers. Granny is currently invisible — only her swatter is drawn.

- Kitchen-floor environment: white tiled walls, worn wooden floor, cupboards, counters, skirting boards, floor-level obstacles.
- Granny peeks/rises from behind the counter, notices the cockroach, looks shocked.
- Short startled **"Eek!"** voice cue on notice, once per encounter unless it resets.
- Attacks from above: fly-swatter strike (exists), foot stomp (new), water splash (new), insecticide spray (exists).
- Every attack telegraphed; visible attack area and collision area must match; fair avoidance window and short recovery.
- Distinct impact feedback per attack.
- Insecticide audio: recognisable psst/aerosol sound synchronised with the visible spray, stopping or fading when spraying ends, and stopping on pause, death or scene change.
- If final audio is unavailable, add clearly named hooks with placeholders and report what is missing.

*Note*: GAME.md §11 defines Granny as an environmental catastrophe, **not** a boss.
Reconciling that with boss-gated progression is open decision 5 in the audit.

**Acceptance criteria**
- Granny's attacks are telegraphed and avoidable.
- Visible attack areas match collision areas for all four attacks.
- "Eek!" plays once per encounter.
- Spray audio stops on pause, death, and scene change.
- Granny audio respects the SFX toggle.

---

# P1 — Granny Level 2 (tabletop)

**Depends on**: boss base + exit gate (P0), combat feel (P1). This is the largest new
content item — schedule it last among P1.

- A second, distinct Granny level on a kitchen/dining table. **Not** the kitchen-floor layout with a new background.
- Run and fight between oversized tabletop objects: salt and pepper shakers, a flower vase, plus plates, cups, cutlery, napkins, crumbs, food containers and spills.
- Props serve as platforms, cover, obstacles, hazards, enemy hiding places and combat arenas.
- Dangerous table edges clearly communicated.
- Distinct route, scale and rhythm from the kitchen floor.
- Cat threat escalation: background eyes, paws, shadows, vibrations, objects knocked over — without obscuring gameplay information.
- **Big Boss Cat** at the end (see Boss Design Candidates).

**Acceptance criteria**
- The tabletop cat boss can be completed without collision or progression problems.
- The level's route cannot be completed using the kitchen-floor traversal pattern.
- Cat ambience never overlaps HUD-critical or hazard-critical screen space.
- Table edges read as lethal before the player falls off one.

---

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

*Reuse*: `autoload/audio_manager.gd` + the `Snd` facade. **Do not create a competing
audio system.** Everything currently plays on the default bus; there are no buses,
mute, volume, settings UI or persistence.

- Separate music on/off and SFX on/off controls with obvious current state, applied immediately.
- Muting music must not mute SFX, and vice versa.
- Controls in both the main menu and a pause/settings menu. **A pause menu does not exist** — pause is a bare `get_tree().paused` toggle plus a "PAUSED" label. The menu shell is a prerequisite.
- Keyboard, controller and existing touch navigation; accessible labels.
- Preferences saved locally and restored on reopen (separate from the game save — `ConfigFile` in `user://`).
- No duplicate music tracks when music is turned back on (`play_music()` already guards on `_current_track`).
- Preserve existing volume sliders if any are added later, while still providing mute.
- Named audio hooks for Granny's Eek/spray so the build never depends on missing final audio.

**Acceptance criteria**
- Music mute persists after restarting the game.
- Muting SFX leaves music playing and vice versa.
- Turning music back on resumes one track, not two.
- Every control is reachable by keyboard, controller and touch.

---

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
