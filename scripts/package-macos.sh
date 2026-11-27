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
wine_archive=${1:-"$output/WinBridge-Wine-runtime.tar.gz"}
[[ -f "$wine_archive" ]] || {
  printf 'Supply the Wine runtime archive built by scripts/build-wine-macos.sh.\n' >&2
  exit 1
}
mkdir -p "$output"
temporary=$(mktemp -d "$output/.package.XXXXXX")
trap 'rm -r -- "$temporary"' EXIT
staged_app="$temporary/WinBridge.app"
shared="$staged_app/Contents/SharedSupport"
mkdir -p "$staged_app/Contents/MacOS" "$staged_app/Contents/Frameworks" "$staged_app/Contents/Resources" "$shared/Wine"
iconset="$temporary/WinBridge.iconset"
mkdir "$iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$root/macOS/Assets/WinBridge.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$root/macOS/Assets/WinBridge.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$staged_app/Contents/Resources/WinBridge.icns"

xcrun swift build --package-path "$root/macOS" --configuration release --arch arm64
bin=$(xcrun swift build --package-path "$root/macOS" --configuration release --arch arm64 --show-bin-path)
install -m 755 "$bin/WinBridge" "$staged_app/Contents/MacOS/WinBridge"
plist="$staged_app/Contents/Info.plist"
install -m 644 "$root/macOS/Info.plist" "$plist"

# The pinned Sparkle SwiftPM artifact is a universal dynamic XCFramework.
sparkle=$(find "$root/macOS/.build/artifacts" -type d -name Sparkle.framework -print -quit)
[[ -n "$sparkle" ]] || { printf 'Missing resolved Sparkle framework.\n' >&2; exit 1; }
ditto "$sparkle" "$staged_app/Contents/Frameworks/Sparkle.framework"
install -m 644 "$root/macOS/ThirdParty/Sparkle-LICENSE.txt" "$shared/Sparkle-LICENSE.txt"
tar -xf "$wine_archive" -C "$shared/Wine"

export WINBRIDGE_BUILD_NUMBER="${WINBRIDGE_BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-1}}"
python3 "$root/scripts/configure-app-plist.py" "$plist"
plutil -lint "$plist"
xcrun lipo "$staged_app/Contents/MacOS/WinBridge" -verify_arch arm64
xcrun lipo "$shared/Wine/bin/wine" -verify_arch x86_64

# The preview is ad hoc signed. Sparkle keeps its own upstream nested signatures.
codesign --force --sign - "$staged_app"
codesign --verify --deep --strict "$staged_app"

if [[ -e "$app" ]]; then
  rm -r -- "$app"
fi
mv -- "$staged_app" "$app"
ditto -c -k --keepParent "$app" "$temporary/WinBridge-arm64.zip"
mv -f -- "$temporary/WinBridge-arm64.zip" "$archive"
(
  cd "$output"
  shasum -a 256 WinBridge-arm64.zip > WinBridge-arm64.zip.sha256
)
printf 'Built %s and %s\n' "$app" "$archive"
