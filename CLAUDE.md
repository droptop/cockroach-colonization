# Cockroach Colonization

Read **GAME.md** (the full design + build brief) before making any architectural
decision. Record decisions in `docs/ARCHITECTURE.md`, track work in `docs/TODO.md`.

Current phase: **Phase 1 — movement prototype** (GAME.md §32). Do not build
Phase 2 systems (growth, wings, saves, more enemies) until movement feels great.

## Run

Open the project in Godot 4.x and press F5, or:

```bash
godot --path . 
```

Headless smoke test (loads main scene, runs 120 frames):

```bash
godot --headless --path . --quit-after 120
```
