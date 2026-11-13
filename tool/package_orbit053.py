from __future__ import annotations

import hashlib
import shutil
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit053"
DELIVERY = ROOT.parent / "ORBIT_AI_EXCHANGE" / "02_RESULTS_FROM_KIMI" / "2026-11-08_ORBIT_0.5.3"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def include_source(relative: str) -> bool:
    path = Path(relative)
    forbidden = {".git", ".dart_tool", "build", "artifacts", "coverage"}
    if any(part in forbidden for part in path.parts):
        return False
    if relative.startswith(("validation/", "test/failures/")):
        return False
    if path.suffix.lower() in {".apk", ".zip", ".log", ".pid", ".jks", ".keystore"}:
        return False
    return path.name not in {".env", "key.properties", "google-services.json"}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    DELIVERY.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / "ORBIT_ARM64_USER_SMOKE_TEST.md", OUT / "ORBIT_ARM64_USER_SMOKE_TEST.md")
    shutil.copy2(ROOT / "ORBIT_PROJECT_STATE.json", OUT / "ORBIT_PROJECT_STATE.json")
    screenshot_manifest = OUT / "logs" / "android-screenshot-sha256.txt"
    screenshot_manifest.parent.mkdir(parents=True, exist_ok=True)
    screenshot_manifest.write_text(
        "".join(
            f"{sha256(path)}  {path.name}  {path.stat().st_size} bytes\n"
            for path in sorted((OUT / "screenshots").rglob("*.png"))
        ),
        encoding="utf-8",
        newline="\n",
    )
    source_zip = OUT / "ORBIT_0.5.3_source.zip"
    screenshots_zip = OUT / "ORBIT_0.5.3_screenshots.zip"
    tracked = subprocess.check_output(
        ["git", "-c", "core.quotepath=false", "ls-files"],
        cwd=ROOT,
        text=True,
        encoding="utf-8",
    ).splitlines()
    source_files = [relative for relative in tracked if include_source(relative)]
    evidence = [
        path
        for directory in ["logs", "persistence", "runtime"]
        for path in (OUT / directory).rglob("*")
        if path.is_file()
    ] + [
        OUT / "ORBIT_0.5.3_validation.md",
        OUT / "ORBIT_0.5.3_release_notes.md",
        OUT / "READY_FOR_USER_TESTING.md",
    ]
    with zipfile.ZipFile(source_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for relative in source_files:
            archive.write(ROOT / relative, f"orbit_visual_lab/{relative}")
        for path in evidence:
            archive.write(path, f"orbit_visual_lab/validation/orbit053/{path.relative_to(OUT)}")
    with zipfile.ZipFile(screenshots_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted((OUT / "screenshots").rglob("*.png")):
            archive.write(path, path.relative_to(OUT / "screenshots"))
        for name in ["integration-app.txt", "integration-navigation.txt", "upgrade-launch.log"]:
            archive.write(OUT / "logs" / name, f"logs/{name}")
    for path in [source_zip, screenshots_zip]:
        with zipfile.ZipFile(path) as archive:
            assert archive.testzip() is None, f"ZIP CRC failed: {path}"
    with zipfile.ZipFile(source_zip) as archive:
        names = archive.namelist()
        assert "orbit_visual_lab/pubspec.yaml" in names
        assert "orbit_visual_lab/ORBIT_PROJECT_STATE.json" in names
        assert not any("/build/" in name or name.endswith((".apk", ".jks", ".keystore", ".env")) for name in names)
    artifact_names = [
        "ORBIT_0.5.3_source.zip",
        "ORBIT_0.5.3_android_arm64.apk",
        "ORBIT_0.5.3_android_x86_64.apk",
        "ORBIT_0.5.3_validation.md",
        "ORBIT_0.5.3_screenshots.zip",
        "ORBIT_0.5.3_release_notes.md",
        "ORBIT_ARM64_USER_SMOKE_TEST.md",
        "READY_FOR_USER_TESTING.md",
        "ORBIT_PROJECT_STATE.json",
    ]
    sums = OUT / "ORBIT_0.5.3_SHA256SUMS.txt"
    sums.write_text(
        "".join(f"{sha256(OUT / name)}  {name}\n" for name in artifact_names),
        encoding="utf-8",
        newline="\n",
    )
    artifact_names.append("ORBIT_0.5.3_SHA256SUMS.txt")
    for name in artifact_names:
        shutil.copy2(OUT / name, DELIVERY / name)
    for directory in ["logs", "persistence", "runtime"]:
        shutil.copytree(OUT / directory, DELIVERY / directory, dirs_exist_ok=True)
    for name in artifact_names:
        source = OUT / name
        copied = DELIVERY / name
        assert source.stat().st_size == copied.stat().st_size
        assert sha256(source) == sha256(copied)
        print(f"{name}: {source.stat().st_size} bytes; {sha256(source)}")
    full = DELIVERY / "2026-11-08_ORBIT_0.5.3_FULL_PACKAGE.zip"
    full_files = sorted(
        path
        for path in DELIVERY.rglob("*")
        if path.is_file() and path.name not in {full.name, "2026-11-08_ORBIT_0.5.3_FULL_PACKAGE_SHA256.txt"}
    )
    with zipfile.ZipFile(full, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in full_files:
            archive.write(path, path.relative_to(DELIVERY).as_posix())
    with zipfile.ZipFile(full) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == len(full_files)
        for path in full_files:
            name = path.relative_to(DELIVERY).as_posix()
            assert hashlib.sha256(path.read_bytes()).digest() == hashlib.sha256(archive.read(name)).digest()
    full_sha = DELIVERY / "2026-11-08_ORBIT_0.5.3_FULL_PACKAGE_SHA256.txt"
    full_sha.write_text(f"{sha256(full)}  {full.name}\n", encoding="utf-8")
    print(f"FULL_PACKAGE files={len(full_files)} bytes={full.stat().st_size} sha256={sha256(full)}")


if __name__ == "__main__":
    main()
