from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit054" / "screenshots"
ADB = Path(r"C:\Users\AVBur\AppData\Local\Android\Sdk\platform-tools\adb.exe")
DIRECTORY = "/sdcard/Download/ORBIT_0.5.4"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    listing = subprocess.run(
        [str(ADB), "-s", "emulator-5554", "shell", "ls", DIRECTORY],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    count = 0
    for name in listing.splitlines():
        name = name.strip()
        if not name.endswith(".png") or not name.startswith(("android_", "orbit_")):
            continue
        subprocess.run(
            [str(ADB), "-s", "emulator-5554", "pull", f"{DIRECTORY}/{name}", str(OUT / name)],
            check=True,
            stdout=subprocess.DEVNULL,
        )
        count += 1
    print(f"pulled={count}")


if __name__ == "__main__":
    main()
