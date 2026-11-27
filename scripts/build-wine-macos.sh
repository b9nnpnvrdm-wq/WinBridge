#!/usr/bin/env bash
set -euo pipefail

if [[ $(uname -s) != Darwin || $(uname -m) != x86_64 ]]; then
  printf 'Build the bundled Wine runtime on an Intel macOS Xcode runner.\n' >&2
  exit 1
fi

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d "${RUNNER_TEMP:-/tmp}/winbridge-wine.XXXXXX")
trap 'rm -r -- "$work"' EXIT
output="$root/dist"
wine_commit=db11d0fe6a169c457e23d007e20404643d067aa8
toolchain_version=20260616
toolchain="llvm-mingw-${toolchain_version}-ucrt-macos-universal"
toolchain_sha=2cab02a2e964bd4aae981150a45985d07c657cfa8d244959eb9e2dcc5eedd7b1

mkdir -p "$output" "$work/wine-source" "$work/build" "$work/install"
git -C "$work/wine-source" init --quiet
git -C "$work/wine-source" fetch --quiet --depth=1 https://github.com/wine-mirror/wine.git "$wine_commit"
git -C "$work/wine-source" checkout --quiet --detach FETCH_HEAD
[[ $(git -C "$work/wine-source" rev-parse HEAD) == "$wine_commit" ]]
# Archive the exact patched source tree used for compilation.
git -C "$work/wine-source" apply --unidiff-zero "$root/scripts/patches/wine-idle-server.patch"
git -C "$work/wine-source" add server/main.c
patched_tree=$(git -C "$work/wine-source" write-tree)
git -C "$work/wine-source" archive --format=tar --prefix=wine-11.0/ "$patched_tree" \
  | gzip -n > "$output/wine-11.0-source.tar.gz"
curl --fail --location --retry 3 --silent --show-error \
  "https://github.com/mstorsjo/llvm-mingw/releases/download/$toolchain_version/$toolchain.tar.xz" \
  -o "$work/toolchain.tar.xz"
printf '%s  %s\n' "$toolchain_sha" "$work/toolchain.tar.xz" | shasum -a 256 --check
tar -xf "$work/toolchain.tar.xz" -C "$work"

# Keep this baseline independent of Homebrew/MacPorts runtime libraries.
export MACOSX_DEPLOYMENT_TARGET=14.0
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
export CC="$(xcrun --sdk macosx --find clang)"
export BISON="$(brew --prefix bison)/bin/bison"
export PATH="$(dirname "$BISON"):$(dirname "$CC"):$PATH:$work/$toolchain/bin"
"$BISON" --version
printf 'int main(void) { return 0; }\n' | "$CC" -x c - -o "$work/native-probe"
"$work/native-probe"
(
  cd "$work/build"
  if ! "$work/wine-source/configure" --prefix=/winbridge-wine \
    --enable-archs=i386,x86_64 --with-mingw="$work/$toolchain/bin/clang" \
    --disable-tests --disable-winebth_sys --with-coreaudio --without-x --without-wayland \
    --without-alsa --without-capi --without-cups --without-dbus --without-ffmpeg \
    --without-fontconfig --without-freetype --without-gettext --without-gphoto \
    --without-gnutls --without-gssapi --without-gstreamer --without-hwloc --without-inotify \
    --without-krb5 --without-netapi --without-opencl --without-oss --without-pcap \
    --without-pcsclite --without-pulse --without-sane --without-sdl --without-udev \
    --without-usb --without-v4l2 --without-vulkan; then
    grep -E 'error:|clang:|ld:|SDKROOT|bison:|m4:' config.log | tail -60 || true
    exit 1
  fi
  make -j"$(sysctl -n hw.ncpu)"
  make install DESTDIR="$work/install"
)
runtime="$work/install/winbridge-wine"
[[ -x "$runtime/bin/wine" && -x "$runtime/bin/wineserver" ]]
"$runtime/bin/wine" --version | grep -Fx 'wine-11.0'

# Carry the upstream notices with the runtime. Keep the exact source alongside
# the app archive when distributing and retain this build recipe in the repo.
mkdir -p "$runtime/share/licenses/wine"
for notice in LICENSE COPYING.LIB AUTHORS ANNOUNCE.md; do
  install -m 644 "$work/wine-source/$notice" "$runtime/share/licenses/wine/$notice"
done
cp "$root/docs/bundled-wine.md" "$runtime/share/licenses/wine/WinBridge.md"

# Check the selected native libraries only resolve against macOS or the bundle.
python3 "$root/scripts/audit-wine-runtime.py" "$runtime"
tar -czf "$output/WinBridge-Wine-runtime.tar.gz" -C "$runtime" bin lib share
