from __future__ import annotations

import json
import re
import statistics
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit054"
ADB = Path(r"C:\Users\AVBur\AppData\Local\Android\Sdk\platform-tools\adb.exe")
DEVICE = "emulator-5554"
PACKAGE = "app.orbit.orbit_visual_lab"
ACTIVITY = f"{PACKAGE}/.MainActivity"


def adb(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [str(ADB), "-s", DEVICE, *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=True,
        text=True,
    )


def values(measurements, key: str) -> list[int]:
    return [item[key] for item in measurements if item[key] is not None]


def summary(measurements, key: str) -> dict[str, float] | None:
    items = values(measurements, key)
    if not items:
        return None
    ordered = sorted(items)
    return {
        "p50": statistics.median(ordered),
        "p95": ordered[min(len(ordered) - 1, int(len(ordered) * 0.95) - 1)],
        "min": ordered[0],
        "max": ordered[-1],
    }


def main() -> None:
    (OUT / "logs").mkdir(parents=True, exist_ok=True)
    (OUT / "runtime").mkdir(parents=True, exist_ok=True)
    (OUT / "screenshots").mkdir(parents=True, exist_ok=True)
    measurements = []
    for iteration in range(1, 11):
        adb("shell", "am", "force-stop", PACKAGE)
        adb("logcat", "-c")
        time.sleep(0.4)
        started = datetime.now(timezone.utc)
        launch = adb("shell", "am", "start", "-W", ACTIVITY).stdout
        time.sleep(6)
        logcat = adb("logcat", "-d", "-v", "time").stdout
        (OUT / "logs" / f"startup-cold-{iteration:02d}.log").write_text(
            f"utc={started.isoformat()}\n{launch}\n{logcat}", encoding="utf-8"
        )
        screenshot = OUT / "screenshots" / f"android_054_startup_cold_{iteration:02d}.png"
        with screenshot.open("wb") as stream:
            subprocess.run(
                [str(ADB), "-s", DEVICE, "exec-out", "screencap", "-p"],
                stdout=stream,
                stderr=subprocess.PIPE,
                check=True,
            )
        first = re.search(r"firstFrameMs=(\d+)", logcat)
        ready = re.search(r"dataReadyMs=(\d+)", logcat)
        interactive = re.search(r"interactiveTodayMs=(\d+)", logcat)
        total = re.search(r"TotalTime:\s*(\d+)", launch)
        wait = re.search(r"WaitTime:\s*(\d+)", launch)
        item = {
            "iteration": iteration,
            "utc": started.isoformat(),
            "dart_main_to_branded_first_frame_ms": int(first.group(1)) if first else None,
            "data_ready_ms": int(ready.group(1)) if ready else None,
            "interactive_today_ms": int(interactive.group(1)) if interactive else None,
            "am_start_total_time_ms": int(total.group(1)) if total else None,
            "am_start_wait_time_ms": int(wait.group(1)) if wait else None,
            "usable_shell_screenshot": screenshot.name,
        }
        measurements.append(item)
        print(json.dumps(item, ensure_ascii=False), flush=True)
    keys = [
        "dart_main_to_branded_first_frame_ms",
        "data_ready_ms",
        "interactive_today_ms",
        "am_start_total_time_ms",
        "am_start_wait_time_ms",
    ]
    (OUT / "runtime" / "startup-measurements.json").write_text(
        json.dumps(
            {
                "environment": "ANDROID_X86_EMULATOR",
                "device": DEVICE,
                "metrics_are_separate": True,
                "measurements": measurements,
                "summary": {key: summary(measurements, key) for key in keys},
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
