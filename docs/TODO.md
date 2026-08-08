# TODO

## CURRENT

- Playtest the 3D movement feel in all three levels; tune exported values.
- Design the pill bug buddy character (companion NPC — see ART_DIRECTION.md).

## NEXT

- Sound placeholder pass: footsteps, jump, bite, hurt, crumb pickup (audio_manager autoload when needed).
- Hit pause + attack impact particles (GAME.md §42 game feel).
- Spider wall/edge awareness so it doesn't walk off platforms while patrolling.

## LATER (Phase 2 — do not start until Phase 1 feels good)

- Five growth states + growth meter + collision size changes.
- Wing glide + wing energy.
- Checkpoints + save system.
- Ant + Beetle enemies, enemy config Resources.
- Kitchen test level with small-route/large-route choice.
- Web (HTML5) export preset — the game's stated target includes running on a website.

## DONE

- Phase 1 scaffold: project structure, input map, collision layers.
- Player controller: run, accel/decel, variable jump, coyote time, jump buffering,
  wall slide + wall jump, dash (one air dash), bite, damage/iframes/knockback,
  death + respawn, landing squash, facing flip.
- Spider: PATROL/CHASE/ATTACK/DEAD FSM, detection radius, telegraphed lunge,
  contact damage, health/death.
- Food crumb pickup + counter.
- HUD: health pips, crumb count, centre messages, pause, F3 debug overlay.
- Camera: smoothing, look-ahead, limits, shake hook.
- Test arena: tutorial run, jump platforms, pit, spider floor, wall-jump shaft,
  dash gap, pantry-crack exit, hints, death zone.
