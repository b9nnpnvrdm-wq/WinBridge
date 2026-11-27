"""Start the Windows Steam installer or client through a supplied Wine engine."""

import os
import subprocess
from pathlib import Path

from .pe import inspect_pe


def steam_app_id(value: str) -> str:
    if not 1 <= len(value) <= 10 or not value.isascii() or not value.isdecimal():
        raise ValueError("Steam App ID must be a positive 32-bit decimal integer")
    number = int(value)
    if not 1 <= number <= 0xFFFFFFFF:
        raise ValueError("Steam App ID must be a positive 32-bit decimal integer")
    return str(number)


def run_steam(
    wine: Path,
    prefix: Path,
    executable: Path,
    *,
    installing: bool = False,
    app_id: str | None = None,
    metal_hud: bool = False,
) -> int:
    if app_id is not None:
        app_id = steam_app_id(app_id)
    wine = wine.expanduser().absolute()
    prefix = prefix.expanduser().resolve()
    executable = executable.expanduser().resolve()
    image = inspect_pe(executable)
    if image.dll or image.machine not in {"x86", "x86-64"}:
        raise ValueError("expected a Windows x86 or x86-64 executable for Steam")
    if prefix.exists() and not prefix.is_dir():
        raise ValueError("Wine prefix path must be a directory")

    initialized = (prefix / "system.reg").is_file() and (prefix / "drive_c").is_dir()
    if installing:
        if app_id is not None:
            raise ValueError("Steam setup does not take a game App ID")
        if not prefix.parent.is_dir():
            raise ValueError("create the Wine prefix's parent directory first")
        if not initialized and prefix.exists() and any(prefix.iterdir()):
            raise ValueError("choose a new, empty, or initialized Wine prefix")
    elif not initialized:
        raise ValueError("Wine prefix is not initialized. Run steam-install first.")

    command = [str(wine), str(executable)]
    if app_id is not None:
        command.extend(["-applaunch", app_id])
    environment = dict(os.environ, WINEPREFIX=str(prefix))
    if metal_hud:
        environment["MTL_HUD_ENABLED"] = "1"
    result = subprocess.run(
        command, cwd=executable.parent, env=environment, check=False,
    )
    if result.returncode < 0:
        raise ValueError(f"Wine process terminated by signal {-result.returncode}")
    return result.returncode
