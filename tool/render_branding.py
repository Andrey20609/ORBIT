"""Render ORBIT branding PNGs from the user-approved reference artwork.

Reference source of truth: tool/branding/orbit_icon_reference.jpg
(SHA-256 8b948d674958df4d582557f1d46a5f02540550a2c6ff2361683c0d3374ff983e,
2400x1792, user-selected photorealistic glass tor design).

Pipeline (crop -> resize -> minimal tonal correction, content untouched):
  - assets/branding/orbit_icon_master.png   2048x2048 square production master
  - assets/branding/orbit_splash_mark.png   1024 rounded-corner splash variant
  - res/mipmap-*/ic_launcher.png            legacy launcher, full-bleed artwork
  - res/mipmap-xxxhdpi/ic_launcher_foreground.png  adaptive foreground (108dp@4x)
  - res/mipmap-xxxhdpi/ic_launcher_monochrome.png  alpha silhouette (A13+)

Run from the project root:  python tool/render_branding.py
No icon generators are added to pubspec; __pycache__ is not committed.
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "tool" / "branding" / "orbit_icon_reference.jpg"
BRANDING = ROOT / "assets" / "branding"
RES = ROOT / "android" / "app" / "src" / "main" / "res"

# Sampled from the dark edge of the approved reference (bottom corners).
SPLASH_BACKGROUND = "#16182C"

# Square crop around the rounded-square icon of the reference. Only the
# outer field of the original is removed; the tor is centred and untouched.
CROP_BOX = (435, 180, 1965, 1710)  # 1530x1530
MASTER_SIZE = 2048

LEGACY_DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}
ADAPTIVE_FOREGROUND_SIZE = 432  # 108 dp @ xxxhdpi
SPLASH_MARK_SIZE = 1024


def load_reference() -> Image.Image:
    img = Image.open(REFERENCE)
    img = img.convert("RGB")
    return img.crop(CROP_BOX)


def build_master(reference: Image.Image) -> Image.Image:
    """2048x2048 square production master with minimal tonal correction."""
    master = reference.resize((MASTER_SIZE, MASTER_SIZE), Image.LANCZOS)
    # Minimal tonal correction: slightly deepen contrast so the glass tor
    # keeps presence at small launcher sizes (content unchanged).
    master = ImageEnhance.Contrast(master).enhance(1.04)
    master = ImageEnhance.Brightness(master).enhance(0.99)
    return master


def rounded(img: Image.Image, radius_frac: float) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle(
        [0, 0, img.size[0] - 1, img.size[1] - 1],
        radius=int(img.size[0] * radius_frac),
        fill=255,
    )
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def build_monochrome(master: Image.Image) -> Image.Image:
    """Alpha silhouette of the tor + orbit trails (white, luminance-based)."""
    grey = master.convert("L")
    # Normalise around the dark background so the glass tor and the light
    # orbit trails become the bright part of the silhouette.
    min_l, max_l = grey.getextrema()
    span = max(1, max_l - min_l)
    boosted = grey.point(lambda v: min(255, int((v - min_l) / span * 300)))
    boosted = boosted.filter(ImageFilter.GaussianBlur(2))
    silhouette = Image.new("RGBA", master.size, (255, 255, 255, 0))
    silhouette.putalpha(boosted)
    return silhouette


def main() -> None:
    BRANDING.mkdir(parents=True, exist_ok=True)
    reference = load_reference()

    master = build_master(reference)
    master.save(BRANDING / "orbit_icon_master.png")

    splash = rounded(master.resize((SPLASH_MARK_SIZE, SPLASH_MARK_SIZE),
                                  Image.LANCZOS), 0.22)
    splash.save(BRANDING / "orbit_splash_mark.png")

    adaptive_foreground = master.resize(
        (ADAPTIVE_FOREGROUND_SIZE, ADAPTIVE_FOREGROUND_SIZE), Image.LANCZOS)
    foreground_folder = RES / "mipmap-xxxhdpi"
    foreground_folder.mkdir(parents=True, exist_ok=True)
    adaptive_foreground.save(foreground_folder / "ic_launcher_foreground.png")

    mono = build_monochrome(master).resize(
        (ADAPTIVE_FOREGROUND_SIZE, ADAPTIVE_FOREGROUND_SIZE), Image.LANCZOS)
    mono.save(foreground_folder / "ic_launcher_monochrome.png")

    for density, size in LEGACY_DENSITIES.items():
        folder = RES / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        master.resize((size, size), Image.LANCZOS).save(
            folder / "ic_launcher.png")
        print(f"ic_launcher.png {density} {size}x{size}")

    print(f"orbit_icon_master.png {MASTER_SIZE}x{MASTER_SIZE}")
    print(f"orbit_splash_mark.png {SPLASH_MARK_SIZE} rounded")
    print(f"adaptive foreground/monochrome {ADAPTIVE_FOREGROUND_SIZE}px")
    print(f"splash background colour: {SPLASH_BACKGROUND}")


if __name__ == "__main__":
    main()
