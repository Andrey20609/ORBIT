from __future__ import annotations

import sys
import time
from pathlib import Path

import android_persistence_ui_052 as ui

ROOT = Path(__file__).resolve().parents[1]
TO = "autosave053@example.demo"
SUBJECT = "OR052 Android autosave"
BODY = "OR052 body without Save"


def fields(root):
    values = ui.edit_fields(root)
    if len(values) != 3:
        raise AssertionError(f"Expected three compose fields, got {len(values)}")
    return values


def assert_draft(root, mode: str) -> None:
    values = [node.attrib.get("text", "") for node in fields(root)]
    expected = [TO, SUBJECT, BODY]
    if values != expected:
        raise AssertionError(f"{mode}: expected {expected}, got {values}")
    ui.screenshot(f"android_053_draft_{mode}")
    print(f"{mode}: all draft fields preserved", flush=True)


def open_compose(prefix: str):
    ui.click_labels(ui.dump(f"{prefix}-today"), "mail")
    ui.click_labels(ui.dump(f"{prefix}-mail"), "compose")
    return ui.dump(f"{prefix}-compose")


def enter_fresh(node, value: str) -> None:
    x, y = ui.center(node)
    ui.adb("shell", "input", "tap", str(x), str(y))
    time.sleep(0.4)
    ui.adb("shell", "input", "keyevent", "KEYCODE_MOVE_END")
    ui.adb("shell", "for i in $(seq 1 160); do input keyevent KEYCODE_DEL; done")
    ui.enter_text(node, value)


def create() -> None:
    ui.launch()
    root = open_compose("autosave-create")
    for node, value in zip(fields(root), [TO, SUBJECT, BODY], strict=True):
        enter_fresh(node, value)
    ui.adb("shell", "input", "keyevent", "KEYCODE_BACK")
    time.sleep(3)
    root = open_compose("autosave-after-system-back")
    assert_draft(root, "system_back")


def verify(mode: str) -> None:
    ui.launch()
    root = open_compose(f"autosave-{mode}")
    assert_draft(root, mode)


def main() -> None:
    if len(sys.argv) != 2 or sys.argv[1] not in {"create", "verify-restart", "verify-upgrade"}:
        raise SystemExit("Usage: android_draft_autosave_053.py create|verify-restart|verify-upgrade")
    ui.OUT = ROOT / "validation" / "orbit053"
    (ui.OUT / "persistence").mkdir(parents=True, exist_ok=True)
    (ui.OUT / "screenshots").mkdir(parents=True, exist_ok=True)
    (ui.OUT / "logs").mkdir(parents=True, exist_ok=True)
    if sys.argv[1] == "create":
        create()
    else:
        verify(sys.argv[1])


if __name__ == "__main__":
    main()
