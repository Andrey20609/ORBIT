from __future__ import annotations

import hashlib
import shutil
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit055_stabilize"
DELIVERY = ROOT.parent / "ORBIT_AI_EXCHANGE" / "02_RESULTS_FROM_KIMI" / "2026-11-09_ORBIT_0.5.5+11_stabilize"
SELECTED_PNG = [
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
VIDEOS = ["layered_one_motion.mp4", "filament_one_motion.mp4", "filament_lab_motion.mp4", "rive_motion.mp4"]
LOGS = [
    "analyze-final.txt",
    "flutter-test-final.txt",
    "gfxinfo-parser-tests-final.txt",
    "integration-app.txt",
    "integration-navigation.txt",
    "integration-calendar-leap.txt",
    "scroll-perf-profile.txt",
    "localization-matrix.txt",
    "localization-matrix-100.txt",
    "localization-matrix-150.txt",
    "rive-motion.txt",
    "android-theme-modes.txt",
    "android-system-night.txt",
    "build-release-arm64.txt",
    "build-release-x86_64.txt",
    "apk-static-verification.txt",
    "installed-release-verification.txt",
    "media-validation-summary.txt",
    "filament-one-capture.txt",
    "update-new-install.log",
    "update-verify.txt",
    "reboot-verify.txt",
    "reboot-theme.txt",
]
RUNTIME = [
    "profile-theme-matrix.json",
    "theme-modes.json",
    "calendar-ui.json",
    "system-night-toggle.json",
    "reboot-theme.json",
    "apk-static-verification.json",
    "installed-release-verification.json",
    "video-validation.json",
    "rive-motion.json",
    "media-validation.json",
    "performance-summary.json",
    "layered-one/capture-result.json",
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def include_source(relative: str) -> bool:
    path = Path(relative)
    if any(part in {".git", ".dart_tool", "build", "artifacts", "coverage"} for part in path.parts):
        return False
    if relative.startswith(("validation/", "test/failures/")) or path.suffix.lower() == ".hdr":
        return False
    if path.suffix.lower() in {".apk", ".zip", ".log", ".pid", ".jks", ".keystore", ".tgz"}:
        return False
    return path.name not in {".env", "key.properties", "google-services.json"}


def main() -> None:
    DELIVERY.mkdir(parents=True, exist_ok=True)
    for name in ["ORBIT_PROJECT_STATE.json", "ORBIT_RESUME.md", "ORBIT_PROGRESS.md", "ORBIT_ISSUES.md"]:
        shutil.copy2(ROOT / name, OUT / name)
    tracked = subprocess.check_output(
        ["git", "-c", "core.quotepath=false", "ls-files"], cwd=ROOT, text=True, encoding="utf-8"
    ).splitlines()
    source_zip = OUT / "ORBIT_0.5.5+11_source.zip"
    with zipfile.ZipFile(source_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for relative in tracked:
            if include_source(relative):
                archive.write(ROOT / relative, f"orbit_visual_lab/{relative}")
        for directory in ["logs", "runtime", "persistence"]:
            for path in (OUT / directory).rglob("*"):
                if path.is_file():
                    archive.write(path, f"orbit_visual_lab/validation/orbit055_stabilize/{path.relative_to(OUT).as_posix()}")
        for name in ["ORBIT_0.5.5+11_validation.md", "ORBIT_0.5.5+11_release_notes.md"]:
            archive.write(OUT / name, f"orbit_visual_lab/validation/orbit055_stabilize/{name}")
    with zipfile.ZipFile(source_zip) as archive:
        assert archive.testzip() is None
        names = archive.namelist()
        assert "orbit_visual_lab/pubspec.yaml" in names
        assert "orbit_visual_lab/pubspec.lock" in names
        assert "orbit_visual_lab/integration_test/scroll_perf_test.dart" in names
        assert "orbit_visual_lab/test_driver/integration_test.dart" in names
        assert not any("/build/" in name or name.endswith((".apk", ".jks", ".keystore", ".env", ".hdr")) for name in names)

    review_zip = OUT / "ORBIT_0.5.5+11_review.zip"
    review_files = []
    changed_files = subprocess.check_output(
        ["git", "-c", "core.quotepath=false", "diff", "--name-only", "2240023..HEAD"],
        cwd=ROOT,
        text=True,
        encoding="utf-8",
    )
    (OUT / "CHANGED_FILES.txt").write_text(changed_files, encoding="utf-8", newline="\n")
    for name in SELECTED_PNG:
        path = OUT / "screenshots" / name
        assert path.is_file(), name
        review_files.append((path, f"screenshots/{name}"))
    for name in VIDEOS:
        path = OUT / "runtime" / "normalized-video" / name
        assert path.is_file(), name
        review_files.append((path, f"video/{name}"))
    for name in LOGS:
        path = OUT / "logs" / name
        assert path.is_file(), name
        review_files.append((path, f"logs/{name}"))
    for name in RUNTIME:
        path = OUT / "runtime" / name
        assert path.is_file(), name
        review_files.append((path, f"runtime/{name}"))
    for name in [
        "CHANGES.md",
        "CHANGED_FILES.txt",
        "ISSUES.md",
        "ORBIT_0.5.5+11_validation.md",
        "ORBIT_0.5.5+11_release_notes.md",
        "ORBIT_0.5.5+11_ARM64_CHECKLIST.md",
        "ORBIT_PROJECT_STATE.json",
        "ORBIT_RESUME.md",
        "ORBIT_PROGRESS.md",
        "ORBIT_ISSUES.md",
    ]:
        path = OUT / name
        review_files.append((path, name))
    manifest = OUT / "REVIEW_CONTENT_SHA256.txt"
    manifest.write_text(
        "".join(f"{sha256(path)}  {relative}\n" for path, relative in review_files),
        encoding="utf-8",
        newline="\n",
    )
    review_files.extend(
        [
            (manifest, "REVIEW_CONTENT_SHA256.txt"),
            (manifest, "SHA256SUMS.txt"),
        ]
    )
    with zipfile.ZipFile(review_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path, relative in review_files:
            archive.write(path, relative)
    with zipfile.ZipFile(review_zip) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == len(review_files)
    if review_zip.stat().st_size > 50 * 1024 * 1024:
        raise AssertionError(f"Review ZIP exceeds 50 MiB: {review_zip.stat().st_size}")

    artifacts = [
        "ORBIT_0.5.5+11_source.zip",
        "ORBIT_0.5.5+11_review.zip",
        "ORBIT_0.5.5+11_android_arm64.apk",
        "ORBIT_0.5.5+11_android_x86_64.apk",
        "ORBIT_0.5.5+11_validation.md",
        "ORBIT_0.5.5+11_release_notes.md",
        "ORBIT_0.5.5+11_ARM64_CHECKLIST.md",
        "ORBIT_PROJECT_STATE.json",
        "ORBIT_RESUME.md",
        "ORBIT_PROGRESS.md",
        "ORBIT_ISSUES.md",
    ]
    sums = OUT / "ORBIT_0.5.5+11_SHA256SUMS.txt"
    sums.write_text(
        "".join(f"{sha256(OUT / name)}  {name}\n" for name in artifacts),
        encoding="utf-8",
        newline="\n",
    )
    for name in [*artifacts, sums.name]:
        source = OUT / name
        target = DELIVERY / name
        shutil.copy2(source, target)
        assert sha256(source) == sha256(target)
    print(f"source={source_zip.stat().st_size} review={review_zip.stat().st_size} sha256={sha256(review_zip)}")


if __name__ == "__main__":
    main()
