#!/usr/bin/env bash
set -euo pipefail

if [[ $(uname -s) != Darwin ]]; then
  printf 'Building WinBridge.app requires macOS and Xcode.\n' >&2
  exit 1
fi

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
output="$root/dist"
app="$output/WinBridge.app"
archive="$output/WinBridge-arm64.zip"
mkdir -p "$app/Contents/MacOS"
xcrun swift build --package-path "$root/macOS" --configuration release --arch arm64
bin=$(xcrun swift build --package-path "$root/macOS" --configuration release --arch arm64 --show-bin-path)
install -m 755 "$bin/WinBridge" "$app/Contents/MacOS/WinBridge"
install -m 644 "$root/macOS/Info.plist" "$app/Contents/Info.plist"
plutil -lint "$app/Contents/Info.plist"
xcrun lipo "$app/Contents/MacOS/WinBridge" -verify_arch arm64

# Apple Silicon requires a valid code signature. This preview uses ad hoc signing.
codesign --force --sign - "$app"
codesign --verify --strict "$app"

# Write a fresh ZIP so removed files from a previous archive cannot persist.
temporary=$(mktemp -d "$output/.archive.XXXXXX")
trap 'rm -r -- "$temporary"' EXIT
ditto -c -k --keepParent "$app" "$temporary/WinBridge-arm64.zip"
mv -f -- "$temporary/WinBridge-arm64.zip" "$archive"
(
  cd "$output"
  shasum -a 256 WinBridge-arm64.zip > WinBridge-arm64.zip.sha256
)
printf 'Built %s and %s\n' "$app" "$archive"
