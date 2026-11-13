from __future__ import annotations

import sys
import time
import xml.etree.ElementTree as ET

import android_persistence_ui_052 as ui

PROFILES = {"one": "ORBIT One", "atelier": "ORBIT Atelier", "flow": "ORBIT Flow", "zen": "ORBIT Zen"}


def click_contains(root: ET.Element, text: str) -> None:
    matches = [
        node
        for node in root.iter("node")
        if node.attrib.get("clickable") == "true"
        and (
            text in node.attrib.get("text", "")
            or text in node.attrib.get("content-desc", "")
        )
    ]
    if not matches:
        raise RuntimeError(f"Clickable text {text!r} not found")
    x, y = ui.center(matches[-1])
    ui.adb("shell", "input", "tap", str(x), str(y))
    time.sleep(2.5)


def back() -> None:
    ui.adb("shell", "input", "keyevent", "KEYCODE_BACK")
    time.sleep(2.5)


def capture(profile: str, screen: str) -> None:
    ui.screenshot(f"release_{profile}_{screen}")


def main() -> None:
    ui.adb("shell", "settings", "put", "system", "show_touches", "0")
    ui.adb("shell", "settings", "put", "system", "pointer_location", "0")
    ui.LABELS.update(
        {
            "interface": ["Интерфейс", "Interface", "Oberfläche", "Interfaz"],
            "compose": ui.LABELS["compose"],
        }
    )
    selected = sys.argv[1:] or list(PROFILES)
    if any(profile not in PROFILES for profile in selected):
        raise SystemExit(f"Profiles must be selected from: {', '.join(PROFILES)}")
    ui.launch()
    for profile in selected:
        profile_name = PROFILES[profile]
        ui.click_labels(ui.dump(f"release-{profile}-before-settings"), "more")
        ui.click_labels(ui.dump(f"release-{profile}-settings-root"), "interface")
        gallery = ui.dump(f"release-{profile}-gallery")
        if profile in {"flow", "zen"}:
            ui.adb("shell", "input", "swipe", "540", "1800", "540", "700", "500")
            time.sleep(2)
            gallery = ui.dump(f"release-{profile}-gallery-scrolled")
        click_contains(gallery, profile_name)
        ui.click_labels(ui.dump(f"release-{profile}-selected"), "today")
        capture(profile, "today")

        click_contains(ui.dump(f"release-{profile}-today-ready"), "ORBIT Brain")
        capture(profile, "brain")
        back()

        ui.click_labels(ui.dump(f"release-{profile}-before-mail"), "mail")
        capture(profile, "mail_inbox")
        click_contains(ui.dump(f"release-{profile}-mail-semantics"), "План на неделю")
        capture(profile, "mail_detail")
        back()
        ui.click_labels(ui.dump(f"release-{profile}-mail-return"), "compose")
        capture(profile, "mail_compose")
        back()

        ui.click_labels(ui.dump(f"release-{profile}-before-calendar"), "calendar")
        capture(profile, "calendar")

        ui.click_labels(ui.dump(f"release-{profile}-before-tasks"), "tasks")
        capture(profile, "tasks")
        click_contains(ui.dump(f"release-{profile}-tasks-semantics"), "Подготовить отчёт по КПЭ")
        capture(profile, "task_detail")
        back()

        ui.click_labels(ui.dump(f"release-{profile}-before-final-settings"), "more")
        ui.click_labels(ui.dump(f"release-{profile}-settings-root-reset"), "more")
        capture(profile, "settings")
        print(f"{profile}: 9 release screens captured", flush=True)


if __name__ == "__main__":
    main()
