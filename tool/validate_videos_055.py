from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit055_stabilize"
MEDIA = OUT / "screenshots"
FFMPEG = Path(r"D:\Кими\tools\ffmpeg\ffmpeg.exe")
FFPROBE = Path(r"D:\Кими\tools\ffmpeg\ffprobe.exe")


def run(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")


def main() -> None:
    if not FFMPEG.exists() or not FFPROBE.exists():
        raise SystemExit("Local FFmpeg/ffprobe tools are missing")
    reports = []
    for source in sorted(MEDIA.glob("*_motion.mp4")):
        normalized_dir = OUT / "runtime" / "normalized-video"
        normalized_dir.mkdir(parents=True, exist_ok=True)
        target = normalized_dir / source.name
        encode = run(
            str(FFMPEG), "-y", "-v", "error", "-i", str(source),
            "-vf", "setpts=PTS-STARTPTS,fps=30",
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
            "-movflags", "+faststart", "-an", str(target),
        )
        if encode.returncode != 0:
            raise RuntimeError(f"Video normalization failed for {source.name}: {encode.stderr}")
        probe = run(
            str(FFPROBE), "-v", "error", "-show_streams", "-show_format", "-of", "json", str(target)
        )
        if probe.returncode != 0:
            raise RuntimeError(probe.stderr)
        metadata = json.loads(probe.stdout)
        decode = run(str(FFMPEG), "-v", "error", "-i", str(target), "-f", "null", "-")
        if decode.returncode != 0 or decode.stderr.strip():
            raise RuntimeError(f"Video decode validation failed for {source.name}: {decode.stderr}")
        stream = metadata["streams"][0]
        duration = float(metadata["format"]["duration"])
        if not 1.5 <= duration <= 10.2:
            raise AssertionError(f"Unexpected clip duration for {source.name}: {duration}")
        if float(metadata["format"]["start_time"]) != 0:
            raise AssertionError(f"Nonzero video start time for {source.name}")
        reports.append(
            {
                "file": f"runtime/normalized-video/{source.name}",
                "sourceFile": f"screenshots/{source.name}",
                "durationSeconds": duration,
                "startTime": float(metadata["format"]["start_time"]),
                "width": stream["width"],
                "height": stream["height"],
                "encodedFrames": int(stream.get("nb_frames", 0)),
                "ffmpegDecode": "PASS; no non-monotonic DTS warning",
                "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
                "environment": "ANDROID_X86_EMULATOR; physical ARM64 NOT RUN",
            }
        )
        (OUT / "logs" / f"video-{source.stem}-ffprobe.json").write_text(
            json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        print(f"{source.name}: {duration:.3f}s; decode PASS; frames={reports[-1]['encodedFrames']}", flush=True)
    if not reports:
        raise SystemExit("No motion videos found")
    (OUT / "runtime" / "video-validation.json").write_text(
        json.dumps({"status": "PASS", "videos": reports}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    (OUT / "logs" / "ffmpeg-source.txt").write_text(
        "Local validation tool: FFmpeg 9.0.2 essentials (gyan.dev)\n"
        "ZIP SHA-256: 60f467265b1e312373dbcd92200c2618a74850f98d3d078e94296bb3fa2047ba\n",
        encoding="utf-8",
    )
    expected = {
        "layered_one_motion.mp4",
        "filament_one_motion.mp4",
        "filament_lab_motion.mp4",
        "rive_motion.mp4",
    }
    actual = {report["sourceFile"].rsplit("/", 1)[-1] for report in reports}
    if actual != expected:
        raise AssertionError(f"Motion clip set mismatch: {sorted(actual)}")
    (OUT / "logs" / "media-validation-summary.txt").write_text(
        "Container normalization and full decode: PASS for all four required clips.\n"
        "Physical ARM64 playback: NOT RUN.\n"
        "Filament Lab clip is retained as evidence of the OPEN visual issue, not as proof of visible camera motion.\n"
        + "".join(
            f"{report['file']}: {report['durationSeconds']:.3f}s, "
            f"{report['width']}x{report['height']}, {report['encodedFrames']} frames, "
            f"SHA-256 {report['sha256']}\n"
            for report in reports
        ),
        encoding="utf-8",
    )
    from PIL import Image, ImageStat

    screenshot_names = [
        "android_light_one_today.png",
        "android_light_atelier_today.png",
        "android_light_flow_today.png",
        "android_light_zen_today.png",
        "android_dark_one_today.png",
        "android_dark_atelier_today.png",
        "android_dark_flow_today.png",
        "android_dark_zen_today.png",
        "android_light_flow_mail.png",
        "android_light_flow_calendar.png",
        "android_light_flow_tasks.png",
        "android_light_flow_settings.png",
        "android_system_night_before.png",
        "android_system_night_after.png",
        "android_calendar_week_selection.png",
        "android_calendar_year_boundary.png",
        "android_calendar_leap_year.png",
        "filament_lab_before.png",
        "filament_lab_gesture.png",
    ]
    screenshots = []
    for name in screenshot_names:
        path = MEDIA / name
        with Image.open(path) as image:
            image.load()
            if image.width < 320 or image.height < 480:
                raise AssertionError(f"Unexpected screenshot dimensions: {name} {image.size}")
            statistics = ImageStat.Stat(image.convert("RGB"))
            if max(statistics.stddev) < 2:
                raise AssertionError(f"Blank or nearly uniform screenshot: {name}")
            screenshots.append(
                {
                    "file": f"screenshots/{name}",
                    "width": image.width,
                    "height": image.height,
                    "decode": "PASS",
                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                }
            )
    (OUT / "runtime" / "media-validation.json").write_text(
        json.dumps(
            {
                "status": "TECHNICAL_PASS_VISUAL_BLOCKERS_REMAIN",
                "environment": "ANDROID_X86_EMULATOR; physical ARM64 NOT RUN",
                "screenshotCount": len(screenshots),
                "videoCount": len(reports),
                "screenshots": screenshots,
                "filamentVisualMotion": "OPEN / NOT PROVEN",
                "nativeRiveArtboardMotion": "PARTIAL / NOT PROVEN",
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
