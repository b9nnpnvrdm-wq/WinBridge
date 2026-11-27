#!/usr/bin/env bash
set -euo pipefail

# The runner has an isolated macOS account. Do not change a local user's settings.
[[ ${GITHUB_ACTIONS:-false} == true ]]
app=${1:?Provide the WinBridge app path.}
exe=${2:?Provide a Windows EXE fixture.}
catalog="$HOME/Library/Application Support/WinBridge/Applications.json"
test ! -e "$catalog"
defaults write com.winbridge.preview didFinishEngineSetup -bool true
defaults write com.winbridge.preview useBundledWine -bool true

# Launch Services delivers the same open-document event as Finder Open With.
open -g -a "$app" "$exe"
python3 - "$catalog" "$exe" <<'PYTHON'
import json
import pathlib
import sys
import time

catalog, executable = map(pathlib.Path, sys.argv[1:])
expected = str(executable.resolve())
deadline = time.monotonic() + 45
while time.monotonic() < deadline:
    if catalog.exists():
        profiles = json.loads(catalog.read_text())
        matches = [profile for profile in profiles if profile["executable"] == expected]
        if len(matches) == 1:
            print("Finder open event persisted one EXE profile.", flush=True)
            break
    time.sleep(1)
else:
    sys.exit("Finder open event did not populate the Windows Apps catalog")
PYTHON
