# Dream Studio — Game Client (Godot 4.3+)

Godot games only. The FastAPI backend lives in the sibling `backend/` folder/repo —
a Claude Code instance working here NEVER edits the backend; if a game needs a
backend change (new endpoint, config key, catalog entry), write it down and hand
it to the backend instance/repo.

## Layout

```
game-client/
├── template/          # START HERE for every new game — copy the whole folder
└── games/
    └── skystack/      # Game #1, the reference for gameplay polish/juice
```

Each game folder is a complete standalone Godot project (open its project.godot).

## Creating a new game (the weekly ritual)

1. `cp -r template games/<newgame>` (folder name = game_id, lowercase, no spaces)
2. In the copy: set `config/name` in `project.godot`, set `game_id` in
   `autoload/GameState.gd`, set `BASE_URL` in `autoload/Backend.gd` to the
   deployed backend URL.
3. Implement the mechanic in `scripts/Gameplay.gd` honoring the contract:
   `start_game()`, `on_tap()` (or your own input), `score_changed`, `game_ended`.
   `scripts/Main.gd` (menu/HUD/game over/leaderboard/ads/analytics) usually
   needs no edits.
4. Ask the backend repo to add the game to `seed.py` (catalog + remote config).
5. Playtest, then export Android AAB (Godot docs: "Exporting for Android").

## Tools (use these instead of doing it by hand)

- `python tools/new_game.py <id> "Name"` — scaffold a new game from template/.
- `python tools/sync_autoloads.py [game]` — push template autoload fixes to
  every game (preserves each game's game_id). Run after ANY autoload change.
- `python tools/export_android.py [game] [--apk]` — batch AAB/APK export
  (needs one-time editor setup; see the script's docstring).
- `.github/workflows/android-build.yml` — CI builds on tag or manual dispatch;
  secrets documented in the file. **We test on real Android AND iOS phones** (on
  top of editor playtests), so every mechanic must hold up to touch + on-device
  perf, not just mouse/keyboard in the editor. iOS export needs a macOS runner +
  Apple dev account — add a `macos` job to the same workflow (Godot iOS export
  preset, then Xcode archive) before the first store submission; keep touch input
  and portrait layout iOS-safe (safe-area insets, notch) as a standing constraint.

## Juice (feel) rules

- All feel effects go through the `Juice` autoload: `sfx` (synthesized, no
  asset files), `flash`, `hitstop`, `popup`, `burst`, `shake2d`, `haptic`.
- Juice intensity is a REMOTE experiment: `juice_level` 0-3 in each game's
  config block (seed.py). Never hardcode intensity — read the dial, so we can
  A/B feel against retention. skystack is the reference wiring.
- Standard vocabulary: success = "chime" (+popup), big success = +"coin"
  (+hitstop), placement/hit = "thud" (+small haptic), death = "boom"
  (+red flash +shake). Keep the vocabulary consistent across games.

## Iron rules (apply to every game)

- **Offline-safe**: the game must be fully playable with the network down.
  Backend calls are fire-and-await with graceful empty fallbacks — never block
  gameplay on a request. `Backend.gd` already behaves this way; keep it so.
- **Autoloads are the platform.** `Backend.gd`, `Analytics.gd`, `Ads.gd`,
  `GameState.gd` are shared across all games. Fix bugs in template/ FIRST, then
  copy the fix into each game's autoload/ (they are duplicated by design so
  games stay standalone). Never fork their public APIs.
- Ad SDK integration happens ONLY in `Ads.gd` (currently a stub that fires
  `interstitial_closed` / `rewarded_completed` after one frame).
- Portrait 720x1280, `canvas_items` stretch, mobile renderer, touch input
  (mouse emulates touch in-editor).
- **Mobile-first: these ship to real Android/iOS phones, not just the editor.**
  Every mechanic must be fully playable by touch with VISIBLE affordances — no
  invisible tap zones. For the 3D labs use the shared `TouchControls` overlay:
  in a demo's `start()` call `add_touch_controls([{ "id", "label", "col" }, …],
  want_look, want_stick)`, then read `tc.move` (Vector2) for the stick,
  `tc.held(id)` for hold buttons, and connect `tc.action`/`tc.look`. It draws a
  floating joystick + labeled buttons + optional look region, is multitouch, and
  auto-hides on death so retry-tap still lands. Keep keyboard (`key_axis_*` +
  discrete keys) working in parallel for desktop playtesting. Never hardcode UI
  to H=1280 — TouchControls lays out from the live viewport size so it stays
  pinned to real screen edges under "expand" stretch and rotation.
- Tuning values (speed, difficulty, ad frequency…) read from
  `Backend.cfg("key", default)` with sane local defaults — so live tuning
  needs no store update. Register the keys in backend `seed.py`.
- `Analytics.track()` every meaningful moment: game_start, game_over (with
  score), fever/combo moments, crosspromo_tap, ad events. These feed the
  kill/scale decision.
- No external asset dependencies for prototypes: build scenes/shapes in code
  (see skystack). AI/asset-pack art comes AFTER a mechanic proves retention.
- GDScript style: typed where practical, tabs, snake_case; scripts must pass
  `gdparse` (pip install gdtoolkit).

## Kill/scale gate (after ~1 week of soft-launch data)

D1 retention ≥ 35% AND avg sessions/user/day ≥ 8 → keep iterating & market.
Below gate → freeze the game (leave it live, zero further work), start next.
