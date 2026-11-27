"""Probe an explicitly selected, trusted Wine executable."""

import re
import subprocess
from pathlib import Path
from shutil import which


def probe_wine(executable: Path | None = None, *, timeout: float = 5) -> dict:
    if executable is None:
        candidate = which("wine")
        if candidate is None:
            raise ValueError("Wine was not found on PATH. Supply --wine with a trusted executable.")
        executable = Path(candidate)
    executable = executable.absolute()

    try:
        result = subprocess.run(
            [str(executable), "--version"],
            capture_output=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired as error:
        raise ValueError(f"Wine version probe timed out after {timeout:g} seconds") from error

    if result.returncode != 0:
        detail = result.stderr.strip()[:500]
        raise ValueError(f"Wine version probe exited with status {result.returncode}: {detail}")
    version = result.stdout.strip()
    if not re.fullmatch(r"wine-\d[^\r\n]*", version):
        raise ValueError("Wine did not return a recognised version banner")
    return {"executable": str(executable), "version": version}
