from __future__ import annotations

import argparse
import json
import re
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image, ImageChops

import android_persistence_ui_052 as ui
import analyze_performance
import capture_motion_evidence_053 as evidence
import release_stress_054 as stress
from capture_release_screens_052 import PROFILES, click_contains

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit055_stabilize"


def capture_renderer(renderer: str, profiles: list[str]) -> None:
    if renderer == "filament":
        ui.click_labels(ui.dump("filament-before-balanced"), "more")
        ui.click_labels(ui.dump("filament-quality-root"), "graphics_quality")
        ui.click_labels(ui.dump("filament-quality-balanced"), "balanced")
        ui.adb("shell", "input", "keyevent", "KEYCODE_BACK")
        time.sleep(1)
    stress.open_lab(1, f"{renderer}-startup")
    ui.click_labels(ui.dump(f"{renderer}-startup-lab"), "static" if renderer == "layered" else "filament")
    for profile in profiles:
        raw = OUT / "runtime" / f"{renderer}-{profile}"
        (raw / "samples").mkdir(parents=True, exist_ok=True)
        ui.OUT = OUT
        evidence.OUT = OUT / "screenshots"
        ui.click_labels(ui.dump(f"{renderer}-{profile}-settings"), "more")
        ui.click_labels(ui.dump(f"{renderer}-{profile}-settings-root"), "more")
        ui.LABELS["interface"] = ["Интерфейс", "Interface", "Oberfläche", "Interfaz"]
        ui.click_labels(ui.dump(f"{renderer}-{profile}-settings-root-open"), "interface")
        gallery = ui.dump(f"{renderer}-{profile}-gallery")
        if profile in {"flow", "zen"}:
            ui.adb("shell", "input", "swipe", "540", "1800", "540", "700", "500")
            time.sleep(1)
            gallery = ui.dump(f"{renderer}-{profile}-gallery-scrolled")
        click_contains(gallery, PROFILES[profile])
        if renderer == "filament":
            selected = ui.dump(f"{renderer}-{profile}-selected")
            ui.click_labels(selected, "more")
            ui.click_labels(ui.dump(f"{renderer}-{profile}-settings-root-native"), "visual_lab")
            ui.assert_text(ui.dump(f"{renderer}-{profile}-native-proof"), "Actual: FILAMENT")
        ui.click_labels(ui.dump(f"{renderer}-{profile}-today"), "today")
        time.sleep(4)
        t0 = evidence.capture(f"{renderer}_{profile}_today_t0.png")
        (raw / "samples" / "before.txt").write_text(
            ui.adb("shell", "dumpsys", "meminfo", ui.PACKAGE).stdout, encoding="utf-8"
        )
        ui.adb("shell", "dumpsys", "gfxinfo", ui.PACKAGE, "reset")
        log_path = OUT / "logs" / f"{renderer}-{profile}-screenrecord.txt"
        with log_path.open("w", encoding="utf-8") as output:
            process = subprocess.Popen(
                [str(ui.ADB), "-s", ui.DEVICE, "shell", "screenrecord", "--time-limit", "6", f"/sdcard/orbit055_{renderer}_{profile}.mp4"],
                stdout=output,
                stderr=subprocess.STDOUT,
                text=True,
            )
        time.sleep(0.5)
        ui.adb("shell", "input", "swipe", "540", "1800", "540", "650", "700")
        time.sleep(1)
        ui.adb("shell", "input", "swipe", "540", "700", "540", "1750", "700")
        time.sleep(1)
        if renderer == "filament":
            ui.adb("shell", "input", "swipe", "260", "850", "920", "850", "900")
        else:
            ui.adb("shell", "input", "tap", "820", "650")
        if process.wait(timeout=20) != 0:
            raise RuntimeError(f"screenrecord failed for {renderer}/{profile}")
        video = OUT / "screenshots" / f"{renderer}_{profile}_motion.mp4"
        ui.adb("pull", f"/sdcard/orbit055_{renderer}_{profile}.mp4", str(video))
        time.sleep(1)
        t2 = evidence.capture(f"{renderer}_{profile}_today_t2.png")
        lab_video = None
        if renderer == "filament":
            stress.open_lab(2, "filament-gesture")
            evidence.capture("filament_lab_before.png")
            lab_log = OUT / "logs" / "filament-lab-screenrecord.txt"
            with lab_log.open("w", encoding="utf-8") as output:
                lab_process = subprocess.Popen(
                    [str(ui.ADB), "-s", ui.DEVICE, "shell", "screenrecord", "--time-limit", "6", "/sdcard/orbit055_filament_lab.mp4"],
                    stdout=output,
                    stderr=subprocess.STDOUT,
                    text=True,
                )
            time.sleep(0.5)
            ui.adb("shell", "input", "swipe", "260", "1200", "920", "1200", "900")
            if lab_process.wait(timeout=20) != 0:
                raise RuntimeError("Filament lab screenrecord failed")
            lab_video = OUT / "screenshots" / "filament_lab_motion.mp4"
            ui.adb("pull", "/sdcard/orbit055_filament_lab.mp4", str(lab_video))
            evidence.capture("filament_lab_gesture.png")
            time.sleep(1)
        (raw / "gfxinfo-framestats.txt").write_text(
            ui.adb("shell", "dumpsys", "gfxinfo", ui.PACKAGE, "framestats").stdout,
            encoding="utf-8",
        )
        (raw / "meminfo-after.txt").write_text(
            ui.adb("shell", "dumpsys", "meminfo", ui.PACKAGE).stdout,
            encoding="utf-8",
        )
        logcat = ui.adb("logcat", "-d", "-v", "time").stdout
        (OUT / "runtime" / f"{renderer}-{profile}-logcat.txt").write_text(logcat, encoding="utf-8")
        native = {}
        if renderer == "filament":
            blocks = re.findall(r"ORBIT_FILAMENT\([^)]*\): activeViews=\d+ stats=\{([^}]+)\}", logcat)
            if not blocks:
                raise RuntimeError("No native Filament stats in capture")
            stats = next(
                (
                    block
                    for block in reversed(blocks)
                    if int(re.search(r"cameraInputCount=(\d+)", block).group(1)) > 0
                ),
                blocks[-1],
            )
            frames = int(re.search(r"renderedFrames=(\d+)", stats).group(1))
            camera_inputs = int(re.search(r"cameraInputCount=(\d+)", stats).group(1))
            if f"profile={profile}" not in stats or "sceneReady=true" not in stats or "hasSwapChain=true" not in stats or frames <= 0 or camera_inputs <= 0:
                raise RuntimeError(f"Invalid native Filament stats or missing camera input: {stats}")
            native = {
                "nativeStats": stats,
                "nativeRenderedFrames": frames,
                "cameraInputCount": camera_inputs,
                "lastFrameDurationMs": int(re.search(r"lastFrameDurationMs=(\d+)", stats).group(1)),
            }
        else:
            probes = re.findall(r"\[ORBIT frame metrics\] (\{[^\n]+\})", logcat)
            if not probes:
                raise RuntimeError("No Flutter FrameTiming metrics in layered capture")
            native["flutterFrameTiming"] = json.loads(probes[-1])
        with Image.open(t0) as first, Image.open(t2) as second:
            box = (0, 120, 1080, 1000)
            difference = ImageChops.difference(
                first.convert("RGB").crop(box), second.convert("RGB").crop(box)
            )
            changed = sum(
                max(pixel) > 10 for pixel in difference.get_flattened_data()
            )
            changed_fraction = changed / (difference.width * difference.height)
        lab_changed_fraction = None
        if renderer == "filament":
            with Image.open(OUT / "screenshots" / "filament_lab_before.png") as first, Image.open(OUT / "screenshots" / "filament_lab_gesture.png") as second:
                box = (50, 1005, 1030, 1583)
                difference = ImageChops.difference(
                    first.convert("RGB").crop(box), second.convert("RGB").crop(box)
                )
                changed = sum(
                    max(pixel) > 10 for pixel in difference.get_flattened_data()
                )
                lab_changed_fraction = changed / (difference.width * difference.height)
            if lab_changed_fraction < 0.005:
                raise RuntimeError(
                    f"Insufficient visible Filament lab motion: {lab_changed_fraction:.6%}"
                )
        metrics = analyze_performance.frame_times(raw / "gfxinfo-framestats.txt")
        result = {
            "renderer": renderer,
            "profile": profile,
            "environment": "ANDROID_X86_EMULATOR",
            "utc": datetime.now(timezone.utc).isoformat(),
            "t0Sha256": evidence.sha256(t0),
            "t2Sha256": evidence.sha256(t2),
            "sceneDiffer": evidence.sha256(t0) != evidence.sha256(t2),
            "sceneChangedFractionOverThreshold10": changed_fraction,
            "sceneComparisonRegion": [0, 120, 1080, 1000],
            "labSceneChangedFractionOverThreshold10": lab_changed_fraction,
            "videoSha256": evidence.sha256(video),
            **({"labVideoSha256": evidence.sha256(lab_video)} if lab_video else {}),
            "frameRecords": len(metrics),
            **native,
        }
        (raw / "capture-result.json").write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        print(json.dumps(result, ensure_ascii=False), flush=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("renderer", choices=["layered", "filament"])
    parser.add_argument("profiles", nargs="*", default=list(PROFILES))
    args = parser.parse_args()
    if any(profile not in PROFILES for profile in args.profiles):
        raise SystemExit(f"Profiles: {', '.join(PROFILES)}")
    for directory in ["logs", "persistence", "runtime", "screenshots"]:
        (OUT / directory).mkdir(parents=True, exist_ok=True)
    ui.OUT = OUT
    evidence.OUT = OUT / "screenshots"
    ui.LABELS.update(
        {
            "filament": ["Filament 3D"],
            "static": ["Static / Eco"],
            "balanced": ["Balanced"],
            "graphics_quality": [
                "Качество графики",
                "Graphics quality",
                "Grafikqualität",
                "Qualité graphique",
                "Calidad gráfica",
            ],
        }
    )
    ui.adb("logcat", "-c")
    ui.launch()
    capture_renderer(args.renderer, args.profiles)


if __name__ == "__main__":
    main()
