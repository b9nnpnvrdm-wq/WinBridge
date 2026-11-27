#!/usr/bin/env bash
set -euo pipefail

if [[ $(uname -s) != Darwin || $(uname -m) != arm64 ]]; then
  printf 'Run this smoke test on Apple Silicon macOS.\n' >&2
  exit 1
fi
app=${1:?Provide the location of WinBridge.app.}
runtime="$app/Contents/SharedSupport/Wine"
wine="$runtime/bin/wine"
work=$(mktemp -d "${RUNNER_TEMP:-/tmp}/winbridge-smoke.XXXXXX")
export WINEPREFIX="$work/prefix"
export WINEDLLOVERRIDES="mscoree,mshtml="
export WINEDEBUG=-all
cleanup() {
  "$runtime/bin/wineserver" -k || true
  "$runtime/bin/wineserver" -w || true
  rm -r -- "$work"
}
trap cleanup EXIT

python3 - "$wine" <<'PYTHON'
import subprocess
import sys
import time
from pathlib import Path

wine = sys.argv[1]
server = Path(wine).with_name("wineserver")
assert subprocess.check_output([wine, "--version"], text=True).strip() == "wine-11.0"

def run_command(path, marker):
    start = time.monotonic()
    output = subprocess.check_output([wine, path, "/d", "/c", f"echo {marker}"], text=True)
    assert output.strip() == marker, output
    elapsed = time.monotonic() - start
    print(f"{marker} ({elapsed:.2f} s)", flush=True)

run_command(r"C:\windows\system32\cmd.exe", "WINBRIDGE_X64_FRESH_PREFIX")
watcher = subprocess.Popen([server, "-w"])
try:
    time.sleep(6)
    assert watcher.poll() is None, "Wine server exited during the idle launch window"
    run_command(r"C:\windows\system32\cmd.exe", "WINBRIDGE_X64_WARM_PREFIX")
    run_command(r"C:\windows\syswow64\cmd.exe", "WINBRIDGE_X86_WARM_PREFIX")
finally:
    if watcher.poll() is None:
        watcher.terminate()
    watcher.wait()
PYTHON
