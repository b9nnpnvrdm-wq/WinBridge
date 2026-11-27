"""Reject native Wine dependencies pointing outside the macOS system and bundle."""

import os
import subprocess
import sys
from pathlib import Path

system_prefixes = ("/usr/lib/", "/System/Library/")
relative_prefixes = ("@rpath/", "@loader_path/", "@executable_path/")
macho_magic = {bytes.fromhex(value) for value in ("cffaedfe", "feedfacf", "cafebabe", "cafebabf")}

root = Path(sys.argv[1]).resolve()
if len(sys.argv) == 4:
    build_id, relocated = sys.argv[2], Path(sys.argv[3]).resolve()
else:
    build_id, relocated = None, None
checked = 0
for path in root.rglob("*"):
    if path.is_symlink():
        if not path.resolve().is_relative_to(root):
            sys.exit(f"Wine symlink escapes the runtime: {path}")
        continue
    if not path.is_file():
        continue
    with path.open("rb") as binary:
        if binary.read(4) not in macho_magic:
            continue
    checked += 1
    lines = subprocess.check_output(["otool", "-L", str(path)], text=True).splitlines()
    for line in lines[1:]:
        if not line.startswith("\t"):
            continue
        dependency = line.strip().split(" (", 1)[0]
        if dependency == build_id:
            replacement = "@loader_path/" + os.path.relpath(relocated, path.parent)
            subprocess.run(["install_name_tool", "-change", build_id, replacement, str(path)], check=True)
            dependency = replacement
        if not dependency.startswith(system_prefixes + relative_prefixes):
            sys.exit(f"{path} uses a non-portable dependency: {dependency}")
if not checked:
    sys.exit("No Wine Mach-O files found")
print(f"Checked {checked} Wine Mach-O files for non-portable dependencies.")
