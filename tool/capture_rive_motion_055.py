from __future__ import annotations

import json
import re
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

import android_persistence_ui_052 as ui
import android_theme_modes_055 as theme
import capture_motion_evidence_053 as evidence
import release_stress_054 as stress

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit055_stabilize"


def main() -> None:
    ui.OUT = OUT
    evidence.OUT = OUT / "screenshots"
    ui.LABELS.update({"rive": ["Rive"]})
    ui.adb("logcat", "-c")
    theme.launch_ready("rive-motion-launch")
    stress.open_lab(1, "rive-motion")
    ui.click_labels(ui.dump("rive-motion-select"), "rive")
    time.sleep(3)
    ui.assert_text(ui.dump("rive-motion-ready"), "Actual: RIVE")
    with (OUT / "logs" / "rive-screenrecord.txt").open("w", encoding="utf-8") as output:
        process = subprocess.Popen(
            [str(ui.ADB), "-s", ui.DEVICE, "shell", "screenrecord", "--time-limit", "6", "/sdcard/orbit055_rive.mp4"],
            stdout=output,
            stderr=subprocess.STDOUT,
            text=True,
        )
    time.sleep(0.5)
    ui.adb("shell", "input", "tap", "500", "1200")
    time.sleep(1)
    ui.adb("shell", "input", "swipe", "260", "1200", "920", "1200", "900")
    if process.wait(timeout=20) != 0:
        raise RuntimeError("Rive screenrecord failed")
    video = OUT / "screenshots" / "rive_motion.mp4"
    ui.adb("pull", "/sdcard/orbit055_rive.mp4", str(video))
    logcat = ui.adb("logcat", "-d", "-v", "time").stdout
    (OUT / "runtime" / "rive-motion-logcat.txt").write_text(logcat, encoding="utf-8")
    for _ in range(3):
        ui.adb("shell", "input", "swipe", "540", "1900", "540", "700", "400")
        time.sleep(0.5)
    values = []
    for index in range(5):
        values.extend(
            value
            for node in ui.dump(f"rive-motion-metrics-{index}").iter("node")
            for value in (node.attrib.get("text", ""), node.attrib.get("content-desc", ""))
            if value
        )
        if "Native state-machine advances" in values:
            break
        ui.adb("shell", "input", "swipe", "540", "800", "540", "1800", "400")
        time.sleep(0.5)

    def metric(label: str) -> int:
        for index, value in enumerate(values[:-1]):
            if value == label:
                match = re.search(r"/\s*(\d+)", values[index + 1])
                if match:
                    return int(match.group(1))
        return 0

    result = {
        "environment": "ANDROID_X86_EMULATOR",
        "utc": datetime.now(timezone.utc).isoformat(),
        "actualRenderer": "rive",
        "artboardReady": True,
        "stateMachine": "OrbitLoop",
        "pulseCount": metric("Pulse (available / activations)"),
        "pulseProof": "Separate app_test.dart PASS; atmospheric Visual Lab preview does not fire Pulse on tap",
        "stateMachineAdvanceCount": metric("Native state-machine advances"),
        "nativeArtboardAnimationProven": False,
        "visualMotionMode": "flutter-transform-fallback",
        "videoSha256": evidence.sha256(video),
        "physicalArm64": "NOT RUN",
    }
    if result["stateMachineAdvanceCount"] < 1:
        raise RuntimeError(f"Rive runtime proof incomplete: {result}; visible values={values}")
    (OUT / "runtime" / "rive-motion.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(result, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
