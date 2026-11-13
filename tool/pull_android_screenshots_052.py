from __future__ import annotations

import hashlib
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit052" / "screenshots"
ADB = Path(r"C:\Users\AVBur\AppData\Local\Android\Sdk\platform-tools\adb.exe")
DEVICE = "emulator-5554"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    pulled = []
    sources = [
        ("/sdcard/Download/ORBIT_0.5", ("android_compact200_",)),
        ("/sdcard/Download/ORBIT_0.5.2", ("android_", "orbit_")),
    ]
    for directory, prefixes in sources:
        listing = subprocess.run(
            [str(ADB), "-s", DEVICE, "shell", "ls", directory],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        for name in listing.splitlines():
            name = name.strip()
            if not name.endswith(".png") or not name.startswith(prefixes):
                continue
            destination = OUT / name
            subprocess.run(
                [str(ADB), "-s", DEVICE, "pull", f"{directory}/{name}", str(destination)],
                check=True,
                stdout=subprocess.DEVNULL,
            )
            pulled.append(destination)
    manifest = ROOT / "validation" / "orbit052" / "logs" / "android-screenshot-sha256.txt"
    lines = []
    for path in sorted(set(pulled)):
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        lines.append(f"{digest}  {path.name}  {path.stat().st_size} bytes")
    manifest.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"pulled={len(set(pulled))} manifest={manifest}")


if __name__ == "__main__":
    main()
