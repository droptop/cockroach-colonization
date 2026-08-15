# Iron Dice Grit

An original heavy, modular poster display font designed for web-game headings and instructions. Its clipped rounded-square modules and deterministic edge damage create a gritty industrial rhythm without tracing an existing typeface.

## Recommended web setup

Copy the Regular, Bold, and Black WOFF2 files plus `iron-dice-grit.css` into your game's font/assets folder. Use `font-weight: 800` for Regular, `900` for Bold, and `950` for Black. Bold and Black use genuinely expanded strokes, tighter counters, and wider spacing—not scaled Regular outlines. WOFF2 is the preferred browser format; TTF is the fallback. OTF is included for desktop/design tools.

```html
<link rel="stylesheet" href="/assets/fonts/iron-dice-grit.css">
<p class="game-instructions">Choose three dice and roll.</p>
```

If your bundler fingerprints assets, import the WOFF2 from your app stylesheet and update the `url(...)` path. Keep body copy in a conventional sans-serif; this face is deliberately loud and works best for headings, prompts, buttons, scores, and short instructions.

## Coverage

ASCII A–Z, a–z, 0–9, common punctuation and brackets, currency and maths symbols, typographic quotes/dashes, and common Western European precomposed Latin characters. Lowercase uses compact small-cap construction to retain the poster voice at game UI sizes.

## License note

Created originally for the requesting user's projects. The user may use and modify the supplied files in their game and related materials.
