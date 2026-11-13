from __future__ import annotations

import hashlib
import json
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "photoreal" / "source"
ASSETS = {
    "kloppenheim_06.jpg": (
        "https://dl.polyhaven.org/file/ph-assets/HDRIs/extra/Tonemapped%20JPG/kloppenheim_06.jpg",
        "e0bae2fe816032852f4c180d4a46ab99",
    ),
    "the_sky_is_on_fire_IMG_0809.jpg": (
        "https://dl.polyhaven.org/file/ph-assets/HDRIs/extra/Backplates/the_sky_is_on_fire/jpg_pretty/IMG_0809.jpg",
        "b1c1bb4ebf0cd355a478e36c4cdee02b",
    ),
    "kloppenheim_06_puresky.jpg": (
        "https://dl.polyhaven.org/file/ph-assets/HDRIs/extra/Tonemapped%20JPG/kloppenheim_06_puresky.jpg",
        "958a8792cecb20d602dab110ebc23e06",
    ),
    "aerial_rocks_02_diff_2k.jpg": (
        "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/aerial_rocks_02/aerial_rocks_02_diff_2k.jpg",
        "f493fa9b31911f8a30ecd1d41cbc6f3d",
    ),
    "aerial_rocks_02_rough_2k.jpg": (
        "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/aerial_rocks_02/aerial_rocks_02_rough_2k.jpg",
        "2d4464ceba47763b2ae75242e6f66270",
    ),
    "aerial_rocks_02_nor_gl_2k.jpg": (
        "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/aerial_rocks_02/aerial_rocks_02_nor_gl_2k.jpg",
        "7c405cfd3308a2672c99b44e102c328e",
    ),
    "kloppenheim_06_2k.hdr": (
        "https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/kloppenheim_06_2k.hdr",
        "86deab62942f3ba6004fda4377769bf7",
    ),
}


def md5(path: Path) -> str:
    digest = hashlib.md5()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _validate_url(url: str) -> None:
    # Assets are pinned by MD5, but the URL itself must stay on the
    # approved CC0 host over https to rule out any redirect/SSRF abuse.
    parts = urllib.parse.urlsplit(url)
    if parts.scheme != "https" or parts.hostname != "dl.polyhaven.org":
        raise RuntimeError(f"Refusing non-allowlisted asset URL: {url}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    for name, (url, expected) in ASSETS.items():
        path = OUT / name
        _validate_url(url)
        if not path.exists() or md5(path) != expected:
            print(f"Downloading {name}", flush=True)
            with urllib.request.urlopen(url, timeout=90) as response:
                path.write_bytes(response.read())
        actual = md5(path)
        if actual != expected:
            raise RuntimeError(f"MD5 mismatch for {name}: {actual} != {expected}")
        manifest.append({"file": name, "url": url, "md5": actual, "bytes": path.stat().st_size})
        print(f"OK {name} {path.stat().st_size} bytes", flush=True)
    (OUT / "download-manifest.json").write_text(
        json.dumps({"license": "CC0-1.0", "assets": manifest}, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
