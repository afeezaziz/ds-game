#!/usr/bin/env python3
"""Batch-export Android builds for one or all games.

    python tools/export_android.py                # AAB for every game
    python tools/export_android.py skystack       # one game
    python tools/export_android.py skystack --apk # debug APK for device testing

One-time setup per machine (10 min, in the Godot editor):
  1. Editor > Manage Export Templates: install templates for your Godot version.
  2. Editor Settings > Export > Android: point at Android SDK + a debug keystore.
  3. Open each game once: Project > Export > Add > Android; set the package
     name to com.dreamstudio.<game_id>. This writes export_presets.cfg
     (gitignored — it can reference keystore paths, keep it local/CI-secret).

Outputs land in build/<game_id>.aab (or .apk). Upload the AAB in Play Console
(internal testing track first). First upload per app is always manual;
after that, CI can push updates (see .github/workflows/android-build.yml).
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT = "godot"  # or full path to the Godot 4.x binary


def export(game: str, apk: bool) -> bool:
    game_dir = ROOT / "games" / game
    if not (game_dir / "export_presets.cfg").exists():
        print(f"[skip] {game}: no export_presets.cfg (create the Android preset in the editor once)")
        return False
    out_dir = ROOT / "build"
    out_dir.mkdir(exist_ok=True)
    out = out_dir / (f"{game}.apk" if apk else f"{game}.aab")
    mode = "--export-debug" if apk else "--export-release"
    cmd = [GODOT, "--headless", "--path", str(game_dir), mode, "Android", str(out)]
    print(">", " ".join(cmd))
    res = subprocess.run(cmd)
    ok = res.returncode == 0 and out.exists()
    print(f"[{'ok' if ok else 'FAIL'}] {out}")
    return ok


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    apk = "--apk" in sys.argv
    games = args or sorted(p.name for p in (ROOT / "games").iterdir() if p.is_dir())
    failures = [g for g in games if not export(g, apk)]
    if failures:
        print("failed/skipped:", ", ".join(failures))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
