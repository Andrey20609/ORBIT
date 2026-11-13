"""Render the ORBIT master mark to PNGs used by the app.

Design source of truth: assets/branding/orbit_icon_master.svg (kept in the
repository). This script rasterises the same geometry (ring with gap,
tilted orbit, satellite) with supersampled anti-aliasing and emits:
  - assets/branding/orbit_splash_mark.png        1024x1024 transparent
  - res/mipmap-*/ic_launcher.png                 legacy launcher, #0B1026 bg

Run from the project root:  python tool/render_branding.py
No third-party assets are used; no icon generators are added to pubspec.
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BRANDING = ROOT / "assets" / "branding"
RES = ROOT / "android" / "app" / "src" / "main" / "res"

BACKGROUND = (0x0B, 0x10, 0x26)
BLUE = (0x6C, 0x8C, 0xFF)
VIOLET = (0x9B, 0x6C, 0xFF)
ORBIT_INK = (0x8A, 0x8F, 0xBC)
SATELLITE = (0xEA, 0xF0, 0xFF)

CENTER = 512.0
RING_RADIUS = 230.0
RING_WIDTH = 44.0
GAP_CENTER_DEG = -45.0  # upper-right, screen coordinates (y down)
GAP_SPAN_DEG = 24.0
ORBIT_RX = 330.0
ORBIT_RY = 128.0
ORBIT_ROT_DEG = -24.0
ORBIT_WIDTH = 8.0
SATELLITE_RADIUS = 30.0
SATELLITE_AT_DEG = -50.0

SUPERSAMPLE = 4  # 4096 px render, downsampled -> clean anti-aliasing


def _gradient_at(angle_deg: float) -> tuple[int, int, int]:
    """Blue->violet interpolation along the ring (0 deg at east, cw)."""
    t = (angle_deg % 360.0) / 360.0
    return tuple(round(BLUE[i] + (VIOLET[i] - BLUE[i]) * t) for i in range(3))


def _draw_mark(draw: ImageDraw.ImageDraw, scale: float, size: int,
               background: tuple[int, int, int] | None) -> None:
    if background is not None:
        draw.rectangle([0, 0, size - 1, size - 1], fill=background)

    # All master-geometry constants live in the 1024 space; scale once.
    center = CENTER * scale
    ring_r = RING_RADIUS * scale
    ring_w = RING_WIDTH * scale
    orbit_rx = ORBIT_RX * scale
    orbit_ry = ORBIT_RY * scale
    orbit_w = max(1, round(ORBIT_WIDTH * scale))
    sat_r = SATELLITE_RADIUS * scale

    # Tilted orbit ellipse (thin, subtle).
    rot = math.radians(ORBIT_ROT_DEG)
    cos_r, sin_r = math.cos(rot), math.sin(rot)
    points = []
    for i in range(721):
        t = 2 * math.pi * i / 720
        x = orbit_rx * math.cos(t)
        y = orbit_ry * math.sin(t)
        px = center + x * cos_r - y * sin_r
        py = center + x * sin_r + y * cos_r
        points.append((px, py))
    draw.line(points, fill=(*ORBIT_INK, 128), width=orbit_w)

    # Satellite glow (soft, decorative).
    sat_angle = math.radians(SATELLITE_AT_DEG)
    sx = center + orbit_rx * math.cos(sat_angle) * cos_r - \
        orbit_ry * math.sin(sat_angle) * sin_r
    sy = center + orbit_rx * math.cos(sat_angle) * sin_r + \
        orbit_ry * math.sin(sat_angle) * cos_r
    glow_r = sat_r * 2.6
    for layer in range(6, 0, -1):
        alpha = 8 * layer
        f = layer / 6
        draw.ellipse(
            [sx - glow_r * f, sy - glow_r * f,
             sx + glow_r * f, sy + glow_r * f],
            fill=(*SATELLITE, alpha),
        )

    # Broken ring: per-angle wedges give per-pixel gradient colours.
    gap_half = math.radians(GAP_SPAN_DEG / 2)
    gap_center = math.radians(GAP_CENTER_DEG)
    start = gap_center + gap_half
    end = gap_center - gap_half + 2 * math.pi
    outer = ring_r + ring_w / 2
    hole = ring_r - ring_w / 2
    cap = math.radians(2.2)  # rounded caps near the gap ends
    step = (end - start) / 1440
    for i in range(1441):
        angle = start + step * i
        colour = _gradient_at(math.degrees(angle))
        a0 = angle - min(0.0025, step) - cap * 0.12
        a1 = angle + min(0.0025, step) + cap * 0.12
        draw.pieslice(
            [center - outer, center - outer, center + outer, center + outer],
            math.degrees(a0), math.degrees(a1),
            fill=(*colour, 255),
        )
    # Punch the inner hole back out (pieslice drew full wedges).
    hole_fill = (*background, 255) if background is not None else (0, 0, 0, 0)
    draw.ellipse([center - hole, center - hole,
                  center + hole, center + hole], fill=hole_fill)

    # Satellite body (opaque, on top).
    draw.ellipse([sx - sat_r, sy - sat_r, sx + sat_r, sy + sat_r],
                 fill=(*SATELLITE, 255))


def render_mark(size: int) -> Image.Image:
    """Transparent render of the master mark at the requested size."""
    big = size * SUPERSAMPLE
    canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    _draw_mark(draw, big / 1024.0, big, None)
    return canvas.resize((size, size), Image.LANCZOS)


def render_launcher(size: int) -> Image.Image:
    """Legacy launcher PNG: #0B1026 background + centred mark."""
    big = size * SUPERSAMPLE
    canvas = Image.new("RGBA", (big, big), (*BACKGROUND, 255))
    mark = render_mark(size * SUPERSAMPLE).resize((big, big), Image.LANCZOS)
    canvas.alpha_composite(mark)
    return canvas.convert("RGB").resize((size, size), Image.LANCZOS)


def main() -> None:
    BRANDING.mkdir(parents=True, exist_ok=True)
    render_mark(1024).save(BRANDING / "orbit_splash_mark.png")

    densities = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    for density, size in densities.items():
        folder = RES / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        render_launcher(size).save(folder / "ic_launcher.png")
        print(f"ic_launcher.png {density} {size}x{size}")
    print("orbit_splash_mark.png 1024x1024")


if __name__ == "__main__":
    main()
