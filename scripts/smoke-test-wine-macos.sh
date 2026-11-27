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

"$wine" --version | grep -Fx 'wine-11.0'
"$wine" 'C:\windows\system32\cmd.exe' /d /c 'echo WINBRIDGE_X64_OK' | tr -d '\r' | grep -Fx WINBRIDGE_X64_OK
"$wine" 'C:\windows\syswow64\cmd.exe' /d /c 'echo WINBRIDGE_X86_OK' | tr -d '\r' | grep -Fx WINBRIDGE_X86_OK
