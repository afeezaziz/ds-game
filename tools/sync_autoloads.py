#!/usr/bin/env python3
"""Propagate template autoloads to every game.

    python tools/sync_autoloads.py            # sync all games
    python tools/sync_autoloads.py skystack   # sync one game

The platform autoloads (Backend, Analytics, Ads, GameState, Juice) are
duplicated into each game ON PURPOSE so every game stays standalone.
The rule from CLAUDE.md: fix bugs in template/autoload/ FIRST, then run
this to copy the fix everywhere. Each game's game_id is preserved.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME_ID_RE = re.compile(r'var game_id := "([^"]+)"')


def sync(game_dir: Path) -> None:
    gs_path = game_dir / "autoload" / "GameState.gd"
    game_id = None
    if gs_path.exists():
        m = GAME_ID_RE.search(gs_path.read_text(encoding="utf-8"))
        if m:
            game_id = m.group(1)
    for src in sorted((ROOT / "template" / "autoload").glob("*.gd")):
        text = src.read_text(encoding="utf-8")
        if src.name == "GameState.gd" and game_id:
            text = GAME_ID_RE.sub(f'var game_id := "{game_id}"', text, count=1)
        (game_dir / "autoload" / src.name).write_text(text, encoding="utf-8")
    print(f"synced {game_dir.name} (game_id={game_id})")


def main() -> int:
    wanted = sys.argv[1:] or None
    for game_dir in sorted((ROOT / "games").iterdir()):
        if not game_dir.is_dir():
            continue
        if wanted and game_dir.name not in wanted:
            continue
        sync(game_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
