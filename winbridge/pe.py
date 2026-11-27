"""Read Windows PE image headers without loading executable code."""

import os
import stat
import struct
from dataclasses import dataclass
from pathlib import Path

MACHINES = {
    0x014C: ("x86", 32),
    0x8664: ("x86-64", 64),
    0x01C0: ("arm32", 32),
    0x01C2: ("arm32", 32),
    0x01C4: ("arm32", 32),
    0xAA64: ("arm64", 64),
    0xA641: ("arm64ec", 64),
    0xA64E: ("arm64x", 64),
}


@dataclass(frozen=True)
class PEImage:
    machine: str
    machine_id: str
    bits: int
    dll: bool


def inspect_pe(path: Path) -> PEImage:
    # Open nonblocking so a named pipe cannot stall inspection.
    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
    with os.fdopen(fd, "rb") as image:
        info = os.fstat(image.fileno())
        if not stat.S_ISREG(info.st_mode):
            raise ValueError("expected a regular file")

        dos = image.read(64)
        if len(dos) != 64 or dos[:2] != b"MZ":
            raise ValueError("missing or truncated DOS header")

        (offset,) = struct.unpack_from("<I", dos, 60)
        if offset < len(dos) or offset + 24 > info.st_size:
            raise ValueError("PE header offset is outside the image")
        image.seek(offset)
        header = image.read(24)
        if len(header) != 24 or header[:4] != b"PE\0\0":
            raise ValueError("missing or truncated PE signature and COFF header")

        machine, sections, _, _, _, optional_size, flags = struct.unpack_from(
            "<HHIIIHH", header, 4
        )
        if not flags & 0x0002 or sections == 0:
            raise ValueError("COFF header does not describe an executable image")
        optional = image.read(optional_size)
        if len(optional) != optional_size or len(optional) < 2:
            raise ValueError("missing or truncated PE optional header")
        (magic,) = struct.unpack_from("<H", optional)
        if magic == 0x10B:
            bits, fixed_size = 32, 96
        elif magic == 0x20B:
            bits, fixed_size = 64, 112
        else:
            raise ValueError(f"unsupported PE optional-header magic 0x{magic:04x}")
        if optional_size < fixed_size:
            raise ValueError("truncated PE optional header")
        (directories,) = struct.unpack_from("<I", optional, fixed_size - 4)
        if directories > (optional_size - fixed_size) // 8:
            raise ValueError("PE data directories exceed the optional header")
        if image.tell() + sections * 40 > info.st_size:
            raise ValueError("truncated PE section table")

        name, expected_bits = MACHINES.get(machine, ("unknown", bits))
        if bits != expected_bits:
            raise ValueError("COFF machine and PE optional header disagree")
        return PEImage(name, f"0x{machine:04x}", bits, bool(flags & 0x2000))
