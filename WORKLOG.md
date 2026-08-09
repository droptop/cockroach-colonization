# WORKLOG

Append-only. Newest first.

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
