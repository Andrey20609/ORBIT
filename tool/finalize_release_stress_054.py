from __future__ import annotations

import json
import re
import time
from datetime import datetime, timezone

import android_persistence_ui_052 as ui
import release_stress_054 as stress


def main() -> None:
    out = stress.ROOT / "validation" / "orbit054"
    ui.OUT = out
    ui.LABELS.update({"filament": ["Filament 3D"], "static": ["Static / Eco"]})
    ui.launch()
    stress.open_lab(10, "static-cleanup")
    ui.click_labels(ui.dump("stress-static-cleanup-lab"), "static")
    ui.click_labels(ui.dump("stress-static-cleanup-selected"), "today")
    time.sleep(6)
    ui.screenshot("android_054_static_cleanup")
    logcat = ui.adb("logcat", "-d", "-v", "time").stdout
    path = out / "runtime" / "release-stress-logcat.txt"
    previous = path.read_text(encoding="utf-8")
    separator = f"\n===== FINAL STATIC CLEANUP {datetime.now(timezone.utc).isoformat()} =====\n"
    combined = previous + separator + logcat
    path.write_text(combined, encoding="utf-8")
    matches = re.findall(r"ORBIT_FILAMENT\([^)]*\): activeViews=(\d+)(?: stats=(\{[^\n]+\}))?", combined)
    if not matches:
        raise RuntimeError("No native Filament resource counters found")
    active_views, stats = matches[-1]
    result = {
        "environment": "ANDROID_X86_EMULATOR",
        "buildType": "release",
        "finalRenderer": "Static / Eco",
        "activeViews": int(active_views),
        "nativeStats": stats or "No active native views after release",
        "status": "PASS" if active_views == "0" else "FAIL",
        "utc": datetime.now(timezone.utc).isoformat(),
    }
    (out / "runtime" / "release-static-cleanup.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(result, ensure_ascii=False), flush=True)
    if active_views != "0":
        raise SystemExit("Filament native views remain after Static cleanup")


if __name__ == "__main__":
    main()
