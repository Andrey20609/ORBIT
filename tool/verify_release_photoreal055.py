from __future__ import annotations

import hashlib
import json
from pathlib import Path

import android_persistence_ui_052 as ui
import android_theme_modes_055 as theme

ROOT = Path(__file__).resolve().parents[1]
WORK = Path("O:/orbit_visual_lab")
if not WORK.exists():
    WORK = ROOT
OUT = WORK / "validation" / "orbit055_stabilize"


def main() -> None:
    ui.OUT = OUT
    ui.LABELS.update(theme.LABELS)
    before = ui.adb(
        "exec-out",
        "run-as",
        ui.PACKAGE,
        "cat",
        "shared_prefs/FlutterSharedPreferences.xml",
    ).stdout
    before_path = OUT / "persistence" / "before-release-upgrade.xml"
    before_path.write_text(before, encoding="utf-8")
    apk = OUT / "ORBIT_0.5.5+11_android_x86_64.apk"
    install = ui.adb("install", "-r", str(apk)).stdout
    (OUT / "logs" / "photoreal-install.log").write_text(install, encoding="utf-8")
    if "Success" not in install:
        raise AssertionError(install)
    root = theme.launch_ready("release-system-today")
    ui.click_labels(root, "more")
    ui.click_labels(ui.dump("release-system-settings-root"), "graphics_quality")
    ui.adb("shell", "input", "swipe", "540", "1800", "540", "650", "500")
    root = ui.dump("release-system-settings")
    theme.assert_selected(root, "system")
    ui.screenshot("android_release_system_settings")
    ui.click_labels(root, "today")
    ui.screenshot("android_release_system_today")
    result = {
        "status": "PASS",
        "environment": "ANDROID_X86_EMULATOR",
        "installWithoutWipe": True,
        "launch": True,
        "systemThemeSelectedAfterUpgrade": True,
        "beforePreferencesSha256": hashlib.sha256(before.encode()).hexdigest(),
        "physicalArm64": "NOT RUN",
    }
    (OUT / "runtime" / "installed-release-verification.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(result, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
