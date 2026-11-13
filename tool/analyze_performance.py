#!/usr/bin/env python3
"""Calculate metrics only from an existing ORBIT raw performance directory."""
from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    position = (len(ordered) - 1) * fraction
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    return ordered[lower] * (upper - position) + ordered[upper] * (position - lower)


def frame_times(path: Path) -> list[float]:
    lines = path.read_text(errors="replace").splitlines()
    if re.search(r"Total frames rendered:\s*0(?:\D|$)", "\n".join(lines)):
        return []
    header_index = next(
        (
            index
            for index, line in enumerate(lines)
            if "HandleInputStart" in line and "FrameCompleted" in line
        ),
        None,
    )
    if header_index is None:
        return []
    headers = [item.strip() for item in lines[header_index].split(",")]
    try:
        start_index = headers.index("HandleInputStart")
        end_index = headers.index("FrameCompleted")
    except ValueError:
        return []
    values: list[float] = []
    for line in lines[header_index + 1 :]:
        if "---PROFILEDATA---" in line:
            continue
        columns = [item.strip() for item in line.split(",")]
        if len(columns) <= max(start_index, end_index):
            continue
        try:
            start = int(columns[start_index])
            end = int(columns[end_index])
        except ValueError:
            continue
        duration_ms = (end - start) / 1_000_000
        if start > 0 and end > start and duration_ms <= 5000:
            values.append(duration_ms)
    return values


def pss_values(directory: Path) -> list[float]:
    values: list[float] = []
    paths = sorted((directory / "samples").glob("*.txt"))
    after = directory / "meminfo-after.txt"
    if after.exists():
        paths.append(after)
    pattern = re.compile(r"^\s*TOTAL\s+PSS:\s*(\d+)", re.MULTILINE | re.IGNORECASE)
    for path in paths:
        match = pattern.search(path.read_text(errors="replace"))
        if match:
            values.append(int(match.group(1)) / 1024)
    return values


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("capture", type=Path)
    parser.add_argument(
        "--budget-ms",
        type=float,
        required=True,
        help="Explicit jank budget, e.g. 33.33 for Balanced or 16.67 for Ultra",
    )
    args = parser.parse_args()
    if not args.capture.is_dir() or args.budget_ms <= 0:
        raise SystemExit("A raw capture directory and positive --budget-ms are required")

    frames = frame_times(args.capture / "gfxinfo-framestats.txt")
    memory = pss_values(args.capture)
    result: dict[str, object] = {
        "schemaVersion": 2,
        "status": "OK" if frames else "NO_VALID_FRAMES",
        "captureDirectory": str(args.capture),
        "frameTimeSource": "gfxinfo FrameCompleted-HandleInputStart; positive <= 5000 ms",
        "jankBudgetMs": args.budget_ms,
        "frameSampleCount": len(frames),
        "memorySampleCount": len(memory),
        "sourceFiles": [
            "gfxinfo-framestats.txt",
            "samples/*.txt",
            "meminfo-after.txt",
        ],
    }
    if frames:
        result["frameTimeMs"] = {
            "p50": percentile(frames, 0.50),
            "p95": percentile(frames, 0.95),
            "p99": percentile(frames, 0.99),
            "min": min(frames),
            "max": max(frames),
        }
        result["jankPercent"] = 100 * sum(value > args.budget_ms for value in frames) / len(frames)
    else:
        result["frameTimeMs"] = "NOT MEASURED: no parsable frame records"
        result["jankPercent"] = "NOT MEASURED"
    if memory:
        result["ramPssMiB"] = {
            "median": percentile(memory, 0.50),
            "p95": percentile(memory, 0.95),
            "max": max(memory),
        }
    else:
        result["ramPssMiB"] = "NOT MEASURED: no TOTAL PSS samples"

    output = args.capture / "derived-metrics.json"
    output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps(result, indent=2, ensure_ascii=False))
    if not frames:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
