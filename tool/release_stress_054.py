from __future__ import annotations

import json
import time
from datetime import datetime, timezone
from pathlib import Path

import android_persistence_ui_052 as ui

ROOT = Path(__file__).resolve().parents[1]


def in_lab(root) -> bool:
    descriptions = [node.attrib.get("content-desc", "") for node in root.iter("node")]
    return any(value in {"Static / Eco", "Rive", "Filament 3D"} for value in descriptions)


def open_lab(cycle: int, renderer: str) -> None:
    root = ui.dump(f"stress-{cycle}-{renderer}-current")
    if in_lab(root):
        return
    ui.click_labels(root, "more")
    root = ui.dump(f"stress-{cycle}-{renderer}-settings")
    if in_lab(root):
        return
    ui.click_labels(root, "visual_lab")


def main() -> None:
    ui.OUT = ROOT / "validation" / "orbit054"
    (ui.OUT / "runtime").mkdir(parents=True, exist_ok=True)
    (ui.OUT / "screenshots").mkdir(parents=True, exist_ok=True)
    ui.LABELS.update({"filament": ["Filament 3D"], "static": ["Static / Eco"]})
    ui.adb("logcat", "-c")
    ui.launch()
    for cycle in range(1, 11):
        for renderer in ["static", "rive", "filament"]:
            open_lab(cycle, renderer)
            ui.click_labels(ui.dump(f"stress-{cycle}-{renderer}-lab"), renderer)
            ui.click_labels(ui.dump(f"stress-{cycle}-{renderer}-selected"), "today")
            if renderer == "filament":
                time.sleep(5)
        ui.adb("shell", "input", "keyevent", "KEYCODE_HOME")
        time.sleep(1)
        ui.adb("shell", "am", "start", "-W", ui.ACTIVITY)
        time.sleep(2)
        memory = ui.adb("shell", "dumpsys", "meminfo", ui.PACKAGE).stdout
        (ui.OUT / "runtime" / f"release-stress-memory-{cycle:02d}.txt").write_text(memory, encoding="utf-8")
        if cycle in {1, 10}:
            ui.screenshot(f"android_054_stress_{cycle}")
        print(f"release cycle {cycle}/10 complete", flush=True)
    logcat = ui.adb("logcat", "-d", "-v", "time").stdout
    (ui.OUT / "runtime" / "release-stress-logcat.txt").write_text(logcat, encoding="utf-8")
    (ui.OUT / "runtime" / "release-stress.json").write_text(
        json.dumps(
            {
                "environment": "ANDROID_X86_EMULATOR",
                "buildType": "release",
                "cycles": 10,
                "sequence": ["Static/Eco", "Rive (expected Static fallback)", "Filament", "home/resume"],
                "memoryLogs": [f"release-stress-memory-{cycle:02d}.txt" for cycle in range(1, 11)],
                "logcat": "release-stress-logcat.txt",
                "utc": datetime.now(timezone.utc).isoformat(),
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
