#!/usr/bin/env python3
"""Scaffold a new game from the template in one command.

    python tools/new_game.py <game_id> "Display Name"

Example:
    python tools/new_game.py neonhop "Neon Hop"

Does: copies template/ -> games/<game_id>/, sets game_id in GameState.gd
and config/name in project.godot, then prints the remaining checklist.
"""
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    game_id, name = sys.argv[1], sys.argv[2]
    if not re.fullmatch(r"[a-z][a-z0-9_]{2,30}", game_id):
        print("game_id must be lowercase letters/digits/underscore, 3-31 chars")
        return 1
    src = ROOT / "template"
    dst = ROOT / "games" / game_id
    if dst.exists():
        print(f"{dst} already exists — aborting")
        return 1

    shutil.copytree(src, dst, ignore=shutil.ignore_patterns(".godot"))

    gs = dst / "autoload" / "GameState.gd"
    gs.write_text(
        gs.read_text(encoding="utf-8").replace('var game_id := "CHANGE_ME"',
                                               f'var game_id := "{game_id}"'),
        encoding="utf-8")

    pg = dst / "project.godot"
    pg.write_text(
        pg.read_text(encoding="utf-8").replace('config/name="NEW GAME NAME"',
                                               f'config/name="{name}"'),
        encoding="utf-8")

    print(f"Created games/{game_id} ({name}). Remaining checklist:")
    print(f"  1. backend/seed.py: add catalog entry + config block for '{game_id}', redeploy")
    print(f"  2. games/{game_id}/autoload/Backend.gd: set BASE_URL to the deployed backend")
    print(f"  3. Implement the mechanic in scripts/Gameplay.gd (see the contract at its top)")
    print(f"  4. Open games/{game_id}/project.godot in Godot and press F5")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
