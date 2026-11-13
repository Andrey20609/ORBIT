from __future__ import annotations

import time

import android_persistence_ui_052 as ui
from capture_release_screens_052 import PROFILES, click_contains


def main() -> None:
    ui.LABELS.update({"interface": ["Интерфейс", "Interface", "Oberfläche", "Interfaz"]})
    for profile in ["one", "atelier", "flow"]:
        ui.click_labels(ui.dump(f"settings-{profile}-branch"), "more")
        ui.click_labels(ui.dump(f"settings-{profile}-root"), "more")
        ui.click_labels(ui.dump(f"settings-{profile}-interface"), "interface")
        gallery = ui.dump(f"settings-{profile}-gallery")
        if profile == "flow":
            ui.adb("shell", "input", "swipe", "540", "1800", "540", "650", "600")
            time.sleep(2)
            gallery = ui.dump(f"settings-{profile}-gallery-scrolled")
        click_contains(gallery, PROFILES[profile])
        ui.click_labels(ui.dump(f"settings-{profile}-selected"), "more")
        ui.screenshot(f"release_{profile}_settings")
        print(f"{profile}: Settings root captured", flush=True)


if __name__ == "__main__":
    main()
