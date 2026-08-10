# BACKLOG

Deferred work only. Done items get deleted, not archived (history lives in WORKLOG.md).

## Now

- Rebuild lost headless checks as committed files in `tests/`: climb, flight, death cycle, rat encounter, baby lifecycle, title screen advance (originals lived in the wiped scratchpad; this session's new checks were scratchpad one-offs too, per convention).
- Playtest/balance pass: rat boss difficulty, fly dive fairness, drip density, growth penalties feel, weapon damage/cooldown feel (pin/fork/knife/broken bottle), shield half-damage feel, Granny attack frequency/telegraph fairness, level 4 obstacle platforming difficulty.
- Decide fate of leftover public repo `droptop/cockroach-colonization-play` — delete or keep as mirror.
- Reskin kitchen's exit decor (still shows the old pantry-crack glow) to read as climbing onto the counter, matching its updated exit text.

## Next

- Bipedal armed stance + fully rigged held-weapon animation (cut from the weapons-system round for scope — currently a procedural angled prop on the existing roach model, not a re-posed stance).
- Wire in user's Meshy-generated cockroach model (`Meshy_AI_Cuddly_Caterpillar_...glb` in Downloads — 10,366 tris, untextured, unrigged) as Harry's visual. Needs: a style-match call (flat-toy procedural look vs Meshy's smoother sculpt) and either an exported rig+animations or keeping it as a static swap (loses the current procedural squash/stretch animation).
- Street + kitchen painted backdrops (user supplies art → wire via ParallaxBackdrop).
- Pill bug buddy companion NPC (character ref exists — docs/ART_DIRECTION.md).
- Fruit variety (apple core, berry, grape) with distinct wing-energy values.
- Hit-pause (brief freeze frame) on confirmed hits — GAME.md §42.
- Checkpoints + versioned save system — GAME.md §43.
- Beetle enemy (armored, attack from behind) + enemy config as Resources.
- Comic impact text pooling if perf dips (currently allocates per hit).

## Later

- Discrete growth size states w/ collision-size changes + small-route gating (GAME.md §14/§17 — current fullness is continuous, collision unchanged).
- Boss trophy system + trophy loadout (GAME.md §7); colony hub + trophy room (§8/§23).
- Three keys + Granny's secret + endings (§20–22) — Granny's hazard mechanic now exists (level 4); the secret-area/ending narrative payoff is still undone.
- Additional levels beyond the counter: pantry, inside-the-walls, bathroom, basement, garden, sewer (§35).
- Scout + Brute playable characters (§3); metabolism/size-loss mechanic (§14).
- Centipede enemy; spider web attacks.
- Co-op architecture work (§24) — keep avoiding player singletons meanwhile.
- Kage-style Three.js landing/marketing page for the game.
- Steam/controller polish, accessibility, localization scaffolding (§36).
- Mobile: real device testing of touch controls + landscape lock.
