# Art direction notes

Reference sketches provided by the designer (2026-08-07) establish the look:

- **Ink-sketch on paper**: scratchy hand-drawn black ink linework on a warm
  cream/parchment background (#E8E2D3-ish), like concept art that came alive.
  Lines are energetic and slightly messy — stray hairs, spatter dots, rough
  ground-shadow strokes under every character.
- **Harry / friendly roaches**: near-black charcoal silhouettes with subtle
  blue-grey shell shading; segmented teardrop abdomen, spiky little leg tufts,
  two long antennae with bulbed tips. One reference shows a large round pale
  head with big black eyes (very "cute-creepy mask" energy) — a strong option
  for Harry's face, giving the expressive eyes GAME.md §25 asks for.
- **Enemies in red**: hostile insects (fly, beetle/tick, ant) use a dusty
  brick-red / rust body with the same black ink linework and hollow black eyes.
  Clean readable rule: **friendlies are black/grey, threats are red.**
- **Palette is minimal**: paper cream, ink black, shell blue-grey, threat red.
  Environments should stay in desaturated paper tones so characters pop.

Implementation implications (later phases, not now):

- The current placeholder `_draw()` visuals already use dark-body/red-eye
  contrast, consistent with this direction.
- When real art lands: sprite-based, thick silhouettes, paper-texture
  background layers, ink-spatter particles for hits/landings.
