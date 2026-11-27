#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_dir="$root/tests/windows-fixtures"
output="$root/dist/windows-fixtures"
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
mkdir -p "$output/app" "$output/components"

clang --target=x86_64-pc-windows-msvc -fno-stack-protector -c "$source_dir/dependency.c" -o "$work/dependency.obj"
lld-link /dll /noentry /nodefaultlib "/out:$output/components/WinBridgeFixture.dll" \
  "/implib:$work/fixture.lib" "$work/dependency.obj"
clang --target=x86_64-pc-windows-msvc -fno-stack-protector -c "$source_dir/application.c" -o "$work/application.obj"
lld-link /entry:winbridge_main /subsystem:console /nodefaultlib "/out:$output/app/fixture.exe" \
  "$work/application.obj" "$work/fixture.lib"
lld-link /lib /machine:x64 "/def:$source_dir/gdi32.def" "/out:$work/gdi32.lib"
clang --target=x86_64-pc-windows-msvc -fno-stack-protector -c "$source_dir/font-probe.c" -o "$work/font-probe.obj"
lld-link /entry:winbridge_main /subsystem:console /nodefaultlib "/out:$output/font-probe.exe" \
  "$work/font-probe.obj" "$work/gdi32.lib"
mcs -optimize+ -out:"$output/mono-probe.exe" "$source_dir/MonoProbe.cs"
(
  cd "$source_dir"
  wixl -o "$output/fixture.msi" installer.wxs
)
