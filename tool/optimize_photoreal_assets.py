from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "photoreal" / "source"
OUT = ROOT / "assets" / "photoreal" / "optimized"
SCENES = {
    "one.jpg": ("kloppenheim_06.jpg", (0.56, 0.56)),
    "atelier.jpg": ("the_sky_is_on_fire_IMG_0809.jpg", (0.5, 0.56)),
    "zen.jpg": ("kloppenheim_06_puresky.jpg", (0.56, 0.44)),
}
TEXTURES = {
    "aerial_rocks_02_diff_2k.jpg": "rocks_diffuse.jpg",
    "aerial_rocks_02_rough_2k.jpg": "rocks_roughness.jpg",
    "aerial_rocks_02_nor_gl_2k.jpg": "rocks_normal.jpg",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    for output, (source, centering) in SCENES.items():
        with Image.open(SOURCE / source) as image:
            rgb = image.convert("RGB")
            if output == "zen.jpg":
                rgb = rgb.crop((0, 0, rgb.width, int(rgb.height * 0.52)))
            result = ImageOps.fit(
                rgb,
                (1080, 2400),
                method=Image.Resampling.LANCZOS,
                centering=centering,
            )
            path = OUT / output
            result.save(path, "JPEG", quality=91, optimize=True, progressive=True)
            manifest.append({"file": output, "source": source, "size": result.size, "sha256": sha256(path), "bytes": path.stat().st_size})
    for source, output in TEXTURES.items():
        with Image.open(SOURCE / source) as image:
            result = image.convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)
            path = OUT / output
            result.save(path, "JPEG", quality=93, optimize=True)
            manifest.append({"file": output, "source": source, "size": result.size, "sha256": sha256(path), "bytes": path.stat().st_size})
    (OUT / "optimized-manifest.json").write_text(
        json.dumps({"assets": manifest}, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({"assets": manifest}, indent=2))


if __name__ == "__main__":
    main()
