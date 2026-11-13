from __future__ import annotations

import hashlib
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit055" / "screenshots"
ADB = Path(r"C:\Users\AVBur\AppData\Local\Android\Sdk\platform-tools\adb.exe")
DIRECTORY = "/sdcard/Download/ORBIT_0.5.4"
SURFACES = [
    "today",
    "brain",
    "mail_inbox",
    "mail_detail",
    "mail_compose",
    "calendar",
    "tasks",
    "task_detail",
    "settings",
]
GRAPHICS = [
    "orbit_static_eco",
    "orbit_rive_motion_t0",
    "orbit_rive_motion_t2",
    "orbit_rive_balanced",
    "orbit_filament_system_t0",
    "orbit_filament_system_t2",
    "orbit_filament_balanced",
    "orbit_filament_before_low_memory_system",
    "orbit_before_low_memory",
]


def adb(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [str(ADB), "-s", "emulator-5554", *args],
        capture_output=True,
        text=True,
        check=True,
    )


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    listing = adb("shell", "ls", "-t", DIRECTORY).stdout.splitlines()
    expected = [
        f"android_{profile}_{surface}.png"
        for profile in ["one", "atelier", "flow", "zen"]
        for surface in SURFACES
    ] + [f"{name}.png" for name in GRAPHICS]
    records = []
    for canonical in expected:
        stem = Path(canonical).stem
        pattern = re.compile(rf"{re.escape(stem)}(?: \(\d+\))?\.png")
        matches = [name for name in listing if pattern.fullmatch(name)]
        if not matches:
            raise FileNotFoundError(f"No device capture for {canonical}")
        source = matches[0]
        target = OUT / canonical
        adb("pull", f"{DIRECTORY}/{source}", str(target))
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        records.append(f"{digest}  {canonical}  source={source}")
        print(records[-1], flush=True)
    (ROOT / "validation" / "orbit055" / "logs" / "integration-media-sha256.txt").write_text(
        "\n".join(records) + "\n", encoding="utf-8"
    )
    print(f"pulled={len(records)}", flush=True)


if __name__ == "__main__":
    main()
