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

## Portfolio notes

- All three run fully offline; leaderboards/config/cross-promo light up when
  the backend is reachable. Cross-promo is now live in all directions: each
  game-over screen advertises the other two.
- Store URLs go into `backend/seed.py` after each Play Store listing exists.
- Tuning is remote: difficulty, gem rates, beam speeds, ad frequency — all
  adjustable per game from the backend without an app update.
