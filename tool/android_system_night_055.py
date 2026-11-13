from __future__ import annotations

import hashlib
import json
import time
from pathlib import Path

from PIL import Image, ImageStat

import android_persistence_ui_052 as ui
import android_theme_modes_055 as theme
from capture_release_screens_052 import PROFILES, click_contains

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit055_stabilize"


def luminance(name: str) -> float:
    with Image.open(OUT / "screenshots" / f"{name}.png") as image:
        return ImageStat.Stat(image.convert("L").crop((0, 0, 1080, 1800))).mean[0]


def main() -> None:
    ui.OUT = OUT
    ui.LABELS.update(theme.LABELS)
    ui.LABELS["interface"] = ["Интерфейс", "Interface", "Oberfläche", "Interfaz"]
    original = ui.adb("shell", "cmd", "uimode", "night").stdout.strip()
    target = "no" if "yes" in original else "yes"
    result = {"original": original, "temporaryTarget": target, "physicalArm64": "NOT RUN"}
    try:
        root = theme.launch_ready("system-night-before-launch")
        ui.click_labels(root, "more")
        ui.click_labels(ui.dump("system-night-settings-root"), "interface")
        ui.adb("shell", "input", "swipe", "540", "1800", "540", "700", "500")
        time.sleep(1)
        click_contains(ui.dump("system-night-gallery"), PROFILES["flow"])
        ui.click_labels(ui.dump("system-night-selected"), "today")
        ui.click_labels(ui.dump("system-night-more"), "more")
        ui.adb("shell", "input", "keyevent", "KEYCODE_BACK")
        time.sleep(1)
        ui.click_labels(ui.dump("system-night-personalization-root"), "graphics_quality")
        ui.adb("shell", "input", "swipe", "540", "1800", "540", "650", "500")
        personalization = ui.dump("system-night-personalization")
        theme.assert_selected(personalization, "system")
        ui.click_labels(personalization, "today")
        ui.screenshot("android_system_night_before")
        ui.adb("shell", "cmd", "uimode", "night", target)
        time.sleep(4)
        ui.screenshot("android_system_night_after")
        before_path = OUT / "screenshots" / "android_system_night_before.png"
        after_path = OUT / "screenshots" / "android_system_night_after.png"
        before_hash = hashlib.sha256(before_path.read_bytes()).hexdigest()
        after_hash = hashlib.sha256(after_path.read_bytes()).hexdigest()
        before_luma = luminance("android_system_night_before")
        after_luma = luminance("android_system_night_after")
        ratio = max(before_luma, after_luma) / min(before_luma, after_luma)
        if before_hash == after_hash or ratio < 1.5:
            raise AssertionError(
                f"System Night mode did not switch the Flow scene: luminance {before_luma} -> {after_luma}"
            )
        result.update(
            {
                "environment": "ANDROID_X86_EMULATOR",
                "status": "PASS",
                "profile": "flow",
                "beforeSha256": before_hash,
                "afterSha256": after_hash,
                "beforeLuminance": before_luma,
                "afterLuminance": after_luma,
                "luminanceRatio": ratio,
                "sceneChanged": True,
            }
        )
    finally:
        restore = "yes" if "yes" in original else "no"
        ui.adb("shell", "cmd", "uimode", "night", restore)
        result["restored"] = restore
        time.sleep(2)
        (OUT / "runtime" / "system-night-toggle.json").write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    print(json.dumps(result, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
