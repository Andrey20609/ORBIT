from __future__ import annotations

import hashlib
import json
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORK = Path("O:/orbit_visual_lab")
if not WORK.exists():
    WORK = ROOT
OUT = WORK / "validation" / "orbit055_stabilize"
SDK = Path(r"C:\Users\AVBur\AppData\Local\Android\Sdk")
AAPT = SDK / "build-tools" / "36.0.0" / "aapt.exe"
APKSIGNER = SDK / "build-tools" / "36.0.0" / "apksigner.bat"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    results = []
    for abi in ["arm64", "x86_64"]:
        path = OUT / f"ORBIT_0.5.5+11_android_{abi}.apk"
        expected_abi = "arm64-v8a" if abi == "arm64" else "x86_64"
        badging = subprocess.run(
            [str(AAPT), "dump", "badging", str(path)],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        signature = subprocess.run(
            [str(APKSIGNER), "verify", "--verbose", "--print-certs", str(path)],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        (OUT / "logs" / f"apk-{abi}-badging.txt").write_text(badging, encoding="utf-8")
        (OUT / "logs" / f"apk-{abi}-signature.txt").write_text(signature, encoding="utf-8")
        assert "versionCode='11' versionName='0.5.5'" in badging
        assert f"native-code: '{expected_abi}'" in badging
        assert "Verified using v2 scheme (APK Signature Scheme v2): true" in signature
        with zipfile.ZipFile(path) as archive:
            assert archive.testzip() is None
            names = archive.namelist()
            lib_abis = {name.split("/")[1] for name in names if name.startswith("lib/") and name.count("/") >= 2}
            assert lib_abis == {expected_abi}, (abi, lib_abis)
            required = {
                "assets/materials/orbit_pbr.filamat",
                "assets/photoreal/rocks_diffuse.jpg",
                "assets/photoreal/rocks_normal.jpg",
                "assets/photoreal/rocks_roughness.jpg",
                *{
                    f"assets/flutter_assets/assets/photoreal/optimized/{name}.jpg"
                    for name in ["one", "atelier", "zen", "flow_light", "flow_dark"]
                },
                "assets/flutter_assets/assets/photoreal/optimized/one_foreground.webp",
                "assets/flutter_assets/assets/photoreal/optimized/atelier_foreground.webp",
                "assets/flutter_assets/assets/photoreal/optimized/zen_foreground.webp",
            }
            missing = sorted(required - set(names))
            assert not missing, (abi, missing)
        result = {
            "file": path.name,
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
            "versionName": "0.5.5",
            "versionCode": 11,
            "abi": expected_abi,
            "zipCrc": "PASS",
            "apkSignatureV2": "PASS",
            "signatureIdentity": "Android Debug; test-only",
            "requiredGraphicsAssets": "PASS",
        }
        results.append(result)
        print(json.dumps(result, ensure_ascii=False), flush=True)
    (OUT / "runtime" / "apk-static-verification.json").write_text(
        json.dumps({"status": "PASS", "apks": results}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
