from __future__ import annotations

import hashlib
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit052" / "persistence"
ADB = Path(r"C:\Users\AVBur\AppData\Local\Android\Sdk\platform-tools\adb.exe")
DEVICE = "emulator-5554"
PACKAGE = "app.orbit.orbit_visual_lab"


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: capture_preferences_052.py SNAPSHOT_NAME")
    name = sys.argv[1]
    if not name.replace("-", "").replace("_", "").isalnum():
        raise SystemExit("Snapshot name must be alphanumeric with dashes/underscores")
    OUT.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        [
            str(ADB),
            "-s",
            DEVICE,
            "exec-out",
            "run-as",
            PACKAGE,
            "cat",
            "shared_prefs/FlutterSharedPreferences.xml",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    if b"ORB05 persistence" not in result.stdout:
        raise SystemExit("Expected UI-created persistence markers are absent")
    path = OUT / f"{name}.xml"
    path.write_bytes(result.stdout)
    digest = hashlib.sha256(result.stdout).hexdigest()
    (OUT / f"{name}.sha256").write_text(f"{digest}  {path.name}\n", encoding="utf-8")
    print(f"{path}: {len(result.stdout)} bytes; sha256={digest}")


if __name__ == "__main__":
    main()
