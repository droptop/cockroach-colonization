# Art direction notes

## UPDATE 2026-08-08 — pivot to 3D

The designer chose a chunky low-poly 3D diorama style, referencing
"Platform Game Assets 3D" by Amin Bayat on ArtStation
(https://www.artstation.com/artwork/2xNDlB): bevelled toy-like blocks with a
contrasting top "lip", soft pastel lighting, cute rounded enemies, real depth.
The game is now rendered in 3D with gameplay locked to a side-scrolling plane.

Character references (provided 2026-08-08): toy-style chubby bugs with big
black glossy eyes, blush cheeks, segmented pill-bug shells. Harry uses a
rusty-red shell over a cream body (designer: white is fine for the reference,
change the colour for the actual cockroach). **The pill bug becomes Harry's
buddy** — a future friendly NPC/companion character.

Level environment palettes: drain = murky teal/moss + sickly green pipe glow;
street = navy night + warm lamp/window glow; kitchen = warm cream/wood morning
light. The older 2D ink-sketch notes below are kept for tone/history.

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
