from __future__ import annotations

import hashlib
import io
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image, ImageStat

ROOT = Path(__file__).resolve().parents[1]
LOG = ROOT / "validation" / "orbit054" / "logs" / "integration-app.txt"
OUT = ROOT / "validation" / "orbit054" / "screenshots"
ADB = Path(r"C:\Users\AVBur\AppData\Local\Android\Sdk\platform-tools\adb.exe")


def adb(*args: str) -> str:
    return subprocess.check_output([str(ADB), "-s", "emulator-5554", *args], text=True).strip()


def capture(name: str) -> Path:
    path = OUT / name
    with path.open("wb") as stream:
        subprocess.run(
            [str(ADB), "-s", "emulator-5554", "exec-out", "screencap", "-p"],
            stdout=stream,
            check=True,
            timeout=15,
        )
    validate_png(path)
    print(f"CAPTURE {name} {path.stat().st_size} bytes", flush=True)
    return path


def validate_png(path: Path) -> None:
    with Image.open(path) as image:
        rgba = image.convert("RGBA")
        alpha = rgba.getchannel("A")
        if alpha.getextrema()[1] == 0:
            raise SystemExit(f"CAPTURE_FAILED transparent PNG: {path.name}")
        bins = len(set(rgba.getdata()))
        if bins < 2 or ImageStat.Stat(rgba).var == [0, 0, 0, 0]:
            raise SystemExit(f"CAPTURE_FAILED visually empty PNG: {path.name}")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def scene_hash(path: Path, box: tuple[int, int, int, int], suffix: str) -> str:
    with Image.open(path) as image:
        crop = image.crop(box)
        output = io.BytesIO()
        crop.save(output, format="PNG")
        scene_path = path.with_name(f"{path.stem}_{suffix}.png")
        crop.save(scene_path)
    return hashlib.sha256(output.getvalue()).hexdigest()


def wait_for(marker: str, timeout: float = 240) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if LOG.exists() and marker in LOG.read_text(encoding="utf-8", errors="replace"):
            return
        time.sleep(0.25)
    raise TimeoutError(f"Marker not observed: {marker}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    print("environment=ANDROID_X86_EMULATOR")
    print(f"utc={datetime.now(timezone.utc).isoformat()}")
    print(f"model={adb('shell', 'getprop', 'ro.product.model')}")
    print(f"abi={adb('shell', 'getprop', 'ro.product.cpu.abi')}")
    print(f"android={adb('shell', 'getprop', 'ro.build.version.release')}")
    print(f"gpu={adb('shell', 'getprop', 'ro.hardware.egl')}")
    wait_for("[ORBIT device] B Rive runtime=")
    rive_t0 = capture("adb_rive_t0.png")
    time.sleep(0.8)
    rive_t2 = capture("adb_rive_t2.png")
    wait_for("[ORBIT device] C Filament motion stats=")
    filament_t0 = capture("adb_filament_t0.png")
    time.sleep(0.8)
    filament_t2 = capture("adb_filament_t2.png")
    adb("shell", "screenrecord", "--time-limit", "5", "/sdcard/orbit054_filament.mp4")
    adb("pull", "/sdcard/orbit054_filament.mp4", str(OUT / "adb_filament_motion.mp4"))
    results = {
        "rive": (
            sha256(rive_t0),
            sha256(rive_t2),
            scene_hash(rive_t0, (650, 450, 1000, 850), "scene_t0"),
            scene_hash(rive_t2, (650, 450, 1000, 850), "scene_t2"),
        ),
        "filament": (
            sha256(filament_t0),
            sha256(filament_t2),
            scene_hash(filament_t0, (0, 150, 1080, 1000), "scene_t0"),
            scene_hash(filament_t2, (0, 150, 1080, 1000), "scene_t2"),
        ),
    }
    for renderer, (full_t0, full_t2, scene_t0, scene_t2) in results.items():
        print(f"{renderer}_actualRenderer={renderer}")
        print(f"{renderer}_t0_sha256={full_t0}")
        print(f"{renderer}_t2_sha256={full_t2}")
        print(f"{renderer}_scene_t0_sha256={scene_t0}")
        print(f"{renderer}_scene_t2_sha256={scene_t2}")
        print(f"{renderer}_scene_differ={scene_t0 != scene_t2}")
    print(f"filament_video_sha256={sha256(OUT / 'adb_filament_motion.mp4')}")
    print("rive_nativeArtboardAnimationProven=False")
    print("rive_visualMotionMode=flutter-transform-fallback")
    if results["rive"][2] == results["rive"][3]:
        raise SystemExit("Rive scene regions are identical")
    if results["filament"][2] == results["filament"][3]:
        raise SystemExit("Filament scene regions are identical")


if __name__ == "__main__":
    main()
