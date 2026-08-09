# BACKLOG

Deferred work only. Done items get deleted, not archived (history lives in WORKLOG.md).

## Now

- Weapons system (approved): bottle-cap shield-bash first; then N/M inventory cycling, Q attack reuse, bipedal armed stance + held-weapon models, left-side weapon HUD, level pools (drain: caps/cans, street: bottles, kitchen: cutlery).
- Rebuild lost headless checks as committed files in `tests/`: climb, flight, death cycle, rat encounter, baby lifecycle, title screen advance (originals lived in the wiped scratchpad).
- Playtest tuning pass: rat boss difficulty (8hp/2dmg), fly dive fairness, drip density in drain, growth penalties feel.
- Decide fate of leftover public repo `droptop/cockroach-colonization-play` (created during the 404 incident, now redundant) — delete or keep as mirror.

## Next

- Street + kitchen painted backdrops (user supplies art → wire via ParallaxBackdrop).
- Pill bug buddy companion NPC (character ref exists — docs/ART_DIRECTION.md).
- Fruit variety (apple core, berry, grape) with distinct wing-energy values.
- Hit-pause (brief freeze frame) on confirmed hits — GAME.md §42.
- Checkpoints + versioned save system — GAME.md §43.
- Beetle enemy (armored, attack from behind) + enemy config as Resources.
- Comic impact text pooling if perf dips (currently allocates per hit).
- Baby eggs in street/kitchen levels (currently drain only).

## Later

- Discrete growth size states w/ collision-size changes + small-route gating (GAME.md §14/§17 — current fullness is continuous, collision unchanged).
- Boss trophy system + trophy loadout (GAME.md §7); colony hub + trophy room (§8/§23).
- Granny environmental hazard events (§11) + insecticide zones (§12).
- Three keys + Granny's secret + endings (§20–22).
- Additional levels: pantry, inside-the-walls, bathroom, basement, garden, sewer (§35).
- Scout + Brute playable characters (§3); metabolism/size-loss mechanic (§14).
- Real 3D assets: AI image→3D GLB generation, or Kenney/Quaternius CC0 packs into `art/`.
- Centipede enemy; spider web attacks.
- Co-op architecture work (§24) — keep avoiding player singletons meanwhile.
- Kage-style Three.js landing/marketing page for the game.
- Steam/controller polish, accessibility, localization scaffolding (§36).
- Mobile: real device testing of touch controls + landscape lock.
