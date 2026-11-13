from __future__ import annotations

import hashlib
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOG = ROOT / "validation" / "orbit051" / "logs" / "integration-app.txt"
OUT = ROOT / "validation" / "orbit051" / "screenshots"
ADB = Path(r"C:\Users\AVBur\AppData\Local\Android\Sdk\platform-tools\adb.exe")


def capture(name: str) -> Path:
    path = OUT / name
    with path.open("wb") as stream:
        subprocess.run(
            [str(ADB), "-s", "emulator-5554", "exec-out", "screencap", "-p"],
            stdout=stream,
            check=True,
            timeout=15,
        )
    print(f"CAPTURE {name} {path.stat().st_size} bytes", flush=True)
    return path


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def wait_for(marker: str, timeout: float = 240) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if LOG.exists() and marker in LOG.read_text(encoding="utf-8", errors="replace"):
            return
        time.sleep(0.25)
    raise TimeoutError(f"Marker not observed: {marker}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    wait_for("[ORBIT device] B Rive runtime=")
    rive_t0 = capture("adb_rive_t0.png")
    time.sleep(0.8)
    rive_t2 = capture("adb_rive_t2.png")
    wait_for("[ORBIT device] C Filament initial stats=")
    filament_t0 = capture("adb_filament_t0.png")
    time.sleep(0.8)
    filament_t2 = capture("adb_filament_t2.png")
    results = {
        "rive": (sha256(rive_t0), sha256(rive_t2)),
        "filament": (sha256(filament_t0), sha256(filament_t2)),
    }
    for renderer, (first, second) in results.items():
        print(f"{renderer}_t0_sha256={first}", flush=True)
        print(f"{renderer}_t2_sha256={second}", flush=True)
        print(f"{renderer}_frames_differ={first != second}", flush=True)
    if results["rive"][0] == results["rive"][1]:
        raise SystemExit("Rive system frames are identical")
    if results["filament"][0] == results["filament"][1]:
        raise SystemExit("Filament system frames are identical")


if __name__ == "__main__":
    main()
