# Dream Studio — Going Deeper (DeepLab depth pass)

Honest self-critique: the DeepLab v1 demos captured each genre's *core verb* but
not its *depth systems* — the interlocking loops that make players stay. A
deckbuilder isn't "play cards at an enemy"; it's the tension of block-resets,
status stacking, relic synergies, and a map of risk/reward choices. This pass
rebuilds the flagships with those systems.

## What "deep" means, per mechanic

### Deckbuilder (deckrogue) — depth = *interacting systems + a run structure*
Shallow v1: energy, dmg/block cards, floors, draft. Missing everything that
creates decisions.
Deep rebuild adds:
- **Status effects** that stack and interact: Block (resets each turn),
  Strength (+dmg/attack), Dexterity (+block), Vulnerable (+50% dmg taken),
  Weak (−25% dmg dealt), Poison (damage-over-time that ticks down).
- **Enemy intents**: each enemy telegraphs its next move (attack N / block /
  buff / debuff) from a *scripted pattern*, so you plan around it — the heart
  of StS decision-making.
- **Enemy archetypes**: cultist (ramps strength), jaw-worm (attack/defend),
  slaver (applies weak), plus **elites** and a **boss every 5 floors**.
- **Relics**: permanent passives with real triggers — Burning Blood (heal on
  win), Anchor (start with block), Vajra (start with strength), Coffee Dripper
  (+1 energy/turn), Bag of Prep (draw extra turn 1), Bronze Scales (thorns).
- **Potions**: 3 consumable slots (fire/block/strength/heal).
- **Card upgrades** at rest sites; **card rewards by rarity** after combat.
- **A map of choices**: after each node you *choose* your next node
  (fight / elite / rest / shop / treasure) — risk vs reward pathing.
- **Shop**: spend gold on cards, relics, potions, card-removal, healing.

### Survivors (surviveevo) — depth = *build-craft via evolution combos*
Shallow v1: 2 weapons, level-up +1. Missing the build.
Deep rebuild adds:
- **5 weapons** (Bolt, Orbit, Whip, Aura, Boomerang), each levels 1→8.
- **Passive items** (Might, Haste, Area, Magnet, Armor, Growth) that modify all
  weapons.
- **Evolution**: a max-level weapon + its paired passive fuses into an evolved
  form (Bolt+Might→Railgun pierce, Orbit+Area→Saturn, Whip+Haste→Cyclone,
  Aura+Armor→Sanctuary, Boomerang+Growth→Comet). The core VS chase.
- **Enemy archetypes**: swarmer, runner (fast), tank (armored), exploder;
  **boss waves** on a timer that drop a **chest** (free weapon level).
- Real XP curve, gold, escalating spawn director.

### Incremental (prestige) — depth = *layers of currency + a perk tree*
Shallow v1: one generator, one prestige stat. Missing the tree.
Deep rebuild adds:
- **5 generator tiers**, each with its own cost curve and per-tier **milestones**
  (x2 output at 10/25/50 owned).
- **Upgrade shop**: global multipliers, tap power, generator boosts.
- **Prestige (Ascend)** grants **stars**; stars are spent in a **perk tree**
  (permanent: +income mult, cheaper gens, stronger taps, faster start) — so a
  reset makes you *structurally* stronger, not just numerically.

## Applied to the rest (queued for the next depth pass)
- **tactics** → unit classes (warrior/archer/mage/healer) with ranges/abilities,
  terrain cover, and a campaign where units persist and level.
- **autochess** → 3-star unit combines, items, more traits, bench + positioning.
- **cardbattle** → hero powers, minion keywords (taunt/charge/deathrattle).
- **idlerpg** → gear, skill trees, offline progress, ascension shards.
- **citysim/tycoon** → zoning, demand curves, services, disasters.

The principle for all of them: a mechanic gets deep when a *second system feeds
back into the first*. That feedback loop — statuses×relics, weapons×passives,
generators×prestige — is what turns a toy into a game.

---

# DeepLab 3D — the depth pass in three dimensions

`games/deeplab3d/` applies the same principle in 3D: each demo carries the
*depth system*, not just the verb. All scripted (no physics engine) so every
mechanic runs deterministically; gray-box primitives only.

### Boss Raid (bossraid) — depth = *telegraph→resolve + phases + positional dmg*
Not "hit the big enemy". The boss runs a **move set that changes per phase**
(100/60/25% HP). Every attack **telegraphs** (a ground marker grows in alpha)
then **resolves** — you read it and dodge out of the shape in time, or eat it.
Attacks have real shapes: point-blank slam (AoE), facing cone sweep, a **charge**
that relocates the boss along a line, and a phase-3 **inverse ring** that is only
safe if you hug the boss. Hits to the **weak point on its back** deal 2x, so
positioning is the skill. A **dodge-roll** spends stamina for i-frames. Miss the
**DPS check** and the boss **enrages** (faster telegraphs, harder hits). Feedback
loop: phase → new patterns → forces new positioning → weak-point windows.

### Survival 3D (survival3d) — depth = *gather → craft → defend, gated by a clock*
A **day/night cycle** is the pressure. By day you **gather** wood/stone from
resource nodes and **hunger** ticks down (eat berries or it eats your HP). At
**night**, raiders spawn at the map edge and march on your **campfire**; you
spend wood to **build walls** that block their path (they attack the wall first)
and to **reheal the fire**. Survive a night → score. Wave size scales with the
day count, so the gather/build economy must outpace the escalating threat.
Feedback loop: daytime gathering → nighttime defenses → survive → harder night.

### Mech Combat (mech) — depth = *two weapons on a shared HEAT economy + lock-on*
The heat gauge is the whole game. The **cannon** is cheap hitscan; **missiles**
need a **lock** (hold your aim cone on a foe until it fills) and hit hard but
spike heat. Fire too much → **overheat lockout** (can't shoot until it cools, and
it cools *slower* while overheated — a real punish). A **boost-dash** burns a
separate **energy** pool for i-frames and repositioning. Enemy mechs strafe to
mid-range and fire, wearing your **armor** down. Feedback loop: heat forces you
to alternate cheap cannon vs committed missiles, and to earn locks under fire.

### The rest (breadth exhibits with one depth hook each)
- **actionrpg** — XP/levels: kills grant XP; leveling raises damage + max HP, so
  the power curve feeds the combat.
- **fpsarena** — ammo/magazine/reload and aim-cone accuracy gate the shooting.
- **td3d** — a real creep **path** with per-wave scaling; tower placement vs path
  proximity is the puzzle.
- **racing** — AI rivals + a **drift→boost** economy (charge while drifting, fire
  on release) over a 3-lap circuit.
- **platform3d** — double-jump + **moving platforms** + collect-all-to-advance;
  lives gate mistakes.
- **dogfight** — pitch/yaw flight with homing foes and an HP budget.
- **citybuild3d** — orbit-cam placement with a **food×population** economy loop.

Same rule as the 2D pass: a mechanic gets deep when a second system feeds back
into the first — telegraph×positioning, gather×defend, heat×weapon-choice.
