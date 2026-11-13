from __future__ import annotations

import json
import re
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit052"
ADB = Path(r"C:\Users\AVBur\AppData\Local\Android\Sdk\platform-tools\adb.exe")
DEVICE = "emulator-5554"
PACKAGE = "app.orbit.orbit_visual_lab"
ACTIVITY = f"{PACKAGE}/.MainActivity"


def adb(*args: str, binary: bool = False) -> subprocess.CompletedProcess:
    return subprocess.run(
        [str(ADB), "-s", DEVICE, *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=True,
        text=not binary,
    )


def main() -> None:
    logs = OUT / "logs"
    screenshots = OUT / "screenshots"
    logs.mkdir(parents=True, exist_ok=True)
    screenshots.mkdir(parents=True, exist_ok=True)
    measurements = []
    for iteration in range(1, 4):
        adb("shell", "am", "force-stop", PACKAGE)
        adb("logcat", "-c")
        time.sleep(0.5)
        started = datetime.now(timezone.utc)
        launch = adb("shell", "am", "start", "-W", ACTIVITY).stdout
        time.sleep(4)
        logcat = adb("logcat", "-d", "-v", "time").stdout
        (logs / f"startup-cold-{iteration}.log").write_text(
            f"utc={started.isoformat()}\n{launch}\n{logcat}",
            encoding="utf-8",
        )
        with (screenshots / f"android_startup_cold_{iteration}.png").open("wb") as stream:
            subprocess.run(
                [str(ADB), "-s", DEVICE, "exec-out", "screencap", "-p"],
                stdout=stream,
                stderr=subprocess.PIPE,
                check=True,
            )
        first_frame = re.search(r"firstFrameMs=(\d+)", logcat)
        total_time = re.search(r"TotalTime:\s*(\d+)", launch)
        wait_time = re.search(r"WaitTime:\s*(\d+)", launch)
        measurement = {
            "iteration": iteration,
            "utc": started.isoformat(),
            "dart_main_to_first_flutter_frame_ms": int(first_frame.group(1)) if first_frame else None,
            "am_start_total_time_ms": int(total_time.group(1)) if total_time else None,
            "am_start_wait_time_ms": int(wait_time.group(1)) if wait_time else None,
            "usable_shell_screenshot": f"android_startup_cold_{iteration}.png",
        }
        measurements.append(measurement)
        print(json.dumps(measurement, ensure_ascii=False))
    (logs / "startup-measurements.json").write_text(
        json.dumps(
            {
                "device": DEVICE,
                "package": PACKAGE,
                "metrics_are_separate": True,
                "measurements": measurements,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
