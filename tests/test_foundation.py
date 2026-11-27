import json
import os
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from winbridge.pe import inspect_pe
from winbridge.performance import frame_stats
from winbridge.steam import run_steam
from winbridge.wine import probe_wine


def pe_header(machine, bits, flags=2):
    dos = bytearray(64)
    dos[:2] = b"MZ"
    struct.pack_into("<I", dos, 60, 64)
    optional = bytearray(96 if bits == 32 else 112)
    struct.pack_into("<H", optional, 0, 0x10B if bits == 32 else 0x20B)
    coff = struct.pack("<HHIIIHH", machine, 1, 0, 0, 0, len(optional), flags)
    return bytes(dos) + b"PE\0\0" + coff + optional + bytes(40)


class FoundationTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)

    def fixture(self, content):
        path = self.root / "Windows image.exe"
        path.write_bytes(content)
        return path

    def launcher(self, script):
        path = self.root / "Wine loader"
        path.write_text("#!/bin/sh\n" + script)
        path.chmod(0o700)
        return path

    def test_architectures(self):
        for machine, bits, label in [
            (0x014C, 32, "x86"), (0x8664, 64, "x86-64"),
            (0x01C0, 32, "arm32"), (0x01C2, 32, "arm32"),
            (0x01C4, 32, "arm32"), (0xAA64, 64, "arm64"),
            (0xA641, 64, "arm64ec"), (0xA64E, 64, "arm64x"),
            (0x9999, 64, "unknown"),
        ]:
            with self.subTest(machine=machine):
                image = inspect_pe(self.fixture(pe_header(machine, bits, 0x2002)))
                self.assertEqual((image.machine, image.bits, image.dll), (label, bits, True))

    def test_malformed_images(self):
        valid = pe_header(0x014C, 32)
        oversized_directories = bytearray(valid)
        struct.pack_into("<I", oversized_directories, 64 + 24 + 92, 1)
        bad_offset = bytearray(valid)
        struct.pack_into("<I", bad_offset, 60, 0xFFFFFFFF)
        for content in [
            b"", b"not PE", valid[:65], valid[:-41], valid[:-1],
            pe_header(0x8664, 32), pe_header(0x014C, 32, 0),
            oversized_directories, bad_offset,
        ]:
            with self.subTest(content_length=len(content)), self.assertRaises(ValueError):
                inspect_pe(self.fixture(content))

    def test_fifo_is_rejected(self):
        path = self.root / "pipe"
        os.mkfifo(path)
        with self.assertRaisesRegex(ValueError, "regular file"):
            inspect_pe(path)

    def test_wine_probe_executes_version_command(self):
        path = self.launcher('[ "$1" = "--version" ] || exit 3\nprintf "wine-11.0\\n"\n')
        self.assertEqual(probe_wine(path), {"executable": str(path), "version": "wine-11.0"})

    def test_wine_missing_from_path(self):
        with patch.dict(os.environ, {"PATH": str(self.root)}):
            with self.assertRaisesRegex(ValueError, "not found"):
                probe_wine()

    def test_wine_failure_reports_status(self):
        with self.assertRaisesRegex(ValueError, "status 7: load failed"):
            probe_wine(self.launcher("echo 'load failed' >&2\nexit 7\n"))

    def test_wine_invalid_banner(self):
        with self.assertRaisesRegex(ValueError, "version banner"):
            probe_wine(self.launcher("echo 'not wine'\n"))

    def test_wine_timeout(self):
        with self.assertRaisesRegex(ValueError, "timed out"):
            probe_wine(self.launcher("exec sleep 5\n"), timeout=0.1)

    def test_cli_json_and_error_status(self):
        path = self.fixture(pe_header(0xAA64, 64))
        command = [sys.executable, "-m", "winbridge", "inspect-pe"]
        accepted = subprocess.run([*command, str(path)], capture_output=True, check=True)
        self.assertEqual(json.loads(accepted.stdout), {
            "machine": "arm64", "machine_id": "0xaa64", "bits": 64, "dll": False,
        })
        rejected = subprocess.run([*command, str(self.root / "missing")], capture_output=True)
        self.assertEqual(rejected.returncode, 1)
        self.assertEqual(rejected.stdout, b"")
        self.assertIn(b"winbridge:", rejected.stderr)

    def test_steam_install_and_launch_use_explicit_prefix(self):
        prefix = self.root / "Steam Prefix"
        installer = self.fixture(pe_header(0x014C, 32))
        wine = self.launcher(
            'if [ "$#" -eq 1 ]; then\n'
            '  mkdir -p "$WINEPREFIX/drive_c" && touch "$WINEPREFIX/system.reg"\n'
            '  exit $?\n'
            'fi\n'
            '[ "$#" -eq 3 ] && [ "$2" = "-applaunch" ] || exit 2\n'
            '[ "$PWD" = "${1%/*}" ] || exit 3\n'
            '[ "$MTL_HUD_ENABLED" = 1 ] || exit 4\n'
            'printf "%s\\n" "$WINEPREFIX" "$1" "$3"\n'
        )
        with patch.dict(os.environ, {"WINEPREFIX": "/unused"}):
            self.assertEqual(run_steam(wine, prefix, installer, installing=True), 0)
            client = prefix / "drive_c" / "Steam.exe"
            client.write_bytes(pe_header(0x8664, 64))
            result = subprocess.run(
                [sys.executable, "-m", "winbridge", "steam-launch", str(client),
                 "--prefix", str(prefix), "--wine", str(wine), "--app-id", "00400", "--metal-hud"],
                capture_output=True, text=True, check=True,
            )
        self.assertEqual(
            result.stdout.splitlines(), [str(prefix.resolve()), str(client.resolve()), "400"],
        )

    def test_steam_rejects_invalid_launch_inputs_before_running_wine(self):
        prefix = self.root / "Steam Prefix"
        client = self.fixture(pe_header(0x8664, 64))
        wine = self.root / "missing loader"
        for app_id in ("0", "-1", "4294967296", "４００", "400 -arg"):
            with self.subTest(app_id=app_id), self.assertRaisesRegex(ValueError, "App ID"):
                run_steam(wine, prefix, client, app_id=app_id)
        with self.assertRaisesRegex(ValueError, "not initialized"):
            run_steam(wine, prefix, client, app_id="400")
        with self.assertRaisesRegex(ValueError, "x86 or x86-64"):
            run_steam(wine, prefix, self.fixture(pe_header(0xAA64, 64)), installing=True)

    def test_steam_propagates_wine_exit_status(self):
        prefix = self.root / "Steam Prefix"
        installer = self.fixture(pe_header(0x014C, 32))
        wine = self.launcher("exit 19\n")
        result = subprocess.run(
            [sys.executable, "-m", "winbridge", "steam-install", str(installer),
             "--prefix", str(prefix), "--wine", str(wine)],
            capture_output=True,
        )
        self.assertEqual(result.returncode, 19)

    def test_frame_stats_reports_tail_latency_and_frame_budget(self):
        capture = self.root / "capture.csv"
        capture.write_text("index,frame_ms\n" + "".join(
            f"{index},{interval}\n"
            for index, interval in enumerate([100, 24] + [16] * 98)
        ))
        result = subprocess.run(
            [sys.executable, "-m", "winbridge", "frame-stats", str(capture)],
            capture_output=True, text=True, check=True,
        )
        stats = json.loads(result.stdout)
        self.assertEqual(stats["frames"], 100)
        self.assertAlmostEqual(stats["average_fps"], 100_000 / 1692)
        self.assertEqual(stats["median_frame_ms"], 16)
        self.assertEqual(stats["p95_frame_ms"], 16)
        self.assertEqual(stats["p99_frame_ms"], 24)
        self.assertEqual(stats["worst_frame_ms"], 100)
        self.assertEqual(stats["frames_over_budget"], 2)
        self.assertEqual(frame_stats(capture, 30)["frames_over_budget"], 1)

    def test_frame_stats_rejects_invalid_measurements(self):
        capture = self.root / "capture.csv"
        for content in [
            "fps\n60\n", "frame_ms,frame_ms\n1,2\n", "frame_ms\n",
            "frame_ms\n0\n", "frame_ms\nnan\n", "frame_ms\ninf\n",
            "frame_ms\n1e-320\n", "index,frame_ms\n1\n",
        ]:
            with self.subTest(content=content), self.assertRaises(ValueError):
                capture.write_text(content)
                frame_stats(capture)
        capture.write_text("frame_ms\n16\n")
        for target in (0, -60, float("nan"), float("inf"), 1e-320):
            with self.subTest(target=target), self.assertRaises(ValueError):
                frame_stats(capture, target)
