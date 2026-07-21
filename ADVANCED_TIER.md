# Dream Studio — Advanced / Systemic Mechanics Tier

The deep end of the atlas: mechanics that aren't a single verb but a *system*
of interacting loops. These are where retention and monetization actually
compound — the shapes behind the highest-grossing mobile games. All are
single-player-buildable (the only 🚫 remains real-time multiplayer infra).

Home project: **`games/deeplab/`** — a third museum (after mechlab, mechlab3d)
for systemic mechanics. Same board/best/analytics contract. LIVE now with the
six ✅ mechanics below (open `games/deeplab` in Godot, F5).

**Status:** ✅ built now · 🔨 queued (ask by name to build next)

---

## ✅ 1. Roguelike run structure — `roguerun`
**Loop:** a branching map of nodes (fight / elite / shop / rest / treasure /
boss). Pick your path; each node resolves against your HP, power, gold, and
relics; reach and beat the boss to ascend into a harder map; death ends the
run but meta-progress persists. **Why it matters:** the *wrapper* that turns
any combat mechanic (deckbuilder, loot, tactics) into a "run" with stakes —
Hades, Slay the Spire, FTL. Highest replay value per byte of content.
**Gray-box:** column-DAG map, tap reachable nodes, auto-resolve encounters,
relics = passive stat mods. Score = bosses felled (ascension).

## ✅ 2. Base building + raid — `basebuild`
**Loop:** build production (mine, barracks) + defense (wall, tower) on a grid;
resources and army accrue on timers; RAID a scaling PvE base for loot; the
enemy raids you back, so defense matters. **Why:** Clash of Clans / Rise of
Kingdoms — the "build-and-battle" economy that prints money via time-skips and
army boosts. **Gray-box:** build-pad grid, per-type stat contribution, raid =
army vs defense compare, periodic incoming raid. Score = raids won.

## ✅ 3. City / colony sim — `citysim`
**Loop:** place houses (population), farms (food), workplaces (coins); pop
grows only if food ≥ pop; imbalance starves the city. Grow as large as you can.
**Why:** SimCity / Township / Frostpunk — the balance-and-optimize itch, and a
natural home for cosmetic + expansion monetization. **Gray-box:** build grid,
food/pop/coin tick, growth vs starvation. Score = peak population.

## ✅ 4. Incremental / prestige — `prestige`
**Loop:** tap + generators earn cash; a PRESTIGE reset trades all progress for
permanent "stars" that multiply future income — so each reset climbs faster.
**Why:** the purest depth mechanic in mobile — AdVenture Capitalist, Cookie
Clicker. Prestige is the loop that makes an idle game *last*. **Gray-box:** tap,
buy generators + tap power, prestige when lifetime crosses a threshold. Score =
stars earned.

## ✅ 5. Turn-based tactics — `tactics`
**Loop:** grid battle; move each unit within range, attack adjacent foes, spend
the turn; enemy AI advances and strikes; wipe the enemy squad to advance to a
tougher map. **Why:** Into the Breach / XCOM / Fire Emblem — deep, thinky,
and the backbone of gacha-RPG combat (which is where the money is). **Gray-box:**
8×8 grid, 2-3 units/side, move+attack, simple AI. Score = squads defeated.

## ✅ 6. Boss-pattern bullet-hell — `bosshell`
**Loop:** a boss cycles telegraphed attack patterns (spread / aimed / spiral);
you dodge (drag) while auto-firing up; deplete boss HP to face a harder boss
with a new pattern; three hits and you're out. **Why:** the readable-danger
action core of Hades bosses, Enter the Gungeon, and every anime-gacha "challenge
boss." **Gray-box:** boss HP, 3 rotating bullet patterns, player dodge + auto-fire.
Score = bosses downed.

---

## ✅ 7. Physics sandbox — `ragdoll`
Drag-fling a ragdoll, bounce off pins for points, fly as far as you can (Kick
the Buddy). Scripted deterministic physics — endless, score = best distance.

## ✅ 8. Rhythm-action hybrid — `rhythmaction`
Four-lane beatmap that drives combat: tap on-beat to strike the boss and build
a combo; a missed note lets the boss hit you (Hi-Fi Rush). Score = bosses.

## ✅ 9. Tower-defense variant — `mazetd`
Maze TD: place towers on a grid and creeps pathfind AROUND them (BFS), so you
route the maze to buy kill-time; you can't fully wall them off. Score = waves.

## ✅ 10. Narrative / choice — `narrative`
Reigns-style: swipe left/right on a card; every choice shifts four resource
meters; empty OR full any meter and your reign ends. Score = years survived.

## ✅ 11. Roguelike deckbuilder — `deckrogue`
The full Slay the Spire: deckbuilder combat, then draft 1 of 3 cards, climb
floors, rest every fourth. Roguerun structure fused with card combat. Score = floors.

## ✅ 12. Auto-chess with synergies — `autochess`
Buy units whose TRAITS synergize (2 of a trait buffs, 4 buffs more); effective
power fights the wave; gold interest + reroll (TFT). Score = rounds won.

## ✅ 13. Survivor evolution — `surviveevo`
Vampire-Survivors swarm where weapons LEVEL and EVOLVE at max into stronger
forms (Bolt → Railgun, Orbit → Saturn); pick an upgrade each level. Score = kills.

## ✅ 14. Trading / market sim — `marketsim`
Buy-low-sell-high across three goods with drifting prices + sudden supply
shocks; grow net worth (tycoon/economy loop). Endless; score = peak net worth.

## ✅ 15. Merge-3 progression meta — `mergemeta`
A merge board wrapped in the energy + chapter economy that makes Merge Mansion
a game: spawn (spends energy), merge up, deliver the ordered tier to advance
the chapter. Endless; score = chapters completed.

---

**All 15 advanced-tier mechanics are now BUILT** in `games/deeplab/`.

## Deep expansion (2026-07-21) — 6 more genre-defining deep systems (deeplab → 21)

Beyond the core 15, DeepLab now also includes:

- **puzzlerpg** — match-3 that fuels RPG combat (Puzzle & Dragons, Empires & Puzzles)
- **cardbattle** — minion-board card game vs AI (Hearthstone), distinct from the
  solo-run deckbuilder
- **idlerpg** — AFK team auto-battle with hero leveling + ascension (AFK Arena)
- **dungeon** — roguelike grid crawler with fog of war (Pixel Dungeon)
- **lifesim** — five-need management sim (The Sims)
- **factory** — production-chain automation with bottlenecks (Factorio / idle)

DeepLab total: **21 deep systemic mechanics**. Studio total: **79 playable
mechanics** across mechlab (38) + mechlab3d (20) + deeplab (21).

## 🚫 Still infra-gated (not mechanic difficulty)
MOBA, battle royale, .io arenas, CCG PvP, guild wars, UGC platforms — all need
a real-time server + live player base. Deferred until one single-player
mechanic proves retention worth scaling socially.

## How this feeds the studio
Deep mechanics are heavier to build but retain far longer and monetize deeper.
The play: prove a *casual* mechanic wins in mechlab/mechlab3d (cheap, fast),
then wrap the winner in a deep-tier system here (roguerun run structure,
prestige meta, base-build economy) to turn a 3-minute toy into a 3-month game.
