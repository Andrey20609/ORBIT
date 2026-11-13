from __future__ import annotations

import json
import time
from pathlib import Path

import android_persistence_ui_052 as ui
import android_theme_modes_055 as theme
from capture_release_screens_052 import PROFILES, click_contains

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit055_stabilize"


def main() -> None:
    ui.OUT = OUT
    ui.LABELS.update(theme.LABELS)
    ui.LABELS.update(
        {
            "interface": ["Интерфейс", "Interface", "Oberfläche", "Interfaz"],
            "mail": ["Почта", "Mail", "E-Mail", "Courrier", "Correo"],
        }
    )
    records = []
    for mode in ["light", "dark", "system"]:
        root = theme.launch_ready(f"matrix-{mode}-launch")
        ui.click_labels(root, "more")
        ui.click_labels(ui.dump(f"matrix-{mode}-settings-root"), "graphics_quality")
        ui.adb("shell", "input", "swipe", "540", "1800", "540", "650", "500")
        ui.click_labels(ui.dump(f"matrix-{mode}-personalization"), mode)
        ui.adb("shell", "input", "keyevent", "KEYCODE_BACK")
        time.sleep(1)
        for index, profile in enumerate(PROFILES):
            if index > 0:
                ui.click_labels(ui.dump(f"matrix-{mode}-{profile}-today-before"), "today")
                ui.click_labels(ui.dump(f"matrix-{mode}-{profile}-more"), "more")
                ui.adb("shell", "input", "keyevent", "KEYCODE_BACK")
                time.sleep(1)
            ui.click_labels(ui.dump(f"matrix-{mode}-{profile}-settings"), "interface")
            gallery = ui.dump(f"matrix-{mode}-{profile}-gallery")
            if profile in {"flow", "zen"}:
                ui.adb("shell", "input", "swipe", "540", "1800", "540", "700", "500")
                time.sleep(1)
                gallery = ui.dump(f"matrix-{mode}-{profile}-gallery-scrolled")
            click_contains(gallery, PROFILES[profile])
            ui.click_labels(ui.dump(f"matrix-{mode}-{profile}-selected"), "today")
            today = f"android_{mode}_{profile}_today"
            ui.screenshot(today)
            records.append({"mode": mode, "profile": profile, "screen": "today", "file": f"{today}.png"})
            if profile == "flow":
                for group, screen in [
                    ("mail", "mail"),
                    ("calendar", "calendar"),
                    ("tasks", "tasks"),
                    ("more", "settings"),
                ]:
                    ui.click_labels(ui.dump(f"matrix-{mode}-flow-before-{screen}"), group)
                    name = f"android_{mode}_flow_{screen}"
                    ui.screenshot(name)
                    records.append({"mode": mode, "profile": profile, "screen": screen, "file": f"{name}.png"})
    (OUT / "runtime" / "profile-theme-matrix.json").write_text(
        json.dumps(
            {
                "environment": "ANDROID_X86_EMULATOR; physical ARM64 NOT RUN",
                "status": "CAPTURED",
                "screenshotCount": len(records),
                "records": records,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"Captured {len(records)} profile/theme/screen images", flush=True)


if __name__ == "__main__":
    main()
