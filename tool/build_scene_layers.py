from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "photoreal" / "optimized"
RANGES = {
    "one": (0.38, 0.57),
    "atelier": (0.45, 0.62),
    "zen": (0.58, 0.76),
}


def main() -> None:
    manifest = {"license": "CC0 derivatives of assets documented in ../LICENSES.md", "layers": []}
    for name, (start, end) in RANGES.items():
        source = Image.open(OUT / f"{name}.jpg").convert("RGBA")
        width, height = source.size
        mask = Image.new("L", source.size)
        pixels = mask.load()
        for y in range(height):
            position = y / (height - 1)
            alpha = min(1, max(0, (position - start) / (end - start)))
            alpha = alpha * alpha * (3 - 2 * alpha)
            for x in range(width):
                pixels[x, y] = round(alpha * 255)
        foreground = source.copy()
        foreground.putalpha(mask)
        path = OUT / f"{name}_foreground.webp"
        foreground.save(path, "WEBP", quality=90, method=6, exact=False)
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        manifest["layers"].append(
            {
                "profile": name,
                "base": f"{name}.jpg",
                "foreground": path.name,
                "alphaStart": start,
                "alphaEnd": end,
                "bytes": path.stat().st_size,
                "sha256": digest,
            }
        )
        print(f"{path.name}: {path.stat().st_size} bytes; {digest}")
    (OUT / "scene-layers-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
