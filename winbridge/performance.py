"""Summarize measured frame intervals from a normalized CSV capture."""

import csv
import math
from pathlib import Path


def frame_stats(path: Path, target_fps: float = 60) -> dict:
    if not math.isfinite(target_fps) or target_fps <= 0:
        raise ValueError("target FPS must be finite and positive")
    budget_ms = 1000 / target_fps
    if not math.isfinite(budget_ms):
        raise ValueError("target FPS is too small to compute a frame budget")

    frames = []
    with path.open(encoding="utf-8-sig", newline="") as capture:
        reader = csv.DictReader(capture, strict=True)
        if (reader.fieldnames or []).count("frame_ms") != 1:
            raise ValueError("CSV must contain exactly one frame_ms column")
        for row in reader:
            try:
                interval = float(row["frame_ms"])
            except (TypeError, ValueError):
                raise ValueError(f"invalid frame interval on CSV line {reader.line_num}") from None
            if not math.isfinite(interval) or interval <= 0:
                raise ValueError(f"frame interval must be finite and positive on CSV line {reader.line_num}")
            frames.append(interval)
    if not frames:
        raise ValueError("CSV contains no frame intervals")

    frames.sort()
    count = len(frames)
    peak_ms = frames[-1]
    mean_ms = peak_ms * (math.fsum(interval / peak_ms for interval in frames) / count)
    average_fps = 1000 / mean_ms
    lower_middle = frames[(count - 1) // 2]
    median_ms = lower_middle + (frames[count // 2] - lower_middle) / 2
    if not math.isfinite(average_fps):
        raise ValueError("frame intervals are too small to compute average FPS")
    return {
        "frames": count,
        "average_fps": average_fps,
        "median_frame_ms": median_ms,
        "p95_frame_ms": frames[(95 * count + 99) // 100 - 1],
        "p99_frame_ms": frames[(99 * count + 99) // 100 - 1],
        "worst_frame_ms": peak_ms,
        "target_fps": target_fps,
        "budget_ms": budget_ms,
        "frames_over_budget": sum(interval > budget_ms for interval in frames),
    }
