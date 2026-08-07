# COCKROACH COLONIZATION
## Game Design + Technical Build Specification

**Working title:** Cockroach Colonization  
**Genre:** 2D action-platformer / exploration / light Metroidvania  
**Primary engine:** Godot 4.x  
**Language:** GDScript  
**Initial target:** Desktop  
**Future target:** Desktop + console + multiplayer

---

# 1. GAME VISION

**Cockroach Colonization** is a dark, funny, highly stylised 2D action-platformer about cockroaches surviving inside a gigantic human world.

The player explores kitchens, cupboards, walls, drains, gardens, basements and other oversized environments while avoiding predators, humans and environmental hazards.

The core twist is:

> **Eating makes you stronger, but getting bigger is not always better.**

Food can increase the player's strength, speed, health and abilities, but larger cockroaches may no longer fit through small cracks, vents and secret shortcuts.

The player must constantly choose between:

- staying small and agile;
- growing stronger;
- exploring hidden routes;
- fighting optional bosses;
- collecting food;
- finding upgrades;
- discovering secrets;
- progressing towards the colony.

The tone should combine:

- gothic;
- strange;
- darkly humorous;
- creepy;
- cute;
- exaggerated;
- slightly disgusting;
- adventurous.

The visual direction should be an **original hand-drawn gothic cartoon world**, influenced by the atmosphere of dark stop-motion fantasy and modern illustrated action-platformers, without directly copying any existing franchise.

---

# 2. CORE DESIGN PILLARS

The game should be built around five principles.

## 2.1 Movement feels excellent

The cockroach must feel responsive and enjoyable before anything else is added.

Movement includes:

- run;
- jump;
- variable-height jump;
- wall jump;
- wall cling/crawl where appropriate;
- dash;
- short wing flight/glide;
- drop through platforms;
- squeeze through small spaces;
- potentially ceiling crawling later.

## 2.2 Growth is a trade-off

Food causes Harry to grow through several size states.

### Size 1 — Tiny
Very agile.

Advantages:
- fits through tiny cracks;
- hidden routes;
- harder for enemies to hit;
- slightly higher agility.

Disadvantages:
- weakest attacks;
- low health;
- cannot move heavy objects.

### Size 2 — Small
Balanced exploration form.

### Size 3 — Normal
Standard balanced combat form.

### Size 4 — Large
Strong combat form.

Advantages:
- higher damage;
- more health;
- can push objects;
- can break certain weak obstacles.

Disadvantages:
- cannot enter small vents;
- bigger target.

### Size 5 — Ripped Roach
Temporary or difficult-to-maintain maximum state.

Advantages:
- maximum damage;
- access to high-level boss chambers;
- can move heavy environmental objects;
- can break certain barriers.

Disadvantages:
- cannot use many shortcuts;
- large hitbox;
- potentially slower turning or acceleration;
- food requirement to maintain state.

Exact values should be data-driven and easily adjustable.

---

# 3. PLAYER CHARACTERS

Eventually players choose between three cockroaches.

For Phase 1, implement **only one character**.

## Harry Cockroach

The initial protagonist.

Balanced character.

Suggested statistics:
- Medium speed
- Medium attack
- Medium health
- Medium growth rate
- Standard wings

Do not create direct Harry Potter references in dialogue, costume, artwork or story.

Harry Cockroach should become his own original character.

## Future Character 2 — Scout

Small, fast cockroach.

Advantages:
- faster;
- longer dash;
- fits through some routes at larger growth states;
- stronger climbing.

Weaknesses:
- lower health;
- lower melee damage.

## Future Character 3 — Brute

Large cockroach.

Advantages:
- high health;
- strong attacks;
- pushes objects;
- slower growth penalty.

Weaknesses:
- slower;
- larger;
- restricted from more shortcuts.

---

# 4. CORE GAMEPLAY LOOP

**Leave colony → explore → collect food → decide whether to grow → avoid hazards → fight insects/predators → discover secrets → defeat bosses → collect trophies/tools → return to colony → unlock new areas → repeat.**

Every level should create decisions rather than simply forcing the player to move from left to right.

---

# 5. BASIC PLAYER ACTIONS

Phase 1 player actions:

- Move left/right
- Jump
- Variable jump height
- Wall jump
- Dash
- Bite attack
- Take damage
- Die
- Respawn
- Collect food

Phase 2:

- Glide/fly
- Growth states
- Weapon/tool system
- Knockback
- environmental interaction

Later:

- crawl upside down;
- grappling;
- special trophy abilities;
- cooperative actions.

---

# 6. COMBAT

Combat should remain relatively simple.

The player should not need dozens of buttons.

Core attack:

## Bite

Short-range quick attack.

Can:
- damage enemies;
- knock back small enemies;
- potentially interact with some objects.

Later attacks are unlocked through boss trophies.

Combat should focus heavily on:
- positioning;
- dodging;
- timing;
- movement;
- enemy attack patterns.

Avoid turning the game into a stat-heavy RPG.

---

# 7. BOSS TROPHY SYSTEM

Bosses drop **physical body parts, shells, weapons or biological trophies**.

These are both collectibles and gameplay upgrades.

Boss rewards should ideally affect **both combat and exploration**.

This is one of the game's major progression systems.

## Example: Praying Mantis

Boss:

**The Mantis**

Reward:

### Mantis Shell

A piece of mantis armour.

Effect:
- increased defence;
- temporary blocking ability;
- visible cosmetic shell section.

Possible additional reward:

### Mantis Sickle

Allows:
- fast slash attack;
- cut hanging fibres;
- cut vegetation;
- sever webs;
- unlock previously inaccessible routes.

## Example: Spider Queen

Reward:

### Venom Fang

Allows:
- poison attack;
- damage-over-time;
- activate certain biological mechanisms.

## Example: Frog Boss

Reward:

### Frog Tongue

Allows:
- grapple across gaps;
- grab certain objects;
- pull food towards player;
- potentially pull light enemies.

## Trophy Loadout

Later versions should allow players to equip a limited number of boss trophies.

For example:
- 2 active trophies;
- several passive trophies.

This creates different builds without excessive complexity.

---

# 8. COLONY TROPHY ROOM

Boss trophies should physically appear inside the cockroach colony.

For example:
- mantis shells mounted on walls;
- spider fangs hanging from hooks;
- frog artefacts;
- human objects collected as treasure.

The colony therefore becomes a visual record of player progress.

---

# 9. ENEMIES

Enemy behaviour should be relatively readable.

Each enemy should have a small number of recognisable states.

Recommended architecture:

```text
IDLE
PATROL
ALERT
CHASE
ATTACK
STUN
DEAD
```

Use a finite-state-machine architecture.

Enemy configuration should be data-driven.

---

# 10. INITIAL ENEMIES

## Spider

Phase 1 enemy.

Behaviour:
- patrol;
- detect player;
- chase;
- short attack;
- return to patrol.

Later:
- wall climbing;
- web attack.

## Ant

Small swarm enemy.

Behaviour:
- weak individually;
- dangerous in groups;
- follows food.

## Beetle

Armoured enemy.

Requires attacking from behind or using stronger abilities.

## Centipede

Fast multi-stage enemy.

---

# 11. HUMAN HAZARD: GRANNY

Granny is not initially a traditional boss.

She is an unpredictable **environmental catastrophe**.

Occasionally the game signals:

> GRANNY IS COMING.

The player must react quickly.

Possible Granny attacks:
- fly swatter;
- insecticide spray;
- stomping;
- vacuum cleaner;
- moving furniture;
- closing cupboards;
- washing surfaces;
- turning lights on.

Her attacks should affect enemies as well as the player.

This can create emergent situations where Granny accidentally kills predators.

---

# 12. INSECTICIDE

Insecticide should create temporary hazardous zones.

Effects might include:
- poison damage;
- reduced visibility;
- forced movement;
- coughing/stagger effect;
- temporary routes becoming inaccessible.

The spray should visibly spread through the level.

---

# 13. FOOD

Food is both:
- score/resource;
- growth mechanic.

Examples:
- crumbs;
- cheese;
- sugar;
- bread;
- cake;
- fruit;
- grease;
- dropped sweets;
- pet food.

Rare food can give stronger temporary bonuses.

---

# 14. GROWTH SYSTEM

Food fills a growth meter.

When thresholds are reached, the cockroach moves to the next size state.

Each state changes:
- sprite size;
- collision shape;
- health;
- attack damage;
- movement;
- environmental access.

Important:

Growing must **never simply be an upgrade**.

Every growth level should create advantages and disadvantages.

The player should sometimes deliberately avoid food.

Later we may introduce ways to lose size again.

Possible mechanic:

### Metabolism

Growth gradually reduces if the player does not continue eating.

This needs testing before becoming permanent.

---

# 15. WINGS

Wings initially provide approximately:

**5 seconds maximum flight/glide energy.**

The wing meter regenerates when grounded.

Wing upgrades could increase:
- flight time;
- horizontal control;
- vertical lift;
- regeneration.

Growth may affect flight efficiency.

A huge cockroach should not necessarily fly as efficiently as a small one.

---

# 16. LEVEL DESIGN

The human world should feel enormous from the cockroach's perspective.

Potential environments:
- kitchen;
- pantry;
- inside kitchen walls;
- cupboard;
- sink;
- pipes;
- basement;
- restaurant;
- garden;
- sewer;
- bathroom;
- attic;
- rubbish area;
- greenhouse;
- garage.

---

# 17. LEVEL ROUTES

Levels should contain multiple routes.

### Small Route

Crack behind kitchen cabinet.

Requires:
- small body.

Advantages:
- faster;
- fewer enemies.

Potential rewards:
- secrets;
- rare food.

### Large Route

Main kitchen floor.

Requires:
- combat.

Advantages:
- large food rewards;
- boss access.

This creates meaningful decisions around growth.

---

# 18. BOSS CHAMBERS

Some optional boss rooms require particular conditions.

Example:

A player discovers the entrance to the Mantis Den.

Requirement:
- Size 4+
OR
- particular trophy combination.

The player may see the room earlier but be unable to survive it.

This encourages returning later.

---

# 19. SECRET SYSTEM

Exploration should contain meaningful secrets.

Secret types:
- breakable walls;
- hidden vents;
- tiny cracks;
- ceiling routes;
- environmental puzzles;
- trophy-specific routes;
- optional boss chambers.

Secrets should contain more than ordinary currency.

Possible rewards:
- lore;
- food;
- trophies;
- cosmetics;
- keys;
- alternate endings.

---

# 20. THE THREE KEYS

Three extremely well-hidden keys exist throughout the game.

### Key I
Found through exploration.

### Key II
Obtained from an optional boss.

### Key III
Requires using several boss abilities together.

Finding all three unlocks:

**Granny's Secret.**

---

# 21. GRANNY'S SECRET

Behind a hidden locked area belonging to Granny is something that changes the player's understanding of the game.

The exact story should remain undecided during early development.

Possible directions:
- Granny knows the colony exists;
- Granny has deliberately been studying the insects;
- something much more dangerous lives beneath the house;
- Granny was protecting the house from another infestation;
- Granny has a secret insect laboratory;
- another colony existed previously;
- the humans are preparing to demolish the house;
- Granny isn't the true enemy.

Do not lock the story yet.

Build the technical ability to support alternate endings without committing to one.

---

# 22. ENDINGS

## Standard Ending

Player completes the main campaign.

The colony successfully expands.

## Secret Ending

Requires all three keys.

Unlocks Granny's secret area.

Reveals additional story and potentially a different final sequence.

---

# 23. COCKROACH COLONY

The colony acts as the player's hub.

It should evolve as the player progresses.

Initially:
- small nest;
- few cockroaches;
- basic food storage.

Later:
- larger tunnels;
- trophy room;
- armour room;
- training area;
- new characters;
- additional exits.

This provides visible progression.

---

# 24. CO-OP

Co-op is **NOT part of the initial MVP**.

Architect systems so multiplayer can be added later without rewriting everything.

Future target:

**2–4 player cooperative play.**

Players control individual cockroaches.

Potential mechanics:
- revive friends;
- share food;
- distract predators;
- cooperative switches;
- different character roles;
- carry heavy food together;
- boss fights;
- race through vents.

Example:

One player distracts Granny while another steals food.

---

# 25. ART DIRECTION

Visual direction:

**2D illustrated gothic cartoon.**

Characteristics:
- thick expressive silhouettes;
- exaggerated insect anatomy;
- dark backgrounds;
- oversized human objects;
- crooked architecture;
- dramatic shadows;
- expressive eyes;
- slightly disgusting food;
- comical movement;
- playful horror.

The game should feel creepy without being genuinely frightening.

The cockroaches should become strangely likeable.

---

# 26. SCALE

Everything should emphasise how tiny the player is.

Examples:

A spoon = enormous metallic structure.

A kitchen sink = dangerous waterfall.

A cereal box = building.

A cupboard = dungeon.

A floor gap = canyon.

A vacuum cleaner = enormous monster/event.

A human foot = devastating environmental hazard.

---

# 27. AUDIO DIRECTION

Sound should combine:
- creepy;
- funny;
- tactile;
- crunchy;
- oversized household sounds.

Examples:
- exaggerated footsteps;
- shell clicking;
- antenna movement;
- crumbs crunching;
- distant human footsteps;
- pipes;
- fridge hum;
- cupboard doors;
- insects;
- Granny shouting indistinctly.

Music should remain atmospheric during exploration and become energetic during combat.

---

# 28. TECHNICAL STACK

Use:
- Godot 4.x
- GDScript
- Git
- GitHub
- Godot Input Map
- CharacterBody2D
- TileMap / TileMapLayer
- AnimationPlayer
- AnimatedSprite2D
- Area2D
- Resource-based configuration
- signals for communication between systems

Avoid unnecessary plugins during the prototype.

---

# 29. PROJECT ARCHITECTURE

Suggested structure:

```text
res://

  autoload/
    game_manager.gd
    save_manager.gd
    audio_manager.gd

  player/
    player.tscn
    player.gd
    player_stats.gd
    player_combat.gd
    player_growth.gd

  enemies/
    base_enemy.gd

    spider/
      spider.tscn
      spider.gd

    mantis/
      mantis.tscn
      mantis.gd

  bosses/
    base_boss.gd

  items/
    food/
    trophies/
    keys/

  world/
    levels/
    props/
    hazards/

  ui/
    hud/
    menus/

  data/
    characters/
    enemies/
    trophies/

  art/
  audio/
  shaders/

  tests/
```

Do not over-engineer the first implementation.

---

# 30. CODE PRINCIPLES

1. Keep scripts relatively small.
2. Prefer composition over massive inheritance trees.
3. Use signals to communicate between independent systems.
4. Store tunable gameplay values outside hard-coded logic where practical.
5. Avoid premature abstractions.
6. Do not build systems until the current phase requires them.
7. Comment WHY something exists rather than commenting obvious code.
8. Avoid huge manager classes.
9. Every system must remain replaceable.
10. Prioritise player feel over architecture purity.

---

# 31. INPUT MAP

Create actions:

```text
move_left
move_right
jump
dash
attack
interact
glide
pause
```

Controller support should eventually map to the same actions.

---

# 32. PHASE 1 — MOVEMENT PROTOTYPE

## Goal

Determine whether controlling a cockroach is fun.

Do NOT attempt to build the complete game.

### Player

Implement:
- left/right movement;
- acceleration;
- deceleration;
- gravity;
- variable-height jump;
- coyote time;
- jump buffering;
- wall jump;
- dash;
- basic bite;
- damage;
- death;
- respawn.

### Test Arena

Create one placeholder level.

Include:
- floor;
- platforms;
- walls;
- vertical shaft;
- small gaps;
- dash gap;
- wall-jump section.

Use placeholder graphics.

### Spider

Implement one enemy.

Behaviour:

```text
PATROL
CHASE
ATTACK
DEAD
```

Spider should:
- patrol a defined area;
- detect player;
- chase;
- attack;
- receive damage;
- die.

### Food

Create one food pickup.

Collecting it increases a temporary food counter.

Do NOT implement full growth yet.

### HUD

Display:
- health;
- food count.

### Phase 1 Success Criteria

Before moving forward:
- movement feels responsive;
- jump feels good;
- dash feels good;
- player can fight spider;
- player can die and respawn;
- food can be collected;
- test level is playable from start to finish.

---

# 33. PHASE 2 — CORE GAMEPLAY

Add:
- five growth states;
- changing collision sizes;
- growth meter;
- growth trade-offs;
- wing glide;
- wing energy;
- more sophisticated damage;
- knockback;
- checkpoints;
- save system;
- enemy configuration resources;
- Ant enemy;
- Beetle enemy;
- small-route/large-route mechanic.

Create the first proper environment:

### Kitchen Test Level

Goal:

Reach the pantry.

Player encounters:
- food;
- spider;
- ants;
- human hazards;
- small shortcut;
- large combat route.

---

# 34. PHASE 3 — VERTICAL SLICE

The objective is to produce approximately **10–20 minutes of polished gameplay** demonstrating the full game concept.

Include:
- finalised movement feel;
- polished kitchen environment;
- food/growth choices;
- multiple routes;
- hidden rooms;
- colony hub;
- first boss;
- boss trophy;
- Granny hazard;
- environmental storytelling;
- music;
- sound;
- particles;
- screen shake;
- controller support.

## First Boss

Recommended:

### Praying Mantis

Boss should have approximately three major attacks.

Example:
1. Horizontal sickle slash
2. Jumping downward strike
3. Fast charge

Later phase:

Attack pattern becomes faster.

Boss reward:

**Mantis Shell / Mantis Sickle**

This should unlock a previously inaccessible route.

---

# 35. PHASE 4 — GAME PRODUCTION

Once the vertical slice proves the concept, expand the world.

Potential environments:
1. Kitchen
2. Pantry
3. Inside the Walls
4. Bathroom
5. Basement
6. Garden
7. Sewer
8. Granny's Secret Area

Add:
- additional bosses;
- additional trophies;
- colony expansion;
- secrets;
- three keys;
- NPC cockroaches;
- dialogue;
- quests;
- multiple characters;
- stronger enemy variety.

Begin multiplayer experiments only after the single-player architecture is stable.

---

# 36. PHASE 5 — CO-OP + POLISH + RELEASE

Add or complete:
- 2–4 player co-op;
- player joining/leaving;
- respawning;
- networking;
- synchronised enemies;
- synchronised bosses;
- shared/individual food decisions;
- co-op interactions.

Then focus on:
- accessibility;
- difficulty balancing;
- performance;
- controller support;
- Steam integration;
- achievements;
- cloud saves;
- localisation architecture;
- bug fixing;
- tutorial;
- options;
- credits;
- demo;
- release build.

---

# 37. MVP DEFINITION

The **first MVP should NOT attempt the whole game.**

The MVP is successful when we can play:

### One cockroach
Harry Cockroach.

### One environment
Kitchen.

### One enemy
Spider.

### One collectible
Food crumb.

### One attack
Bite.

### Core movement
Run, jump, wall jump and dash.

### One objective
Reach the pantry exit.

That is enough.

---

# 38. FIRST PLAYABLE SCENARIO

Create a level approximately 2–4 minutes long.

Sequence:

```text
START

Harry emerges from a crack in the wall.

↓
Tutorial movement section

↓
Jump across kitchen objects

↓
Collect food crumb

↓
Encounter spider

↓
Fight or avoid spider

↓
Wall-jump section

↓
Dash beneath dangerous object

↓
Cross kitchen floor

↓
Reach crack leading towards pantry

↓
LEVEL COMPLETE
```

---

# 39. PLACEHOLDER VISUALS

During Phase 1:

Do not spend significant development time on artwork.

Use:
- simple silhouettes;
- rectangles;
- basic sprites;
- temporary particles.

However, maintain correct approximate proportions so collision testing remains meaningful.

Harry should already have:
- body;
- six legs;
- antennae;
- obvious facing direction.

Animation can initially be procedural or minimal.

---

# 40. DEBUG TOOLS

Add a debug overlay toggle.

Display:
- FPS;
- player velocity;
- grounded state;
- wall state;
- current health;
- food;
- growth state;
- dash availability;
- wing energy.

Debug mode should be easy to disable.

---

# 41. CAMERA

Create responsive 2D camera.

Requirements:
- slight horizontal look-ahead;
- smooth follow;
- vertical smoothing;
- configurable limits;
- optional subtle shake.

Avoid excessive camera lag.

---

# 42. GAME FEEL

Important polish features to introduce gradually:
- landing squash;
- tiny dust particles;
- hit pause;
- knockback;
- attack impact particles;
- enemy flash;
- screen shake;
- subtle controller vibration;
- responsive animations.

Do not allow these effects to obscure gameplay.

---

# 43. SAVE DATA

Eventually save:

```text
character
current_area
checkpoint
health
growth_state
food
bosses_defeated
trophies_owned
trophies_equipped
keys_found
secrets_found
colony_progress
```

Use a versioned save format.

Saving is not required in Phase 1 except where trivially useful.

---

# 44. DATA-DRIVEN TROPHIES

Eventually define trophies as Godot Resources.

Example conceptual data:

```text
id
name
description
icon
boss_source
passive_effect
active_ability
damage_modifier
mobility_ability
requirements
```

This allows new boss rewards to be added without rewriting player code.

---

# 45. MULTIPLAYER ARCHITECTURE RULE

Do NOT build networking during Phase 1.

However:

Avoid assumptions such as:

```text
there is always exactly one player globally
```

Where practical, systems should interact with a player instance rather than reaching directly into a global singleton.

This will make later co-op easier.

---

# 46. OUT OF SCOPE FOR MVP

Do NOT build yet:

- online multiplayer;
- final artwork;
- enormous world;
- dialogue system;
- quests;
- three characters;
- three keys;
- alternate endings;
- complete trophy system;
- dozens of enemies;
- crafting;
- inventory management;
- procedural generation;
- monetisation;
- achievements;
- online accounts.

---

# 47. CLAUDE CODE WORKING RULES

When implementing this project:

1. Read this document before making architectural decisions.
2. Never jump ahead to another phase unless necessary for the current implementation.
3. Build small testable features.
4. Run the project after meaningful changes whenever possible.
5. Fix errors before adding new systems.
6. Do not replace functioning systems simply because another implementation is theoretically cleaner.
7. Record major architectural decisions in `docs/ARCHITECTURE.md`.
8. Maintain `docs/TODO.md` with `CURRENT`, `NEXT`, `LATER`, `DONE`.
9. If something is uncertain, choose the simplest implementation that allows later replacement.
10. Gameplay quality is more important than feature count.

---

# 48. FIRST CLAUDE CODE TASK

Begin with **Phase 1 only**.

Create a Godot 4.x project for:

# Cockroach Colonization

Build the initial playable prototype.

Implement:

1. project folder structure;
2. input map;
3. `Player` using `CharacterBody2D`;
4. left/right movement;
5. acceleration/deceleration;
6. jump;
7. coyote time;
8. jump buffering;
9. wall jump;
10. dash;
11. basic bite attack;
12. player health;
13. damage/death/respawn;
14. basic Spider enemy;
15. spider patrol;
16. spider player detection;
17. spider chase;
18. spider attack;
19. spider health/death;
20. food pickup;
21. simple HUD;
22. camera;
23. one small test level.

Use placeholder visuals.

Do not implement:
- growth;
- bosses;
- trophies;
- Granny;
- multiplayer;
- final artwork.

Prioritise the movement controller.

Expose relevant tuning variables through exported properties so movement can be quickly tuned inside Godot.

At completion, provide:

```text
1. Summary of files created
2. Scene structure
3. Input controls
4. Important tuning values
5. How to run the prototype
6. Known limitations
7. Recommended next three development tasks
```

Do not move automatically into Phase 2.

---

# 49. PRODUCT PRINCIPLE

When deciding whether to add a feature, ask:

> Does this make being a tiny cockroach in a gigantic dangerous house more fun?

If not, do not add it.

---

# 50. NORTH STAR

The ideal player experience is:

> "I can't believe I'm this invested in this stupid cockroach."

The game should generate funny stories naturally:

- becoming too fat to fit through a shortcut;
- escaping a frog by milliseconds;
- Granny accidentally swatting a boss;
- sacrificing food to remain small;
- discovering a crack nobody else noticed;
- collecting a grotesque boss trophy;
- flying across a kitchen only to run out of wing energy;
- finding one of the three mysterious keys;
- surviving together with friends.

**Small creature. Huge world. Bad decisions.**
