from __future__ import annotations

import time
from pathlib import Path

import android_persistence_ui_052 as ui
import capture_motion_evidence_053 as evidence
import release_stress_054 as stress

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit054"


def main() -> None:
    ui.OUT = OUT
    evidence.OUT = OUT / "screenshots"
    ui.LABELS.update({"filament": ["Filament 3D"], "static": ["Static / Eco"]})
    ui.adb("logcat", "-c")
    ui.launch()
    print(f"environment=ANDROID_X86_EMULATOR build=installed-debug model={evidence.adb('shell', 'getprop', 'ro.product.model')}", flush=True)

    stress.open_lab(1, "installed-rive")
    ui.click_labels(ui.dump("installed-rive-lab"), "rive")
    time.sleep(2)
    ui.assert_text(ui.dump("installed-rive-selected"), "Actual: RIVE")
    ui.click_labels(ui.dump("installed-rive-ready"), "today")
    rive_t0 = evidence.capture("installed_rive_t0.png")
    time.sleep(2)
    rive_t2 = evidence.capture("installed_rive_t2.png")

    stress.open_lab(1, "installed-filament")
    ui.click_labels(ui.dump("installed-filament-lab"), "filament")
    time.sleep(3)
    ui.assert_text(ui.dump("installed-filament-selected"), "Actual: FILAMENT")
    ui.click_labels(ui.dump("installed-filament-ready"), "today")
    time.sleep(2)
    filament_t0 = evidence.capture("installed_filament_t0.png")
    time.sleep(2)
    filament_t2 = evidence.capture("installed_filament_t2.png")
    ui.adb("shell", "screenrecord", "--time-limit", "5", "/sdcard/orbit054_installed_filament.mp4")
    ui.adb("pull", "/sdcard/orbit054_installed_filament.mp4", str(OUT / "screenshots" / "installed_filament_motion.mp4"))
    logcat = ui.adb("logcat", "-d", "-v", "time").stdout
    (OUT / "runtime" / "installed-motion-logcat.txt").write_text(logcat, encoding="utf-8")

    results = {
        "rive": (
            evidence.sha256(rive_t0),
            evidence.sha256(rive_t2),
            evidence.scene_hash(rive_t0, (650, 450, 1000, 850), "scene_t0"),
            evidence.scene_hash(rive_t2, (650, 450, 1000, 850), "scene_t2"),
        ),
        "filament": (
            evidence.sha256(filament_t0),
            evidence.sha256(filament_t2),
            evidence.scene_hash(filament_t0, (0, 150, 1080, 1000), "scene_t0"),
            evidence.scene_hash(filament_t2, (0, 150, 1080, 1000), "scene_t2"),
        ),
    }
    for renderer, (full_t0, full_t2, scene_t0, scene_t2) in results.items():
        print(f"{renderer}_actualRenderer={renderer}", flush=True)
        print(f"{renderer}_t0_sha256={full_t0}", flush=True)
        print(f"{renderer}_t2_sha256={full_t2}", flush=True)
        print(f"{renderer}_scene_t0_sha256={scene_t0}", flush=True)
        print(f"{renderer}_scene_t2_sha256={scene_t2}", flush=True)
        print(f"{renderer}_scene_differ={scene_t0 != scene_t2}", flush=True)
    print(f"filament_video_sha256={evidence.sha256(OUT / 'screenshots' / 'installed_filament_motion.mp4')}", flush=True)
    print("rive_nativeArtboardAnimationProven=False", flush=True)
    print("rive_visualMotionMode=flutter-transform-fallback", flush=True)
    if results["rive"][2] == results["rive"][3]:
        raise SystemExit("Installed Rive scene regions are identical")
    if results["filament"][2] == results["filament"][3]:
        raise SystemExit("Installed Filament scene regions are identical")


if __name__ == "__main__":
    main()
