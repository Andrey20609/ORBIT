from __future__ import annotations

import re
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit052"
LOG = OUT / "logs" / "integration-navigation.txt"
ADB = Path(r"C:\Users\AVBur\AppData\Local\Android\Sdk\platform-tools\adb.exe")
DEVICE = "emulator-5554"


def main() -> None:
    captured = set()
    position = 0
    deadline = time.monotonic() + 360
    while time.monotonic() < deadline:
        if not LOG.exists():
            time.sleep(0.1)
            continue
        text = LOG.read_text(encoding="utf-8", errors="replace")
        chunk = text[position:]
        position = len(text)
        for name in re.findall(r"\[ORBIT device\] screenshot=\S*/(android_[^\s]+\.png)", chunk):
            if name in captured:
                continue
            path = OUT / "screenshots" / f"system_{name}"
            with path.open("wb") as stream:
                subprocess.run(
                    [str(ADB), "-s", DEVICE, "exec-out", "screencap", "-p"],
                    stdout=stream,
                    stderr=subprocess.PIPE,
                    check=True,
                )
            captured.add(name)
            print(f"system capture {len(captured)}: {path.name}", flush=True)
        if "All tests passed!" in text and len(captured) >= 36:
            break
        time.sleep(0.05)
    if len(captured) < 36:
        raise SystemExit(f"Expected 36 system captures, got {len(captured)}")


if __name__ == "__main__":
    main()
