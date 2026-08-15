# Implementation audit — pre-Phase-2

Audit date: 2026-08-15. Scope: everything in the repo at commit `328ae0b` plus the
uncommitted font wiring and this session's sewer art pass.

Purpose: know exactly what already exists before the boss-gated progression work
starts, so the next sessions extend systems instead of duplicating them.

---

## Existing systems

### Player — `player/player_3d.gd` (669 lines)
One self-contained `CharacterBody3D`. No player singleton (deliberate, for co-op later).
Every tunable is an `@export`. Holds:

- **Movement**: run accel/decel (ground + air), variable-height jump, coyote time,
  jump buffer, wall slide, wall climb, wall jump, dash with cooldown + one air dash.
- **Flight**: `wing_energy` (0–100) drains while flying, refills from food; any hit
  costs 18; running dry sets `_wings_spent` until refilled past a threshold.
- **Combat**: `_handle_attack()` reads `WEAPON_STATS[active_weapon]`
  (`player/player_3d.gd:80`) for damage/cooldown/reach, sweeps one shared `BiteArea`,
  spawns a slash crescent and a weapon swing tween.
- **Health/damage**: float `health` (max 5, half-hearts render), `take_damage()`
  (`:463`) applies shield halving, wing cost, knockback, 0.8 s invincibility, camera
  shake; `_die()` → tween flop + ghost + "AAHH!" + respawn after 2.2 s.
- **Growth**: continuous `fullness` 0–1 penalising run/jump/fly speed; visual girth only.
- **State hooks (duck-typed)**: `take_damage`, `apply_slow`, `collect_food`,
  `collect_fruit`, `add_wing_energy`, `carry_baby`, `collect_weapon`, `collect_shield`.

Legacy `player/player.gd` (2D, 250 lines) is still in the repo as reference only.

### Weapons — `items/weapon_visuals.gd`, `items/weapons/*`
- `WEAPON_STATS` const dict: `bite`, `pin`, `fork`, `knife`, `broken_bottle`.
- `collected_weapons: Array[String]`, cycled with N/M; pickup equips immediately.
- `WeaponVisuals.build_weapon(id)` is a static mesh builder shared by the ground
  pickup and the player's held prop, so the floor item and the held item are the
  same mesh at different scale.
- Held prop hangs off a pivot parented to `$Visual` — it flips with facing and
  follows the body, but there is **no rig and no bone attachment**.
- `weapon_pickup_3d.gd`: bobs, spins, respawns after `respawn_seconds` (default 14,
  `0` = never). Pickup hides + disables monitoring, then restores.
- Weapons are **level-scoped**: `_respawn()` resets `collected_weapons` to `["bite"]`.

### Equipment — `items/weapons/shield_pickup_3d.gd`
`collect_shield(kind)` sets `has_shield` + `shield_kind` (`"cap"` / `"pan"`).
Both halve damage identically; the kind is cosmetic. **No durability, no break state,
no block feedback.** The bottle cap renders as a halo *floating above* the head
(`player/player_3d.gd:424`), which is exactly what the new requirements reject.

### Companions — `items/babies/baby_roach_3d.gd`
`Area3D` egg (smooth sphere, wobble) → on player contact hatches → `carry_baby()` →
`ride()` **reparents the baby onto the player** and pins it to his back. There is
**no follower AI at all** — babies ride, they do not trail. `bank_babies()` frees
every carried baby at the exit and adds to `GameManager.babies_banked`; dying loses
all carried babies. Nothing crosses a scene boundary except the banked integer.

### Enemies — `enemies/`
Four standalone `CharacterBody3D` FSMs, deliberately with no shared 3D base:

| Enemy | States | HP | Notes |
|---|---|---|---|
| Spider | PATROL/CHASE/ATTACK/DEAD | 3 | telegraphed lunge; **only enemy with a hit flash** |
| Ant | PATROL/CHASE/DEAD | 1 | swarm filler |
| Fly | HOVER/DIVE/RETURN/DEAD | 2 | dive-bombs, returns to perch |
| Rat | PACE/WINDUP/CHARGE/LEAP_WINDUP/LEAP/RECOVER/DEAD | 8 | charge + body slam |

All four attach a world-space `EnemyHealthBar` (`enemies/enemy_health_bar.gd`).
`enemies/base_enemy.gd` is a **2D** `CharacterBody2D` leftover — unused by any 3D enemy.
No praying mantis, no cat.

### Bosses
**There is no boss architecture.** The rat is a tanky enemy with a longer FSM, a
floating `EnemyHealthBar`, a `Label3D` reading "THE RAT", and a death sequence that
drops fruit + a crown (`items/trophies/crown_3d.gd` → `GameManager.unlock_achievement`).
There is no `base_boss.gd` (GAME.md's planned file tree lists one that was never
written), no arena lock, no phases, no boss-defeated signal, and no link between the
rat dying and the level exit.

### Hazards — `world/hazards/`
- `DripEmitter3D`: drop hangs (telegraph) → falls → on world contact spawns a burning
  puddle that ticks damage every 0.35 s for 5 s, then shrinks away.
- `GrannyHazard`: on a random 8–14 s interval, telegraphs then fires **one of two**
  attacks at the player's current position — fly-swatter slam (shadow grows, paddle
  drops, 3 damage in a 1.3 m radius) or an insecticide cloud (1 damage/s for 6 s plus
  `apply_slow(0.5)`). No Granny character is ever drawn; only the swatter appears.
  No stomp, no water, no vacuum, no "Eek", no dedicated audio.

### Levels — `world/levels/`
`drain → street → kitchen → counter`, chained by `next_scene` on each `.tscn` root.
`counter_level.tscn` has no `next_scene`, so it ends the run via
`GameManager.complete_level()`. `test_arena.tscn` is a legacy 2D scene. There is no
pantry level. Each level = `.tscn` geometry (`Block3D` static bodies) + instanced
pickups/enemies, with a `.gd` subclass building non-collidable decor in `_build_decor()`.

**Exit condition today is purely positional.** `Level3D._on_exit_zone_body_entered`
(`world/levels/level_3d.gd:52`) fires on the first player body entering `ExitZone` and
immediately banks babies and changes scene. There is no gate of any kind.

### Transitions
`get_tree().change_scene_to_file(next_scene)` after a 1.4 s message. Nothing persists:
the next level instantiates a fresh player at full health with `["bite"]` only.
`GameManager.babies_banked` is the sole piece of cross-level state.
**No checkpoints and no save system exist.**

### Audio — `autoload/audio_manager.gd` + `autoload/snd.gd`
Pooled one-shot SFX (10 players, 13 named clips), music with a 1.2 s fade-in and
duplicate-track guard, and a dedicated looping wing-buzz channel. Gameplay code always
goes through the static `Snd` facade so scripts still compile under the headless
`--script` harness (which has no autoloads).

**Gaps**: everything plays on the default bus — there are no Music/SFX buses, no mute,
no volume control, no settings UI, and no persistence.

### FX / feedback — `world/fx.gd`, `player/camera_3d.gd`
`Fx.impact_text` (comic word), `Fx.spark_burst`, `Fx.ghost` (used for both player death
and rat death). Camera `shake(strength)`. Player blinks during invincibility.
No hit-pause, no damage numbers, no per-hit-strength differentiation.

### UI — `ui/hud/`, `ui/title/`
HUD `CanvasLayer`: half-heart bar, crumb/fruit/baby/weapon/shield labels, wing dial,
centre message, F3 debug overlay, touch controls, rotate-phone overlay, vignette.
Pause is a bare `get_tree().paused` toggle plus a "PAUSED" label — **no pause menu, no
settings screen, no controller navigation**. Boss health is world-space only; the HUD
has no boss bar.

### Fonts — verified present locally
`ui/fonts/` holds three **real** files (not synthesised weights):

| File | Size | Use |
|---|---|---|
| `IronDiceGrit-Regular.ttf` | 56 796 B | project default via `gui/theme/custom_font` |
| `IronDiceGrit-Bold.ttf` | 55 512 B | HUD stat readouts, title CTA (per-Label overrides) |
| `IronDiceGrit-Black.ttf` | 55 404 B | popup Message, rotate overlay |

Staging kit `iron-dice-font /` (note the trailing space) holds otf/ttf/woff2 +
specimens and is excluded from the web build via `exclude_filter="iron-dice-font */*"`
in `export_presets.cfg`. Fonts are local `.ttf` imports — no external requests.
The migration is essentially done; only the visual/clipping check is outstanding.

### Rendering / performance
GL Compatibility renderer, `scaling_3d/scale=0.75`, **shadows off everywhere**
(shadow maps dropped software-GL browsers below 1 fps). One shadowless
`DirectionalLight3D` plus a handful of shadowless `OmniLight3D` per level. All
textures are procedural 128×128 greyscales generated at load and cached in
`Block3D._tex_cache`, tinted per surface, triplanar-tiled, with matching normal maps
and (as of this session) baked AO maps and mipmaps. Zero imported models, zero 4K
textures. `CPUParticles3D` for motes/sparks/smoke/spray. Export ships every resource
under the project root (`export_filter="all_resources"`), so new staging folders must
be added to `exclude_filter` or they bloat the build.

---

## Reuse matrix

| Feature | Existing system | Status | Recommendation |
|---|---|---|---|
| Boss-gated progression | none — `Level3D:52` exits on touch | **C — Missing** | Add exit state to `Level3D` + a `boss_defeated` signal contract. The single highest-value change. |
| Reusable boss base | none; rat FSM is bespoke | **C — Missing** | Add a thin `BaseBoss3D` (health, phases, arena bounds, `defeated` signal). Do **not** rewrite the rat's FSM into it — adopt it. |
| King Rat | `enemies/rat/rat_boss_3d.gd` | **B — Partial** | Keep the FSM; add the defeat signal, arena lock, and dodge/punish recovery window. |
| Boss health UI | `EnemyHealthBar` world-space | **B — Partial** | Reuse the bar for normal enemies; add a HUD boss bar for bosses only. |
| Rusty nail | `WEAPON_STATS` + `WeaponVisuals` + pickup | **B — Partial** | Add a `rusty_nail` entry + mesh + pickup scene. `pin` already occupies this niche — decide reskin vs. new (see open decisions). |
| Weapon attachment to arm | pivot parented to `$Visual` | **B — Partial** | Follows the body already but is not bone-attached; real attachment is blocked on the bipedal-stance/rig item. |
| Weapon pickup respawn | `weapon_pickup_3d.gd` | **A — Exists** | Already hides on pickup and respawns on a configurable timer. Only needs a double-respawn guard test. |
| Contextual X — BITE / X — HIT | `weapon_changed` signal + HUD label | **B — Partial** | Change the label text; the signal already fires on every weapon change. |
| Bottle-cap helmet | `collect_shield` + halo mesh | **B — Partial** | Reposition onto the head, add block feedback and durability. Damage halving already works. |
| Shield durability | none | **C — Missing** | Add a hit counter to the existing shield state — do not add a new equipment system. |
| Cracked eggs | `baby_roach_3d.gd` egg mesh | **B — Partial** | Visual-only change to the egg mesh + hatch tween. |
| Baby follower / trailing | `ride()` reparents to player | **D — Replace** | The ride-on-back design directly contradicts "follows behind". Genuine design conflict — see open decisions. |
| Baby survives transitions | `bank_babies()` frees them at the exit | **D — Replace** | Requires persistence, which requires the save/checkpoint item first. |
| Enemy hit reactions | only Spider has `_flash()` | **B — Partial** | Promote the spider's flash into a shared helper (`Fx` is the natural home) and call it from ant/fly/rat. |
| Player damage feedback | knockback + blink + shake + `hurt` SFX | **B — Partial** | Exists but is quiet; add a hit flash / vignette pulse. Do not add a parallel system. |
| Hit confirmation | `Fx.impact_text` + `spark_burst` | **A — Exists** | Already fires on every connected hit. Differentiate by damage tier. |
| Hit-pause | none | **C — Missing** | Already backlogged (GAME.md §42). |
| Acid drips | `DripEmitter3D` | **B — Partial** | Growth-over-time and the collision/visual mismatch are the work; the emitter itself is sound. |
| Poison / insecticide reuse | `GrannyHazard._start_spray()` builds its own cloud | **B — Partial** | Factor the puddle/cloud into one shared hazard volume rather than two near-duplicates. |
| Granny | `world/hazards/granny_hazard.gd` | **B — Partial** | Telegraph + swatter + spray exist. Reveal, "Eek", stomp, water, and a visible Granny are new. |
| Fly heart drops | rat drops fruit on death; no fly drop | **B — Partial** | Copy the rat's drop pattern into `fly_3d._die()`; needs a heart pickup scene. |
| Player death ghost | `Fx.ghost` + `_spawn_ghost()` | **A — Exists** | Ghost already floats up and fades. Only the height-scaling value is new. |
| Cause-specific death messages | `hud.gd` hardcodes "SQUISHED!" | **C — Missing** | Needs a damage-source tag threaded through `take_damage`. Small but touches every hazard call site. |
| Music/SFX toggles | `AudioManager`, no buses | **B — Partial** | Add two buses + mute flags to the **existing** manager. Do not build a second audio path. |
| Settings persistence | none | **C — Missing** | `ConfigFile` in `user://`. Independent of the game save. |
| Pause/settings menu | bare `tree.paused` toggle | **C — Missing** | Needed as the host for the audio toggles. |
| Save / checkpoints | none | **C — Missing** | Already backlogged. Blocks baby persistence and boss-completion persistence. |
| Exit pipes + arrows | `Pipe3D` decor + glow-box exits | **B — Partial** | `Pipe3D` exists; wire it as the exit marker and add the arrow indicator. |
| Level transition | `Level3D` `next_scene` | **A — Exists** | Reuse as-is; only add the gate in front of it. |
| Sewer light shafts | `LightShaft3D` (added this session) | **A — Exists** | Done for the drain; reuse for future sewer levels. |
| Iron Dice Grit migration | wired in `project.godot` + both scenes | **A — Exists** | Only the visual clipping check remains. |
| Tabletop level / cat boss | none | **C — Missing** | Entirely new; depends on the boss base landing first. |
| Praying mantis | none | **C — Missing** | Future; GAME.md §7 already designs its trophies. |

---

## Risks

1. **Boss gating changes every level's exit.** `Level3D._on_exit_zone_body_entered` is
   shared by all four levels and by `tests/smoke_test_3d.gd`. A default of "locked"
   would break the drain, street and counter levels, which have no boss. Default the
   gate to **unlocked** and let a level opt in.
2. **Baby persistence contradicts the current design.** `ride()` calls
   `reparent(player)`; `bank_babies()` calls `queue_free()`. Making babies survive a
   transition means unwinding both, plus the `babies_banked` scoring that the HUD and
   the level-complete message already read.
3. **Acid hurtbox is larger than the visible puddle** — confirmed, not suspected:
   `_spawn_puddle()` builds a `BoxShape3D` of `1.1 × 0.5 × 1.0` offset +0.2 in Y, while
   the visible disc is a cylinder of radius 0.55–0.62 and height 0.09. The hurtbox
   stands roughly 0.45 m above the visible acid and is square rather than round.
   Fixing this changes hazard difficulty in the drain and kitchen.
4. **The headless test harness has no autoloads.** Anything new that touches
   `GameManager`/`AudioManager` must go through `Snd` or `get_node_or_null`, or it
   breaks compilation for *every* dependent script under `--script`.
5. **GDScript compiles function bodies lazily.** A clean `--import` proves nothing
   about code inside a function. New systems need a scene that actually runs them.
6. **Damage-source tagging touches every call site.** `take_damage(amount, from_pos)`
   is duck-typed and called from the player, four enemies, drips, and Granny. Adding a
   third parameter must stay optional or every caller breaks at once.
7. **Export ships everything.** Any new asset staging folder needs an `exclude_filter`
   entry or it silently inflates the 40 MB web build.
8. **Additive transparency is the one real perf unknown** in the new sewer art. Three
   light-shaft cones with `DEPTH_DRAW_DISABLED` overdraw; budget a check on a
   software-GL browser before adding shafts to more levels.

---

## Dependencies

```
save/checkpoint system
   ├── baby persists across transitions
   └── boss-completion persists across sessions

boss gate on Level3D  ──┬── King Rat gate (kitchen)
   (needs BaseBoss3D)   ├── Granny encounter gate
                        └── cat boss gate (tabletop)

BaseBoss3D ── HUD boss health bar ── cat boss

pause/settings menu ── music + SFX toggles ── settings persistence
                                    └── Granny audio respecting the SFX toggle

shared hazard volume ──┬── acid puddle growth + collision parity
                       └── insecticide reuse

bipedal stance / rig ── true nail-to-arm attachment
damage-source tagging ── cause-specific death messages
```

**Do first, because other things wait on them:** save/checkpoint, `BaseBoss3D` + the
`Level3D` exit gate, the pause/settings menu shell.

---

## Recommended implementation order

1. **Exit-gate contract + `BaseBoss3D`** — `Level3D` gains
   `LOCKED → BOSS_ACTIVE → BOSS_DEFEATED → UNLOCKED → TRANSITION`, defaulting to
   unlocked so existing levels are untouched. Retrofit the rat as the first user.
2. **Combat readability** — shared enemy hit flash, damage tiers, HUD boss bar,
   stronger player-damage feedback. Cheap, self-contained, and makes every later boss
   testable by feel.
3. **Hazard volume unification** — one puddle/cloud implementation, collision matched
   to the visual, growth over time; reuse it for Granny's spray.
4. **Save/checkpoint** — minimal `ConfigFile` versioned save: current level, bosses
   defeated, babies banked. Unblocks baby persistence.
5. **Baby companion rework** — follower behaviour + transition persistence, once the
   ride-vs-follow decision is made.
6. **Weapons/equipment polish** — rusty nail, contextual prompt, helmet placement,
   block feedback, durability.
7. **Audio settings** — buses, toggles, pause menu, persistence.
8. **Granny Level 1 (kitchen floor)** — new environment + Granny reveal, using the
   gate and hazard systems from steps 1–3.
9. **Granny Level 2 (tabletop) + cat boss** — the largest new content, last, on top of
   everything above.

---

## Open design decisions

These genuinely need a human call — they are not answerable by reading the code.

1. **Rusty nail vs. existing pin.** `pin` already is a scavenged metal spike with a
   fast, low-damage jab. Is the rusty nail a *rename/reskin* of `pin`, or a fifth
   distinct weapon that sits alongside it? A fifth weapon makes the N/M cycle six
   items long.
2. **Baby: rides or follows?** The current design (rides on Harry's back, banked at
   the exit, lost on death) is a scoring mechanic. The new requirement (trails behind,
   catches up, survives transitions) is a companion mechanic. They can coexist —
   hatch → follow → optionally mount — but that is a design choice, not a refactor.
3. **Does banking still exist** if babies persist across levels? If a baby carries
   through to the end, what does `babies_banked` count and what does the scorecard say?
4. **Bosses for the drain and street.** The rule says every level ends in a boss.
   Kitchen has the rat; the tabletop gets the cat. The drain (Spider Queen) and the
   street currently have none — are those levels in scope for new bosses, or does the
   rule apply going forward only?
5. **Granny as boss vs. hazard.** GAME.md §11 is explicit that Granny is an
   environmental catastrophe, not a boss, and the current implementation follows that.
   The new rule wants every level to end in a boss. "Force her retreat" is the
   suggested reconciliation — confirm that Granny gets a *defeat condition* at all,
   or whether her levels are gated by something else (reaching the drain, surviving N
   attacks).
6. **Ghost-height progression.** No ghost-level or equivalent progression value exists
   anywhere in the project. Either it is invented (a new progression system) or the
   ghost rise is a flat configurable constant. Recommend the constant until a
   progression system exists.
7. **Damage readability format.** The request floated a pie chart over a bar. The HUD
   is currently text + half-hearts + a radial wing dial; a radial boss indicator would
   match the wing dial, a bar would match the enemy bars. Pick one.

---

## What has happened since (2026-08-16)

Steps 1–7 of the order below are **done and deployed**, plus content the audit only
sketched. The reuse matrix above is therefore a snapshot of the starting position, not
the current state — read it for the reasoning, read CLAUDE.md and BACKLOG.md for what
exists now.

Resolved from the open decisions:
- **(1) Rusty nail** — reskin of `pin`, not a sixth weapon. The brief itself asked to
  reuse rather than duplicate.
- **(2) Baby rides or follows** — follows. The brief asked for trailing, catch-up, stuck
  recovery and transition survival, none of which a passenger can do.
- **(4) Bosses for drain/street** — the drain got the Spider Queen. The street still has
  no concept.
- **(5) Granny as boss vs hazard** — she stays a catastrophe with a defeat *condition*
  rather than a health bar: her patience drains when she misses.
- **(6) Ghost-height progression** — not invented. Exposed as a configurable constant and
  flagged, as the brief instructed.

Still genuinely open: **(3)** what banking means now that babies follow, and **(7)** the
damage-readability format (bar vs radial vs pie).

## Verification status at audit time

- `godot --headless --path . --import` — clean; all global classes register.
- `tests/smoke_test_3d.gd` — **PASS** (Harry crosses both drain gaps, 5/5 health).
- `tests/smoke_test.gd` — legacy 2D, still present, not run as part of this audit.
- No linter or type checker is configured in this repo (no CI, no `gdlint` config);
  `--import` plus running a real scene is the only static check available.
