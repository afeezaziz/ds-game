# Dream Studio — Mechanics Atlas

The master map of core game mechanics since the arcade era, tracked as an
implementation checklist. There is no finite list of "every mechanic ever" —
but the core *verbs* of game design form a countable set of families, and this
atlas covers the canon. Each mechanic gets a gray-box demo (mostly in the
`mechlab` project; big systemic ones get their own lab like `openlab`).

**Status legend:** ✅ live · 🔨 batch queued · ⬜ unscheduled · 🚫 needs infra we
deliberately don't have yet (real-time multiplayer / content scale / UGC platform)

---

## 1 · Timing & reflex (arcade → hypercasual)

| mechanic | canonical game | status | where |
|---|---|---|---|
| slide-and-drop timing | Stack | ✅ | skystack:classic |
| pendulum/momentum release | Tower Bloxx | ✅ | skystack:pendulum |
| size/rhythm pulse timing | Lucky Wheel-likes | ✅ | skystack:pulse |
| aim-ahead under drift | Wind games | ✅ | skystack:wind |
| reaction to chaos | Rush-likes | ✅ | skystack:rush |
| one-tap gravity flight | Flappy Bird | ✅ | mechlab:flappy |
| falling-note rhythm | Guitar Hero / Piano Tiles | ✅ | mechlab:rhythm |
| timing gates / color match gate | Color Switch | 🔨 b2 | mechlab |
| quick-time events | Shenmue / Telltale | ⬜ | mechlab |

## 2 · Aim & projectile (Pong → Angry Birds)

| mechanic | canonical | status | where |
|---|---|---|---|
| paddle deflection | Pong / Breakout | ✅ | mechlab:breakout |
| rotate + shoot + drift | Asteroids | ✅ | mechlab:asteroids |
| drag-aim ballistic launch | Angry Birds | ✅ | mechlab:sling |
| hitscan aim (3D) | Doom → sniper games | ✅ | openlab (shooting) |
| billiards / bounce planning | 8 Ball Pool | 🔨 b2 | mechlab |
| turret / artillery angle+power | Worms / Scorched Earth | 🔨 b2 | mechlab |
| bullet-hell dodging | Touhou / Survivor.io | 🔨 b3 | mechlab |

## 3 · Match & merge (Tetris → Candy Crush → 2048)

| mechanic | canonical | status | where |
|---|---|---|---|
| swap-adjacent match-3 | Bejeweled / Candy Crush | ✅ | mechlab:match3 |
| falling tetromino packing | Tetris | 🔨 b2 | mechlab |
| slide-and-merge powers | 2048 | 🔨 b2 | mechlab |
| free-merge on board | Merge Dragons | 🔨 b3 | mechlab |
| block-blast fit puzzle | Block Blast | 🔨 b2 | mechlab |
| bubble shooter (aim+match) | Puzzle Bobble | 🔨 b2 | mechlab |

## 4 · Grid logic & puzzle (pre-digital → Nokia → indie)

| mechanic | canonical | status | where |
|---|---|---|---|
| grow-and-avoid | Snake | ✅ | mechlab:snake |
| push-block puzzles | Sokoban | ✅ | mechlab:sokoban |
| deduction from numbers | Minesweeper / Picross / Sudoku | 🔨 b3 | mechlab |
| pathfinding/pipe rotation | Pipe Mania / Flow Free | 🔨 b3 | mechlab |
| turn-based tactics grid | Chess / Into the Breach | ⬜ | own lab (deep) |

## 5 · Physics toys (Cut the Rope era)

| mechanic | canonical | status | where |
|---|---|---|---|
| tower stability / stacking | Stack / Tricky Towers | ✅ | skystack (abstracted) |
| rope cut / constraint solve | Cut the Rope | ⬜ | mechlab |
| ragdoll / soft body comedy | Happy Wheels | ⬜ | mechlab |
| vehicle balance | Hill Climb Racing | 🔨 b3 | mechlab |
| drawing as physics object | Brain Dots | ⬜ | mechlab |

## 6 · Runner & platformer (Mario → Subway Surfers)

| mechanic | canonical | status | where |
|---|---|---|---|
| lane/turn endless runner | ZigZag / Subway Surfers | ✅ | zigroll |
| hold-release measurement | Stick Hero | ✅ | bridgehop |
| jump+gravity platforming | Mario | 🔨 b2 | mechlab |
| wall-jump / dash aerial | Celeste | ⬜ | mechlab |
| runner with switch-state | Geometry Dash | 🔨 b3 | mechlab |

## 7 · Strategy & defense (RTS → TD → auto-battler)

| mechanic | canonical | status | where |
|---|---|---|---|
| tower defense | Kingdom Rush / Bloons | ✅ | mechlab:towerdef |
| lane pusher / summon battler | Clash Royale | ⬜ | needs mp infra for PvP; PvE 🔨 b4 |
| auto-battler economy | TFT | ⬜ | mechlab b4 |
| RTS select-and-command | StarCraft | ⬜ | own lab (deep) |
| 4X turn empire | Civilization | ⬜ | own lab (deep) |

## 8 · Progression & economy (Farmville → idle era)

| mechanic | canonical | status | where |
|---|---|---|---|
| tap income + compound generators | Cookie Clicker / AdVenture Capitalist | ✅ | mechlab:idle |
| timers + harvest loops | FarmVille / Hay Day | 🔨 b4 | mechlab |
| city/base building | SimCity / Clash of Clans | ⬜ | own lab (deep) |
| tycoon queues & margins | Game Dev Tycoon | ⬜ | mechlab |
| gacha pull + collection | Genshin / FGO | 🔨 b4 (ethics note: sim only) | mechlab |
| battle pass / season track | Fortnite | ⬜ | live-ops feature, not demo |

## 9 · Card & deck (solitaire → deckbuilders)

| mechanic | canonical | status | where |
|---|---|---|---|
| solitaire patience rules | Klondike | 🔨 b3 | mechlab |
| deckbuilding roguelike combat | Slay the Spire | 🔨 b4 | mechlab (flagship candidate) |
| CCG duel | Hearthstone | 🚫 PvP infra; PvE ⬜ | — |
| push-your-luck | Blackjack / Balatro-ish scoring | 🔨 b3 | mechlab |

## 10 · Word & trivia (crossword era → Wordle)

| mechanic | canonical | status | where |
|---|---|---|---|
| letter-grid word finding | Word Search / Boggle | 🔨 b3 | mechlab |
| guess-with-feedback | Wordle / Mastermind | 🔨 b2 | mechlab |
| quiz / trivia ladder | Trivia Crack | ⬜ | mechlab (needs question DB) |

## 11 · Stealth, survival & horror verbs

| mechanic | canonical | status | where |
|---|---|---|---|
| vision-cone avoidance | Metal Gear (2D era) | 🔨 b2 | mechlab |
| hide-and-seek AI | Alien: Isolation | ⬜ | openlab extension |
| hunger/resource survival | Don't Starve | ⬜ | own lab |
| wave survival + pickup | Vampire Survivors | 🔨 b3 | mechlab (hot genre) |

## 12 · RPG systems (D&D → roguelites)

| mechanic | canonical | status | where |
|---|---|---|---|
| turn-based menu combat | Final Fantasy / Pokémon | 🔨 b4 | mechlab |
| XP levels / skill tree | Diablo | 🔨 b4 | mechlab (as meta-layer demo) |
| loot rarity dopamine | Diablo / Archero | 🔨 b4 | mechlab |
| roguelike run + permadeath meta | Hades / Archero | ⬜ | flagship candidate |
| dialogue trees | Baldur's Gate | ⬜ | mechlab (narrative demo) |

## 13 · Open-world & simulation verbs (the OpenLab family)

| mechanic | canonical | status | where |
|---|---|---|---|
| third-person traversal + orbit cam | GTA / RDR2 | ✅ | openlab |
| vehicle enter/exit + arcade driving | GTA | ✅ | openlab (car) |
| mount riding | RDR2 | ✅ | openlab (horse) |
| wanted/heat + police AI | GTA | ✅ | openlab |
| crowd NPC ambience | GTA | ✅ | openlab |
| procedural missions | GTA side content | ✅ | openlab |
| day/night + minimap | all open worlds | ✅ | openlab |
| life sim needs/relationships | The Sims | ⬜ | own lab |
| crafting + block building | Minecraft | ⬜ | own lab (voxel = real project) |

## 14 · Multiplayer-dependent (flagged, not faked)

MOBA (Mobile Legends), battle royale (PUBG/Fortnite), .io arenas, CCG PvP,
guild wars, UGC platforms (Roblox). 🚫 until the dedicated real-time service
exists — these are *network architectures*, not client mechanics. The client
verbs they use (aim, move, build) are already covered above; what's missing is
infra. Decision on that service comes AFTER a single-player mechanic proves
retention worth scaling socially.

---

## Modern wing update (2026-07-21)

Eight post-2015 mechanics went LIVE in mechlab, jumping their batch queue:
**survivors** (auto-battler swarm + level-up choices), **paperio** (territory
capture vs AI bots — the io feel without netcode), **crowdgate** (Count
Masters gate-math runner), **mergeboard** (drag-merge grid + orders),
**arcadeidle** (My Mini Mart walk-collect-sell), **wordle** (guess-feedback
deduction), **sniper** (scoped mission shooter), **dashrun** (Geometry Dash
precision runner). Rows below updated accordingly: wave survival ✅, free-merge
✅, guess-with-feedback ✅, geometry-dash runner ✅, plus four rows this table
previously lacked. The menu now lists the modern wing first.

## 3D wing (2026-07-21) — the `mechlab3d` project

A dedicated sibling project, `games/mechlab3d/`, holds 20 modern 3D / 2.5D
mechanics (own MechDemo3D base + shell; same board/best/analytics contract).
All gray-box primitives, all desktop-playable (mouse + WASD) and touch:

1. runner3d — 3-lane endless runner (Subway Surfers)
2. helix — rotate-tower ball drop (Helix Jump)
3. stackball — smash-through platforms (Stack Ball)
4. holeio — swallow-the-city .io (Hole.io)
5. kart — arcade kart + drift boost (Mario Kart)
6. marble — roll-the-winding-track (Going Balls)
7. archero — stop-to-shoot roguelite (Archero)
8. crowd3d — gate-math crowd runner in 3D (Count Masters)
9. slice3d — swipe-to-slice (Fruit Ninja)
10. flight — fly-through-rings, dodge pillars
11. parkour — jump-the-gaps platformer
12. tumble — downhill slalom dive
13. bridgerace — collect-planks-auto-build (Bridge Race)
14. stackrun — stack-height runner (Shortcut Run)
15. hoops — flick-arc basketball
16. aquapark — lean-and-slide water tube (Aquapark.io)
17. sword — timing-combo melee dash
18. wreck — RigidBody3D physics demolition
19. fpswave — first-person wave shooter (zombies)
20. idle3d — walk-collect-sell 3D idle (Gold mine)

These move many previously-⬜/🔨 rows to ✅ in 3D form (endless runner 3D,
kart, marble, archero twin-stick, fruit-slice, flight, bridge race, aquapark,
melee combo, physics demolition, FPS wave, 3D arcade idle). Adding a 3D
mechanic = extend MechDemo3D + one DEMOS entry, same as the 2D lab.

## Batch roadmap — ALL BUILT (2026-07-21)

- **Batch 1 ✅ (mechlab):** snake, breakout, asteroids, sokoban, flappy, match3,
  sling, rhythm, towerdef, idle.
- **Batch 2 ✅ (mechlab):** tetris, g2048, bubbleshoot, blockblast, billiards,
  artillery, stealth. (wordle already shipped in the modern wing.)
- **Batch 3 ✅ (mechlab):** minesweeper, flow (connect-the-dots), tripeaks
  (solitaire), pushluck, wordsearch, hillclimb. (survivors + geometry-dash
  shipped earlier as `survivors` / `dashrun`.)
- **Batch 4 ✅ (mechlab):** rpgcombat, loot, gacha (sim), deckbuilder, farm,
  autobattler, lanepusher — the deep monetizing systems.

`mechlab` now holds 38 2D demos; `mechlab3d` holds 20 3D demos. 58 playable
mechanics total across the two labs.

## There is no ceiling — the advanced / systemic tier

The "batches" were a staging order, not a limit. These are candidate future
builds (each a single-player mechanic we CAN build; the only true blocker is
real-time-multiplayer infra, still deferred):

- **Roguelike run structure** — map nodes, events, relics, permadeath + meta
  (Hades / FTL). The framework that wraps deckbuilder/loot into a "run".
- **Base building + raid** — build, defend, timers, army (Clash of Clans PvE).
- **City / colony sim** — supply chains, needs, growth (SimCity / Frostpunk).
- **Incremental / prestige** — reset-for-multiplier depth (Cookie Clicker layer 2).
- **Physics sandbox** — soft-body / ragdoll / destruction toys.
- **Rhythm-action hybrid** — beatmap drives combat (Hi-Fi Rush / Crypt of NecroDancer).
- **Boss-pattern bullet-hell** — telegraph → dodge → punish windows.
- **Tower-defense variants** — maze TD, co-op lanes, hero TD.
- **Narrative / choice** — branching dialogue, consequence state (visual novel core).
- **Deck-drafting / roguelike deckbuilder** — pick-1-of-3 build-a-deck-mid-run.
- **Auto-chess with synergies** — trait bonuses, item combines, econ curves.
- **Survivor evolution** — weapon-combine / evolution trees (Vampire Survivors depth).
- **Turn-based tactics** — grid, cover, action points (Into the Breach / XCOM-lite).
- **Trading / market sim** — buy-low-sell-high, supply shocks (economy loop).
- **Merge-3 progression meta** — merge board wrapped in a story/energy economy.

Ask for any of these by name and it becomes the next batch. (Multiplayer verbs
— MOBA, battle royale, .io arenas, CCG PvP, Roblox-style UGC — remain 🚫 not
because the mechanic is hard but because they need a real-time server + player
base, a business decision we deferred until one single-player mechanic proves
retention worth scaling socially.)

## How to read the data (the point of all this)

Every demo posts to its own leaderboard (`board == demo key`) and tags every
event with the demo key. Rank mechanics by: plays per session, average session
depth, retry rate, and D1 return to the same demo. A mechanic that wins in
gray-box — with zero art, zero sound, zero meta — is a mechanic worth building
a real game around. That's the studio's entire R&D thesis in one sentence.
