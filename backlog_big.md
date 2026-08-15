Please add all this to the cockroach colonisation repo in the backlog.md 

Flow Summary
Solo design walkthrough of a bug/sewer game: art direction for sewer and granny levels, weapon and enemy behaviors, level transitions, and font exploration.

Art Direction & Environment

Granny level: white tile walls, wooden floor, sits atop the sewer; kitchen → step one → second level flow
Swap current AMD/runs/dumbhold font for a big fat font (e.g. Monster Rat Bold); explore Miniature, Impression Art, Modern Brush, jungle/trench options

Weapons, Enemies & Feedback
Rusty nail: pickup held by front cockpit arm, ~5m carry, different hit behavior, ~0.5s buff; delay reappearance after pickup
Spider death: float up as ghost and fall; acid drips form widening puddle over time
Cracked eggs at top (chicken-egg style); flies drop hearts, smack to steal power; rename to X bite or X hit
Damage taken from rat/boss hits is unreadable, needs clearer feedback

Progression & Player
End each level with a pipe + arrow pointing in as transition to next level; sewer bowl at end of pantry
Bottle cap worn as halo/helmet on head (not on cap) for thorn/rock protection; baby always follows behind
Death shows ghost floating up, higher float = higher ghost level; drop the squish-on-death, reserve squish for granny foot/water
Granny peeks from behind counter, looks shocked, then attacks with swatter or poison spray from above

Other:
Have abilty to toggle music off/on and also cound effect on/off




Please implement the following complete adjustment list for Cockroach Civilisation. Inspect the existing project first, reuse its current systems where possible, and do not create duplicate mechanics or levels when suitable implementations already exist.

Art direction and environments









Windows may remain in street or above-ground levels.



Add shiny, grainy light rays entering from sewer caps, storm drains, grates, or openings above.



Include subtle dust or grain floating within the light.



Keep sewer covers, drains, pipes, and access points visually prominent.



Maintain sufficient contrast between the environment, player, enemies, weapons, and hazards.

Typography





Replace the current display fonts with the Iron Dice Grit font pack already added to the repository.



Use Iron Dice Grit Black at font-weight: 950 for major titles, level names, victory/death messages, and large HUD text.



Use Iron Dice Grit Bold at font-weight: 900 for buttons, prompts, controls, counters, and short instructions.



Keep a readable sans-serif for long paragraphs and very small text if necessary.



Remove unused old font imports only after confirming they are no longer required.



Adjust font sizing, spacing, line height, buttons, and containers to prevent clipping or overflow.

Rusty-nail weapon





Make the rusty nail an equippable melee weapon.



When collected, show it immediately in one of the cockroach’s front arms.



Attach it to the arm animation so it does not float separately.



Keep it visible while walking, jumping, and attacking.



Allow the player to carry it for at least five metres, or integrate it with the existing weapon-duration system.



Give the nail a distinct attack animation and impact effect.



Add approximately 0.5 seconds of clearly communicated weapon buff or readiness feedback without making the controls feel unresponsive.



Remove the nail pickup from the world immediately after collection.



Add a configurable delay before the nail pickup can reappear in the world.



Do not delay the nail appearing in the player’s hand.



Prevent multiple copies from respawning immediately at the same location.

Contextual controls





Display X — BITE when the cockroach is unarmed.



Display X — HIT while a weapon is equipped.



Update the prompt immediately when the weapon state changes.

Bottle-cap helmet





Place a collected bottle cap directly over the cockroach’s head as a helmet.



Do not float it above the head or place it on another cap.



Attach it to the head animation.



Use it as protection against suitable hazards such as thorns, rocks, or falling debris.



Add visible and audible feedback when it blocks damage.



Break or remove it when its protection is exhausted.

Eggs and baby companion





Redesign the eggs with cracked openings at the top.



Give them a stylised cracked chicken-egg appearance.



Keep the baby mostly inside until the hatch animation.



Avoid having the baby protrude through an unbroken shell.



Make the baby cockroach follow behind the player consistently.



Maintain a readable trailing distance.



Prevent the baby from blocking or overlapping the player.



Make it catch up when it falls too far behind.



Recover or teleport it safely if level geometry leaves it permanently stuck.



Bring the baby through every level transition with the player.

Enemy hits and damage feedback





Make damage against rats, bosses, and other enemies much easier to understand.



Add clear enemy hit reactions.



Add impact flashes, particles, recoil, or appropriate hit effects.



Add floating damage values if they suit the existing visual style.



Provide clear enemy and boss health feedback.



Make player damage obvious through animation, sound, health changes, or screen effects.



Add brief invulnerability feedback after the player is hit.



Make blocked, weak, normal, and powerful hits visually distinct where supported.



Ensure the player can tell whether an attack connected and how much damage it caused.

Spider death





Give spider deaths a stronger physical impact.



Add a short knock-up, recoil, bounce, or upward movement.



Allow the body to fall naturally afterward.



Spawn a small stylised spider ghost.



Make the spider ghost float upward, fade, and disappear.



Keep the effect playful rather than graphic.

Acid and poison puddles





Animate acid drops falling from sewer pipes.



Create a visible acid puddle where each drop lands.



Grow the puddle progressively while the acid continues dripping.



Cap its maximum size.



Ensure the visible puddle and damaging collision area match.



Add bubbling, sizzling, steam, glow, or particle feedback.



Shrink or remove the puddle when appropriate after the source stops.



Do not allow invisible acid damage beyond the visible puddle.



Reuse this puddle system for Granny’s insecticide where appropriate.

Flies and rewards





Make defeated flies drop small hearts or power rewards.



Use hearts when the reward restores health.



Use an existing energy or power visual when it restores another resource.



Allow the reward to move toward the player or be collected manually.



Add clear collection feedback.



Respect maximum health and energy limits.



Do not grant fly rewards silently.

Level exits and progression





Place a clearly visible exit pipe at the end of every level.



Add an arrow or animated indicator pointing into the pipe.



Allow the player and baby companion to enter it.



Play an entry, crawling, or descent animation.



Trigger the next level only after the transition begins.



Prevent early activation while required objectives or combat remain unfinished.



Preserve progress through the existing save or checkpoint system.



Add a sewer bowl, drain, pipe, or sewer access point at the end of the pantry.



Make this exit visually connect the pantry or kitchen to the sewer.



Ensure it leads to the correct sewer level.

Player death and ghost





When the player dies, spawn a cockroach ghost.



Make the ghost float upward before fading or transitioning to the restart screen.



If a ghost-level or equivalent progression value already exists, make higher values produce a higher ghost rise.



Clamp the height so the ghost remains visible.



Keep the animation duration reasonable.



Show a minimum visible rise even at level zero.



Do not invent a major ghost-progression system if none exists; expose a configurable value and report that a design decision is needed.



Do not use SQUISHED as the generic death message.



Reserve SQUISHED for death by Granny’s foot, swatter, or another crushing attack.



Use SPRAYED or POISONED for insecticide deaths.



Use cause-appropriate messages for acid, enemies, falling, and other hazards.

Granny Level 1: kitchen floor





Create or improve the first Granny level on the kitchen floor.



Use white tiled walls.



Use a worn wooden floor.



Include cupboards, counters, skirting boards, and floor-level obstacles.



Show Granny peeking or rising from behind the counter.



Make her notice the cockroach and look shocked.



Play a short startled Eek! voice cue when she notices the cockroach.



Play the cue once per encounter unless the encounter resets.



Make Granny attack from above.



Possible attacks include a fly-swatter strike, foot stomp, water splash, and insecticide spray.



Give every attack a readable warning or telegraph.



Ensure visible attack areas and collision areas match.



Provide a fair avoidance window and short recovery period.



Add distinct impact feedback for each attack.

Granny insecticide audio





Play a recognisable psst or sustained aerosol-spray sound during insecticide attacks.



Synchronise the sound with the visible spray.



Stop or fade the sound when spraying ends.



Stop it if the game pauses, the player dies, or the scene changes.



Make the Eek! and spray sounds respect the sound-effects setting.



If final audio is unavailable, add clearly named audio hooks and temporary placeholders, then report the missing assets.

Granny Level 2: tabletop





Create a second, distinct Granny level on top of a kitchen or dining table.



Do not reuse the kitchen-floor layout with only a different background.



Make the player run and fight between oversized tabletop objects.



Include salt and pepper shakers.



Include a flower vase.



Include suitable plates, cups, cutlery, napkins, crumbs, food containers, spills, and other table props.



Use props as platforms, cover, obstacles, hazards, enemy hiding places, and combat arenas.



Clearly communicate dangerous table edges.



Give this level a different route, scale, and gameplay rhythm from the kitchen-floor level.

Cat threats and Big Boss cat





Add cat-related threats to the tabletop level.



Use background eyes, paws, shadows, vibrations, and objects being knocked over to build tension.



Avoid decorative cat elements obscuring important gameplay information.



Add a Big Boss cat encounter at the end of the tabletop level.



Give the cat boss importance comparable to the King Rat.



Make it appear enormous relative to the cockroach.



Use its head, paws, shadows, and surrounding movement rather than requiring the entire cat to stand on the table.



Add a dedicated boss health display.



Include clearly telegraphed paw swipes.



Include pounce or head-lunge attacks.



Include table-shaking attacks.



Give each attack fair collision areas and avoidance windows.



Add recoverable attack windows during which the player can strike.



Add strong hit and damage feedback.



Add a clear cat-boss defeat sequence.

Music and sound settings





Add a separate music on/off control.



Add a separate sound	-effects on/off control.



Make the current state of each control obvious.



Apply changes immediately.



Save both preferences locally.



Restore them when the game is reopened.



Ensure muting music does not mute sound effects.



Ensure muting sound effects does not mute music.



Place the controls in the main menu and pause/settings menu.



Support keyboard, controller, and any existing touch navigation.



Use accessible labels.



Prevent duplicate music tracks when music is turned back on.



Preserve existing volume sliders if present while still providing mute controls.

Animation, audio, and technical polish





Match all additions to the existing visual style.



Reuse the current animation, collision, audio, and state systems.



Keep gameplay collisions separate from decorative effects.



Do not add excessive screen shake or flashing.



Maintain stable performance.



Respect pause, restart, death, save, and level-transition states.



Add suitable sound hooks without making the build depend on missing final audio.



Avoid introducing unrelated mechanics.

Verification





Run the existing build, tests, linting, and type checking.



Test every affected level.



Test desktop and mobile layouts.



Test keyboard, controller, and existing touch controls.



Confirm the Iron Dice Grit font loads locally without external requests.



Confirm Bold and Black are actual supplied font files and are not browser-synthesised weights.



Confirm text does not clip or overflow.



Confirm the nail remains attached during movement and attacks.



Confirm the nail appears in the hand immediately but respawns in the world only after its cooldown.



Confirm the bottle cap follows the head and blocks the intended damage.



Confirm the baby follows through every exit.



Confirm acid and poison visuals match their collision areas.



Confirm enemy and boss damage is readable. Maybe a piechart rather or what is clearer?



Confirm Granny’s attacks are telegraphed and avoidable.



Confirm Granny’s audio respects the sound-effects toggle.



Confirm music and sound settings persist after restarting.



Confirm the tabletop cat boss can be completed without collision or progression problems.



Confirm every exit leads to the correct next level.

Before you go to the next levels and every level, before you can go to the next one, you need to defeat the big boss. 

He said it was a big boss with his own unique styles. 

The way he beats it is always different. 

