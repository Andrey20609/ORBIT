from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "photoreal" / "optimized"
SIZE = (1080, 2400)
STOP_COLORS = {
    "light": [(242, 251, 253), (217, 239, 244), (234, 231, 248), (248, 252, 254)],
    "dark": [(6, 27, 42), (16, 56, 75), (23, 28, 62), (7, 17, 31)],
}
ACCENTS = {
    "light": ((36, 121, 168), (22, 143, 138), 0.24, 0.16),
    "dark": ((117, 201, 255), (100, 230, 210), 0.42, 0.24),
}
STOPS = (0, 0.38, 0.72, 1)


def gradient(name: str) -> Image.Image:
    colors = STOP_COLORS[name]
    image = Image.new("RGB", SIZE)
    pixels = image.load()
    for y in range(SIZE[1]):
        for x in range(SIZE[0]):
            position = (x / (SIZE[0] - 1) + y / (SIZE[1] - 1)) / 2
            index = next((i for i in range(3) if position <= STOPS[i + 1]), 2)
            local = (position - STOPS[index]) / (STOPS[index + 1] - STOPS[index])
            local = min(1, max(0, local))
            pixels[x, y] = tuple(
                round(colors[index][channel] * (1 - local) + colors[index + 1][channel] * local)
                for channel in range(3)
            )
    return image


def cubic(points, steps=100):
    p0, p1, p2, p3 = points
    result = []
    for index in range(steps + 1):
        t = index / steps
        u = 1 - t
        result.append(
            (
                u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
                u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1],
            )
        )
    return result


def render(name: str) -> None:
    secondary, accent, secondary_alpha, accent_alpha = ACCENTS[name]
    width, height = SIZE
    scale = width / 411.4
    glow = Image.new("RGBA", SIZE)
    draw = ImageDraw.Draw(glow)
    for index in range(7):
        y = height * (0.18 + index * 0.115)
        drift = math.sin(index * 0.72) * 24 * scale
        lift = math.cos(index) * 18 * scale
        points = cubic(
            (
                (-width * 0.15, y + lift),
                (width * 0.22, y - 90 * scale + drift),
                (width * 0.66, y + 105 * scale - drift),
                (width * 1.15, y - 38 * scale + lift),
            )
        )
        color = secondary if index % 2 == 0 else accent
        alpha = round(255 * (secondary_alpha if index % 2 == 0 else accent_alpha))
        draw.line(
            points,
            fill=(*color, alpha),
            width=max(2, round((22 - index * 1.8) * scale)),
            joint="curve",
        )
    glow = glow.filter(ImageFilter.GaussianBlur(14 * scale))
    image = Image.alpha_composite(gradient(name).convert("RGBA"), glow).convert("RGB")
    image.save(OUT / f"flow_{name}.jpg", quality=90, optimize=True, progressive=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name in ["light", "dark"]:
        render(name)
        path = OUT / f"flow_{name}.jpg"
        print(f"{path.name}: {path.stat().st_size} bytes")


if __name__ == "__main__":
    main()
