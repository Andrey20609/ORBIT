from __future__ import annotations

import hashlib
import shutil
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "validation" / "orbit05"
DELIVERY = ROOT.parent / "ORBIT_AI_EXCHANGE" / "02_RESULTS_FROM_KIMI" / "2026-11-07_ORBIT_0.5"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def include_source(relative: str) -> bool:
    path = Path(relative)
    forbidden_parts = {".git", ".dart_tool", "build", "artifacts", "failures", "coverage"}
    if any(part in forbidden_parts for part in path.parts):
        return False
    if relative.startswith("validation/"):
        return False
    if path.suffix.lower() in {".apk", ".zip", ".log", ".pid", ".jks", ".keystore"}:
        return False
    return path.name not in {".env", "key.properties", "google-services.json"}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    DELIVERY.mkdir(parents=True, exist_ok=True)
    source_zip = OUT / "ORBIT_0.5_source.zip"
    screenshots_zip = OUT / "ORBIT_0.5_screenshots.zip"
    tracked = subprocess.check_output(
        ["git", "-c", "core.quotepath=false", "ls-files"],
        cwd=ROOT,
        text=True,
        encoding="utf-8",
    ).splitlines()
    source_files = [relative for relative in tracked if include_source(relative)]
    evidence_files = [
        path
        for path in (OUT / "logs").rglob("*")
        if path.is_file()
    ] + [
        path
        for path in (OUT / "persistence").rglob("*")
        if path.is_file()
    ] + [
        OUT / "ORBIT_0.5_validation.md",
        OUT / "ORBIT_0.5_release_notes.md",
        OUT / "BLOCKED_ORBIT_0.5.md",
    ]
    with zipfile.ZipFile(source_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for relative in source_files:
            archive.write(ROOT / relative, f"orbit_visual_lab/{relative}")
        for path in evidence_files:
            archive.write(path, f"orbit_visual_lab/validation/orbit05/{path.relative_to(OUT)}")
    with zipfile.ZipFile(screenshots_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted((OUT / "screenshots").rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(OUT / "screenshots"))
        for name in [
            "integration-app-final.txt",
            "integration-navigation-final.txt",
            "release-x86-safe-launch.log",
        ]:
            archive.write(OUT / "logs" / name, f"logs/{name}")
    for path in [source_zip, screenshots_zip]:
        with zipfile.ZipFile(path) as archive:
            assert archive.testzip() is None, f"ZIP CRC failed: {path}"
    with zipfile.ZipFile(source_zip) as archive:
        names = archive.namelist()
        assert "orbit_visual_lab/pubspec.yaml" in names
        assert "orbit_visual_lab/ORBIT_PROJECT_STATE.json" in names
        assert not any("/build/" in name or name.endswith((".apk", ".jks", ".keystore")) for name in names)
    shutil.copy2(ROOT / "ORBIT_PROJECT_STATE.json", OUT / "ORBIT_PROJECT_STATE.json")
    artifact_names = [
        "ORBIT_0.5_source.zip",
        "ORBIT_0.5_android_arm64.apk",
        "ORBIT_0.5_android_x86_64.apk",
        "ORBIT_0.5_validation.md",
        "ORBIT_0.5_screenshots.zip",
        "ORBIT_0.5_release_notes.md",
        "ORBIT_PROJECT_STATE.json",
    ]
    sums = OUT / "ORBIT_0.5_SHA256SUMS.txt"
    sums.write_text(
        "".join(f"{sha256(OUT / name)}  {name}\n" for name in artifact_names),
        encoding="utf-8",
        newline="\n",
    )
    artifact_names.append("ORBIT_0.5_SHA256SUMS.txt")
    for name in artifact_names:
        shutil.copy2(OUT / name, DELIVERY / name)
    for directory in ["logs", "persistence"]:
        shutil.copytree(OUT / directory, DELIVERY / directory, dirs_exist_ok=True)
    for name in artifact_names:
        source = OUT / name
        copied = DELIVERY / name
        assert source.stat().st_size == copied.stat().st_size
        assert sha256(source) == sha256(copied)
        print(f"{name}: {source.stat().st_size} bytes; {sha256(source)}")


if __name__ == "__main__":
    main()
