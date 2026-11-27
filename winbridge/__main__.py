"""WinBridge development diagnostics entry point."""

import argparse
import csv
import json
from dataclasses import asdict
from pathlib import Path

from .pe import inspect_pe
from .performance import frame_stats
from .steam import run_steam
from .wine import probe_wine


def main() -> int:
    parser = argparse.ArgumentParser(prog="winbridge")
    commands = parser.add_subparsers(dest="command", required=True)
    inspect = commands.add_parser("inspect-pe", help="report the machine declared in a PE header")
    inspect.add_argument("path", type=Path)
    probe = commands.add_parser("probe-wine", help="query the version of a trusted Wine loader")
    probe.add_argument("--wine", type=Path, help="Wine executable path (defaults to PATH lookup)")
    steam_install = commands.add_parser("steam-install", help="run Windows Steam setup in Wine")
    steam_install.add_argument("installer", type=Path)
    steam_launch = commands.add_parser("steam-launch", help="start Windows Steam or request a game")
    steam_launch.add_argument("client", type=Path, help="path to the installed Steam.exe")
    steam_launch.add_argument("--app-id", help="Steam App ID of the game to launch")
    for steam_command in (steam_install, steam_launch):
        steam_command.add_argument("--wine", required=True, type=Path, help="trusted Wine executable")
        steam_command.add_argument("--prefix", required=True, type=Path, help="dedicated Steam Wine prefix")
    steam_launch.add_argument("--metal-hud", action="store_true", help="enable the macOS Metal Performance HUD")
    stats = commands.add_parser("frame-stats", help="summarize measured frame intervals from CSV")
    stats.add_argument("path", type=Path, help="CSV containing a frame_ms column")
    stats.add_argument("--target-fps", type=float, default=60, help="frame budget target (default: 60)")
    args = parser.parse_args()

    try:
        if args.command == "inspect-pe":
            report = asdict(inspect_pe(args.path))
        elif args.command == "probe-wine":
            report = probe_wine(args.wine)
        elif args.command == "frame-stats":
            report = frame_stats(args.path, args.target_fps)
        elif args.command == "steam-install":
            return run_steam(args.wine, args.prefix, args.installer, installing=True)
        else:
            return run_steam(
                args.wine, args.prefix, args.client,
                app_id=args.app_id, metal_hud=args.metal_hud,
            )
    except (OSError, ValueError, csv.Error) as error:
        parser.exit(1, f"winbridge: {error}\n")
    print(json.dumps(report, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
