# Sky Stack — Mechanics Lab

Sky Stack is the studio's mechanics testbed: five stacking mechanics behind one
shell, each with its own leaderboard (backend `board` == mode key), its own
local best, its own analytics tag (`mode` prop on `game_start`/`game_over`),
and its own remote-config tuning block. Ship it, watch the per-mode numbers,
and the winning mechanic becomes its own game via the template.

## Current modes

| key      | mechanic                                                | skill tested        |
|----------|---------------------------------------------------------|---------------------|
| classic  | block slides, tap to place, overhang sliced              | position timing     |
| pendulum | block swings on a rope, releases with momentum, falls    | physics anticipation|
| pulse    | block sits centered, its WIDTH oscillates, tap at match  | rhythm timing       |
| wind     | slides up high, falls with sideways wind drift (arrows)  | aim-ahead           |
| rush     | classic + random direction flips and speed bursts        | reaction            |

## Live tuning (no store update)

`backend/seed.py` → `CONFIGS["skystack"]`:

- `enabled_modes`: list of mode keys to show in the menu (kill or stage modes remotely)
- `modes`: `{"<mode>": {param: value}}` — overrides any default in
  `Stack.gd::_mode_params()` (speeds, perfect_window, rope_length, swing_speed,
  pulse_min/max, wind_max, chaos_*, ...)

Redeploy backend (SEED_ON_START=1) → all clients pick it up on next launch.

## Adding a new mechanic (~15 min)

1. Add an entry to `MODES` in `scripts/Stack.gd` (title, tagline, flags).
   If the mechanic is a combination of existing flags (falls/wind/chaos over
   slide/pendulum/pulse), you're done — that's a new experiment for free.
2. New movement type? Add a branch in `_process()` (how the block moves) and,
   if placement differs, a `_place_<name>()` in `_place()`.
3. New tuning knobs? Add defaults in `_mode_params()`, override via seed.py.
4. The menu button, per-mode best, leaderboard, and analytics wire themselves up.

Ideas queued: bomb blocks (perfect defuses, sloppy destroys 2 layers),
mirror (two towers, alternating), fog (upper tower hidden), gold rush
(moving bonus zones), sudden-death (perfect-only after layer 20).

## Which mechanic wins? (read the events table)

Compare per mode: games per session (game_start count / session_start count),
average score at game_over (depth = engagement), fever rate, and D1 return
per favorite mode. Highest engagement + depth = spin it into its own game.
