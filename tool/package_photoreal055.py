from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit055"
DELIVERY = ROOT.parent / "ORBIT_AI_EXCHANGE" / "02_RESULTS_FROM_KIMI" / "2026-11-09_ORBIT_0.5.4_photoreal"
FULL_NAME = "2026-11-09_ORBIT_0.5.4_photoreal_FULL_PACKAGE.zip"


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
    if relative.startswith(("validation/", "test/failures/")):
        return False
    if path.suffix.lower() in {".apk", ".zip", ".log", ".pid", ".jks", ".keystore", ".tgz"}:
        return False
    return path.name not in {".env", "key.properties", "google-services.json"}


def main() -> None:
    DELIVERY.mkdir(parents=True, exist_ok=True)
    for name in [
        "ORBIT_PROJECT_STATE.json",
        "ORBIT_RESUME.md",
        "ORBIT_PROGRESS.md",
        "ORBIT_ISSUES.md",
        "ORBIT_RELEASE_CHECKLIST.md",
        "PHOTOREAL.md",
        "PHOTOREAL_READY.md",
    ]:
        shutil.copy2(ROOT / name, OUT / name)
    surfaces = ["today", "brain", "mail_inbox", "mail_detail", "mail_compose", "calendar", "tasks", "task_detail", "settings"]
    graphics = ["static_eco", "rive_motion_t0", "rive_motion_t2", "rive_balanced", "filament_system_t0", "filament_system_t2", "filament_balanced", "filament_before_low_memory_system", "before_low_memory"]
    expected_png = {
        *(f"android_{profile}_{surface}.png" for profile in ["one", "atelier", "flow", "zen"] for surface in surfaces),
        *(f"orbit_{name}.png" for name in graphics),
        *(f"layered_{profile}_today_{time}.png" for profile in ["one", "atelier", "flow", "zen"] for time in ["t0", "t2"]),
        *(f"filament_one_today_{time}.png" for time in ["t0", "t2"]),
        *(f"android_theme_{mode}_{place}.png" for mode in ["dark", "light", "system"] for place in ["today", "relaunch_settings"]),
        "android_release_system_settings.png",
        "android_release_system_today.png",
    }
    expected_videos = {
        *(f"layered_{profile}_motion.mp4" for profile in ["one", "atelier", "flow", "zen"]),
        "filament_one_motion.mp4",
    }
    pngs = sorted((OUT / "screenshots").glob("*.png"))
    videos = sorted((OUT / "screenshots").glob("*.mp4"))
    assert {path.name for path in pngs} == set(expected_png)
    assert {path.name for path in videos} == set(expected_videos)
    unique = {}
    provenance = []
    for path in pngs:
        digest = sha256(path)
        unique.setdefault(digest, path)
        provenance.append({"source": path.name, "sha256": digest, "bytes": path.stat().st_size, "duplicate": unique[digest].name != path.name})
    for path in videos:
        unique[path.name] = path
    (OUT / "runtime" / "screenshot-provenance.json").write_text(
        json.dumps({"runId": "ORBIT-PHOTOREAL-055", "screenshots": provenance}, indent=2) + "\n",
        encoding="utf-8",
    )
    media_manifest = "".join(f"{sha256(path)}  {path.name}  {path.stat().st_size} bytes\n" for path in unique.values())
    (OUT / "logs" / "android-media-sha256.txt").write_text(media_manifest, encoding="utf-8", newline="\n")

    source_zip = OUT / "ORBIT_0.5.4_photoreal_source.zip"
    screenshots_zip = OUT / "ORBIT_0.5.4_photoreal_screenshots.zip"
    tracked = subprocess.check_output(
        ["git", "-c", "core.quotepath=false", "ls-files"], cwd=ROOT, text=True, encoding="utf-8"
    ).splitlines()
    evidence = [
        path
        for directory in ["logs", "persistence", "runtime"]
        for path in (OUT / directory).rglob("*")
        if path.is_file()
    ] + [
        OUT / "ORBIT_0.5.4_photoreal_validation.md",
        OUT / "ORBIT_0.5.4_photoreal_release_notes.md",
        OUT / "PHOTOREAL_READY.md",
    ]
    with zipfile.ZipFile(source_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for relative in tracked:
            if include_source(relative):
                archive.write(ROOT / relative, f"orbit_visual_lab/{relative}")
        for path in evidence:
            archive.write(path, f"orbit_visual_lab/validation/orbit055/{path.relative_to(OUT)}")
    with zipfile.ZipFile(screenshots_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in unique.values():
            archive.write(path, path.name)
        for name in ["integration-app.txt", "integration-navigation.txt", "photoreal-install.log"]:
            path = OUT / "logs" / name
            if path.exists():
                archive.write(path, f"logs/{name}")
    for path in [source_zip, screenshots_zip]:
        with zipfile.ZipFile(path) as archive:
            assert archive.testzip() is None, path
    with zipfile.ZipFile(source_zip) as archive:
        names = archive.namelist()
        assert "orbit_visual_lab/pubspec.yaml" in names
        assert "orbit_visual_lab/assets/photoreal/LICENSES.md" in names
        assert not any("/build/" in name or name.endswith((".apk", ".jks", ".keystore", ".env")) for name in names)

    artifact_names = [
        "ORBIT_0.5.4_photoreal_source.zip",
        "ORBIT_0.5.4_photoreal_android_arm64.apk",
        "ORBIT_0.5.4_photoreal_android_x86_64.apk",
        "ORBIT_0.5.4_photoreal_validation.md",
        "ORBIT_0.5.4_photoreal_release_notes.md",
        "ORBIT_0.5.4_photoreal_screenshots.zip",
        "PHOTOREAL.md",
        "PHOTOREAL_READY.md",
        "ORBIT_PROJECT_STATE.json",
        "ORBIT_RESUME.md",
        "ORBIT_PROGRESS.md",
        "ORBIT_ISSUES.md",
        "ORBIT_RELEASE_CHECKLIST.md",
    ]
    sums = OUT / "ORBIT_0.5.4_photoreal_SHA256SUMS.txt"
    sums.write_text(
        "".join(f"{sha256(OUT / name)}  {name}\n" for name in artifact_names),
        encoding="utf-8",
        newline="\n",
    )
    artifact_names.append(sums.name)
    for name in artifact_names:
        shutil.copy2(OUT / name, DELIVERY / name)
    for directory in ["logs", "persistence", "runtime"]:
        shutil.copytree(OUT / directory, DELIVERY / directory, dirs_exist_ok=True)
    full = DELIVERY / FULL_NAME
    files = sorted(path for path in DELIVERY.rglob("*") if path.is_file() and path.name not in {FULL_NAME, f"{FULL_NAME}_SHA256.txt"})
    with zipfile.ZipFile(full, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in files:
            archive.write(path, path.relative_to(DELIVERY).as_posix())
    with zipfile.ZipFile(full) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == len(files)
        for path in files:
            name = path.relative_to(DELIVERY).as_posix()
            assert hashlib.sha256(path.read_bytes()).digest() == hashlib.sha256(archive.read(name)).digest()
    full_sha = DELIVERY / f"{FULL_NAME}_SHA256.txt"
    full_sha.write_text(f"{sha256(full)}  {FULL_NAME}\n", encoding="utf-8", newline="\n")
    print(f"FULL_PACKAGE files={len(files)} bytes={full.stat().st_size} sha256={sha256(full)}")


if __name__ == "__main__":
    main()
