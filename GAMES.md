# Dream Studio — Game Catalog & Store Descriptions

Three live experiments, one platform. Each game tests a different core skill;
the analytics (games/session, average depth, retention per title) decide which
one gets the studio's full weight.

---

## 1 · Sky Stack — *the mechanics lab* (2D)

**One-liner:** Five ways to stack. One tower to top.

**Short description (80 chars):**
Stack blocks 5 different ways. Perfect drops, fever streaks, world rankings.

**Full description:**
How high can you go — and in which world? Sky Stack isn't one stacking game,
it's five. CLASSIC slides, you tap, the overhang gets sliced. PENDULUM swings
the block on a rope — release it with momentum and pray. PULSE locks the block
in place but pulses its size — tap on the beat. WIND blows your block sideways
as it falls — read the arrows, aim ahead. RUSH flips direction and bursts speed
just to mess with you. Every mode has its own world leaderboard, its own best,
and its own feel. Chain PERFECT drops to regrow your tower and ignite fever.
One thumb. Five skills. Zero mercy.

**Keywords:** stack, tower, one tap, arcade, timing, hypercasual, leaderboard

**Experiment question:** which timing skill (position / physics / rhythm /
aim-ahead / reaction) holds players longest?

---

## 2 · ZigRoll — *first 3D title*

**One-liner:** One tap. Don't fall off.

**Short description (80 chars):**
Roll the zigzag sky-path. Tap to turn, grab gems, don't look down. 3D arcade.

**Full description:**
A ball. A ribbon of floating tiles. Two directions. ZigRoll is pure flow-state
arcade: your ball rolls forward on its own — all you do is tap to zig or zag,
threading a path that crumbles away behind you. Snap up golden gems for bonus
points, feel the speed creep up tile by tile, and try not to blink: one late
tap and you're off the edge, watching the sky path disappear above you.
Instant restarts, global leaderboard, runs offline anywhere. Easy to start.
Impossible to put down.

**Keywords:** zigzag, ball, roll, 3D, endless, one tap, gems, arcade

**Experiment question:** does a continuous-motion one-tap 3D runner out-retain
discrete tap-timing games? (Also: our first read on Godot 3D perf on low-end
Android.)

---

## 3 · BridgeHop — *hold-and-release, 3D*

**One-liner:** Grow the beam. Nail the gap.

**Short description (80 chars):**
Hold to grow a beam, release to bridge the gap. Hit the red line for PERFECT.

**Full description:**
Between you and the next pillar: a gap, and your nerve. Press and hold to grow
a golden beam — too short and it tips into the void, too long and you overshoot
the sweet spot. Release, watch it slam down, and walk across if you judged it
right. Land the tip on the thin red center line for a PERFECT and chain a
combo streak that turns every crossing into a highlight clip. Procedural
pillars, escalating tension, world rankings, offline play. The rules take
three seconds to learn. The red line takes a lifetime.

**Keywords:** bridge, stick, hold and release, 3D, precision, arcade, perfect

**Experiment question:** do hold-duration mechanics (analog input) beat
tap-timing mechanics (binary input) on session length and share-rate?

---

## 4 · OpenLab — *open-world mechanics gray-box (R&D, 3D)*

**One-liner:** A whole city to mess with.

**Short description (80 chars):**
Run, drive, ride. Take jobs, dodge the cops, own the city. Open-world arcade.

**Full description:**
A pocket open world that fits in your pocket. Sprint through a neon gray-box
city on foot, steal— er, *borrow* the car, or saddle up the horse. Yellow
pillars mark the jobs: deliveries to run, checkpoint races to win, all on your
terms — any vehicle, any route. Cause trouble and the stars start stacking:
cops close in, and BUSTED costs you. Day rolls into night, the minimap keeps
you honest, and the leaderboard remembers who really ran this town.

**Keywords:** open world, driving, sandbox, city, missions, police chase, 3D

**Experiment question:** this one is R&D, not a weekly release. It exists to
answer: which open-world *system* (driving, shooting, missions, chase/wanted)
creates the most engagement per dev-hour — and can Godot's mobile renderer
hold a crowd + city + vehicles at 60fps on low-end Android? The winning system
gets extracted into a focused hypercasual title (chase game, sniper game,
delivery game — all proven mobile niches).

**Honest scope note:** OpenLab is a mechanics slice — the first artifact any
studio builds on the road toward GTA/RDR2-scale ambitions. It is gray-box by
design: systems first, beauty later. Do not compare it to a $2B production;
compare each mechanic to "is this fun for 30 seconds?" — that's the test.

---

## 6 · MechLab 3D — *modern 3D / 2.5D mechanics museum*

**One-liner:** 20 modern 3D mechanics, one tap away each.

**Short description (80 chars):**
Runner, kart, hole.io, archero, helix, slice & more — 20 modern 3D demos.

**Full description:**
The 3D companion to MechLab: twenty of the mechanics actually charting on
mobile today, each a bite-size playable exhibit. Dodge trains in a lane
runner, drift a kart, swallow a city as a growing hole, stop-and-shoot your
way through an Archero room, drop a ball down a spinning Helix tower, slice
fruit mid-air, fly a plane through rings, build bridges on the run, lean
through a water slide, and knock a tower down with real physics. All
gray-box, all instantly playable on desktop (mouse + WASD) or touch — built
to answer, in 3D, the same question as everything here: which mechanic do
people replay?

**Keywords:** 3D, hypercasual, runner, .io, kart, archero, helix, arcade

**Experiment question:** which 3D verb (runner / .io growth / auto-shooter /
timing-drop / physics) earns the most replays per session in gray-box — and
does Godot's mobile renderer hold 60fps with crowds + procedural worlds on
low-end Android? Winners graduate to their own polished title.

---

## 7 · DeepLab — *deep / systemic mechanics museum*

**One-liner:** The systems behind games that last months, not minutes.

**Short description (80 chars):**
Roguelike runs, prestige, base-build, tactics, boss-hell, city sim — 6 deep loops.

**Full description:**
Where the casual labs prototype 3-minute toys, DeepLab prototypes the systems
that keep players for months. Chart a branching roguelike run past elites and
bosses; reset an idle empire for permanent prestige multipliers; build and raid
a base economy; out-manoeuvre a squad on a tactics grid; dodge a boss's
telegraphed bullet patterns; and balance food against population in a growing
city. All gray-box, all the shapes behind the top-grossing charts — built to
answer which deep system is worth wrapping a proven casual mechanic inside.

**Keywords:** roguelike, prestige, idle, base-build, tactics, bullet-hell, sim

**Experiment question:** which deep loop (run-structure / prestige-reset /
build-economy / tactics / boss-action / city-balance) most deserves to *wrap*
a winning casual mechanic — turning a toy into a retained, monetizing game.
See ADVANCED_TIER.md for the full 15-mechanic tier and what's still queued.

---

## 8 · DeepLab 3D — *deep / systemic 3D mechanics museum*

**One-liner:** The 3D genres people sink hundreds of hours into, gray-boxed.

**Short description (80 chars):**
Action-RPG, FPS arena, TD, circuit racing, boss raid, survival, mech — 10 deep 3D loops.

**Full description:**
The 3D counterpart to DeepLab: ten systemic 3D loops, each carrying the depth
system that actually retains — not just the verb. A third-person action-RPG with
XP and levels; a first-person arena with ammo, reloads and aim-cones; a 3D tower
defense with a real creep path; a circuit racer with AI rivals, drift and boost;
a double-jump collectathon platformer; an Ace-Combat-lite dogfight; an orbit-cam
city builder with a food/population economy; a Monster-Hunter-style **boss raid**
where every attack telegraphs then resolves, weak-point hits double, and missing
the DPS check enrages the boss; a Valheim-lite **survival** loop of gather →
build walls → defend the campfire through escalating nights; and a Titanfall-lite
**mech** with two weapons on a shared heat gauge, lock-on missiles, and a
boost-dash on energy. All gray-box, all playable on desktop (mouse + WASD) or
touch — built to find which deep 3D system is worth wrapping a proven mechanic in.

**Keywords:** 3D, action-rpg, fps, tower-defense, racing, boss-raid, survival, mech

**Experiment question:** which deep 3D loop (RPG-progression / arena-shooter /
lane-defense / racing / collectathon / air-combat / city-economy / raid-boss /
survival-craft / mech-heat) holds attention longest in gray-box — and does the
mobile renderer hold 60fps with the added AI, projectiles and day/night on
low-end Android? Winners graduate to a polished title.

---

## 9 · FlagLab 3D — *flagship 3D genres museum*

**One-liner:** The 3D shapes behind the top-grossing charts, gray-boxed to play.

**Short description (80 chars):**
MOBA, battle royale, open-world, voxel, cover-shooter, stealth, musou, RTS — 10 flagships.

**Full description:**
The genres people pour hundreds of hours (and billions of dollars) into, each
carrying its real depth loop. Push a lane past minions and towers in a MOBA;
survive a shrinking-zone battle royale with tiered loot; drive-and-shoot a GTA-
style open world with a five-star wanted ladder; mine and place blocks through
voxel days and mob-filled nights; peek from cover under suppression in a Gears-
style shooter; slip past patrol vision cones for silent takedowns; mow crowds and
bank a musou gauge; chain scripted-pendulum grapple swings across a skyline;
knock a ball into the net in rocket-car football; and macro a base to raze the
enemy in a top-down RTS. All gray-box, all playable on desktop (WASD + mouse) or
touch via the shared on-screen controls — the named targets you'd build a
RM10M/month title around, prototyped in a week.

**Keywords:** 3D, MOBA, battle-royale, open-world, voxel, stealth, RTS, rocket-car

**Experiment question:** which flagship 3D loop (lane-push / zone-survival /
open-world-heat / voxel-build / cover-peek / stealth-detection / crowd-musou /
swing-momentum / car-ball / base-macro) is worth a full team wrapping into a
tentpole title — and which hold 60fps on low-end Android with their AI, crowds
and physics. Winners graduate; the rest still teach the genre's core tension.

---

## Portfolio notes

- All of them run fully offline; leaderboards/config/cross-promo light up when
  the backend is reachable. Cross-promo is live across the portfolio: each
  game-over screen advertises sibling titles.
- Store URLs go into `backend/seed.py` after each Play Store listing exists.
- Tuning is remote: difficulty, gem rates, beam speeds, ad frequency — all
  adjustable per game from the backend without an app update.
