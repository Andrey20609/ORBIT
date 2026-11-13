from __future__ import annotations

import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import android_draft_autosave_053 as draft
import android_persistence_ui_052 as ui

ROOT = Path(__file__).resolve().parents[1]


def open_compose(prefix: str):
    for attempt in range(3):
        try:
            ui.click_labels(ui.dump(f"{prefix}-today"), "mail")
            ui.click_labels(ui.dump(f"{prefix}-mail"), "compose")
            return ui.dump(f"{prefix}-compose")
        except RuntimeError:
            if attempt == 2:
                raise
            time.sleep(5)
            ui.launch()


def main() -> None:
    ui.OUT = ROOT / "validation" / "orbit054"
    (ui.OUT / "runtime").mkdir(parents=True, exist_ok=True)
    (ui.OUT / "persistence").mkdir(parents=True, exist_ok=True)
    (ui.OUT / "screenshots").mkdir(parents=True, exist_ok=True)
    delays = [int(value) for value in sys.argv[1:]] or [0, 100, 250, 500]
    results = []
    for delay in delays:
        recipient = f"kill054-{delay}@example.demo"
        subject = f"OR054 kill {delay}"
        body = f"OR054 body {delay}"
        expected = [recipient, subject, body]
        ui.launch()
        root = open_compose(f"kill-{delay}-create")
        for node, value in zip(draft.fields(root), expected, strict=True):
            draft.enter_fresh(node, value)
        time.sleep(delay / 1000)
        ui.adb("shell", "am", "force-stop", ui.PACKAGE)
        ui.launch()
        root = open_compose(f"kill-{delay}-verify")
        actual = [node.attrib.get("text", "") for node in draft.fields(root)]
        status = "PASS" if actual == expected else "PARTIAL"
        screenshot = ui.OUT / "screenshots" / f"android_054_kill_{delay}.png"
        with screenshot.open("wb") as stream:
            import subprocess
            subprocess.run(
                [str(ui.ADB), "-s", ui.DEVICE, "exec-out", "screencap", "-p"],
                stdout=stream,
                stderr=subprocess.PIPE,
                check=True,
            )
        result = {
            "delayMs": delay,
            "action": "type then immediate am force-stop and cold relaunch",
            "expected": expected,
            "actual": actual,
            "status": status,
            "screenshot": screenshot.name,
            "utc": datetime.now(timezone.utc).isoformat(),
        }
        results.append(result)
        print(json.dumps(result, ensure_ascii=False), flush=True)
    output = ui.OUT / "runtime" / "draft-kill-windows.json"
    previous = []
    if output.exists():
        previous = json.loads(output.read_text(encoding="utf-8"))["results"]
    results = previous + results
    output.write_text(
        json.dumps(
            {
                "environment": "ANDROID_X86_EMULATOR",
                "note": "force-stop is not an uncontrolled hardware power loss; earlier unconfirmed bytes may still be lost",
                "results": results,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
