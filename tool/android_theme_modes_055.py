from __future__ import annotations

import json
import time
import xml.etree.ElementTree as ET
from pathlib import Path

import android_persistence_ui_052 as ui

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit055_stabilize"
LABELS = {
    "light": ["Светлая", "Light", "Hell", "Clair", "Claro"],
    "dark": ["Тёмная", "Dark", "Dunkel", "Sombre", "Oscuro"],
    "system": ["Системная", "System", "Sistema"],
    "graphics_quality": [
        "Качество графики",
        "Graphics quality",
        "Grafikqualität",
        "Qualité graphique",
        "Calidad gráfica",
    ],
}


def assert_selected(root: ET.Element, label: str) -> None:
    matches = [
        node
        for node in root.iter("node")
        if (
            node.attrib.get("text") in LABELS[label]
            or node.attrib.get("content-desc") in LABELS[label]
        )
        and node.attrib.get("selected") == "true"
    ]
    if not matches:
        raise AssertionError(f"Theme chip is not selected after relaunch: {label}")


def launch_ready(name: str) -> ET.Element:
    ui.launch()
    deadline = time.monotonic() + 30
    activated = False
    while time.monotonic() < deadline:
        root = ui.dump(name)
        if any(
            node.attrib.get("text", "").split("\n")[0] in ui.LABELS["more"]
            or node.attrib.get("content-desc", "").split("\n")[0] in ui.LABELS["more"]
            for node in root.iter("node")
        ):
            return root
        if not activated:
            ui.adb("shell", "input", "tap", "950", "2210")
            activated = True
        time.sleep(2)
    raise AssertionError("Today semantics did not become ready within 30 seconds")


def main() -> None:
    for directory in ["logs", "persistence", "runtime", "screenshots"]:
        (OUT / directory).mkdir(parents=True, exist_ok=True)
    ui.OUT = OUT
    ui.LABELS.update(LABELS)
    results = []
    for mode in ["dark", "light", "system"]:
        ui.click_labels(launch_ready(f"theme-{mode}-today"), "more")
        ui.click_labels(
            ui.dump(f"theme-{mode}-settings-root"), "graphics_quality"
        )
        ui.adb("shell", "input", "swipe", "540", "1800", "540", "650", "500")
        ui.click_labels(ui.dump(f"theme-{mode}-settings"), mode)
        ui.click_labels(ui.dump(f"theme-{mode}-selected"), "today")
        ui.screenshot(f"android_theme_{mode}_today")
        ui.click_labels(launch_ready(f"theme-{mode}-relaunch-today"), "more")
        ui.click_labels(
            ui.dump(f"theme-{mode}-settings-root"), "graphics_quality"
        )
        ui.adb("shell", "input", "swipe", "540", "1800", "540", "650", "500")
        root = ui.dump(f"theme-{mode}-relaunch-settings")
        assert_selected(root, mode)
        ui.screenshot(f"android_theme_{mode}_relaunch_settings")
        results.append({"mode": mode, "selectedAfterForceStop": True})
    (OUT / "runtime" / "theme-modes.json").write_text(
        json.dumps({"environment": "ANDROID_X86_EMULATOR", "status": "PASS", "results": results}, indent=2) + "\n",
        encoding="utf-8",
    )
    print("Light/Dark/System selection and process-death persistence PASS", flush=True)


if __name__ == "__main__":
    main()
