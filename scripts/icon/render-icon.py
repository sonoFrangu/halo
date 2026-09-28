#!/usr/bin/env python3
"""Renders Halo's app icon, Support/AppIcon.png (1024 x 1024).

The artwork: a black island (the Dynamic Island pill) floating in a dark squircle,
circled by a luminous halo whose colors turn around it. Drawn procedurally so it can be
tweaked and re-rendered; the PNG is committed, so building the app needs neither Python
nor these packages.

    python3 -m pip install numpy pillow
    python3 scripts/icon/render-icon.py

The body follows the macOS icon grid: an 824 pt squircle centered on the 1024 pt canvas,
with the drop shadow drawn in the margin.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

SIZE = 1024
SCALE = 2  # supersampling
N = SIZE * SCALE
OUT = Path(__file__).resolve().parents[2] / "Support" / "AppIcon.png"

# Halo colors, clockwise from the top.
STOPS = [
    (0.00, (255, 159, 10)),   # orange
    (0.17, (255, 55, 95)),    # pink
    (0.36, (191, 90, 242)),   # purple
    (0.55, (94, 92, 230)),    # indigo
    (0.72, (10, 132, 255)),   # blue
    (0.86, (100, 210, 255)),  # cyan
    (1.00, (255, 159, 10)),   # back to orange
]


def grid():
    coords = (np.arange(N) + 0.5) / SCALE
    return np.meshgrid(coords, coords)


def squircle_mask(x, y, cx, cy, half, exponent=4.6):
    """Anti-aliased superellipse |x|^n + |y|^n <= 1, close to Apple's continuous corners."""
    u = np.abs(x - cx) / half
    v = np.abs(y - cy) / half
    value = u**exponent + v**exponent
    # Approximate distance to the edge in points from the implicit function.
    edge = (value ** (1 / exponent) - 1) * half
    return np.clip(0.5 - edge * SCALE / 2, 0, 1)


def stadium_distance(x, y, cx, cy, half_width, radius):
    """Signed distance to a horizontal capsule."""
    px = np.maximum(np.abs(x - cx) - (half_width - radius), 0)
    py = np.abs(y - cy)
    return np.sqrt(px**2 + py**2) - radius


def conic_colors(x, y, cx, cy, rotation=0.0):
    angle = (np.arctan2(x - cx, -(y - cy)) / (2 * np.pi) + rotation) % 1.0
    positions = np.array([s[0] for s in STOPS])
    colors = np.array([s[1] for s in STOPS], dtype=np.float64) / 255
    out = np.empty(angle.shape + (3,))
    for channel in range(3):
        out[..., channel] = np.interp(angle, positions, colors[:, channel])
    return out


def blend(base, color, alpha):
    alpha = alpha[..., None]
    return base * (1 - alpha) + color * alpha


def main():
    x, y = grid()
    cx, cy = SIZE / 2, SIZE / 2
    half = 412

    body = squircle_mask(x, y, cx, cy, half)

    # Background: graphite lit from above, falling to near black.
    r = np.sqrt((x - cx) ** 2 + (y - (cy - 260)) ** 2) / 900
    shade = np.clip(1 - r, 0, 1) ** 1.6
    top = np.array([0.155, 0.155, 0.175])
    bottom = np.array([0.018, 0.018, 0.024])
    rgb = bottom + (top - bottom) * shade[..., None]

    # The island and its halo.
    island_cx, island_cy = cx, cy - 18
    half_width, radius = 238, 84
    distance = stadium_distance(x, y, island_cx, island_cy, half_width, radius)
    colors = conic_colors(x, y, island_cx, island_cy, rotation=0.04)

    ring_offset = 32
    ring = np.exp(-(((distance - ring_offset) / 5.5) ** 2))
    glow = np.exp(-(((distance - ring_offset) / 40) ** 2)) * 0.6
    haze = np.exp(-np.clip(distance - ring_offset, 0, None) / 140) * 0.2
    rgb = blend(rgb, colors, np.clip(haze, 0, 1))
    rgb = blend(rgb, colors, np.clip(glow, 0, 1))
    rgb = blend(rgb, np.clip(colors * 0.55 + 0.45, 0, 1), np.clip(ring, 0, 1))

    # The pill: pure black with a faint rim of light on its upper edge.
    pill = np.clip(0.5 - distance * SCALE / 2, 0, 1)
    rgb = blend(rgb, np.zeros(3), pill)
    rim = np.exp(-(((distance + 2.5) / 2.2) ** 2)) * np.clip((island_cy - y) / radius, 0, 1) * 0.22
    rgb = blend(rgb, np.ones(3), np.clip(rim, 0, 1) * pill)

    # Now playing inside the island: the artwork and a small equalizer in the halo colors.
    art_cx, art_cy, art_half, art_radius = island_cx - half_width + radius, island_cy, 40, 18
    qx = np.maximum(np.abs(x - art_cx) - (art_half - art_radius), 0)
    qy = np.maximum(np.abs(y - art_cy) - (art_half - art_radius), 0)
    art_distance = np.sqrt(qx**2 + qy**2) - art_radius
    art = np.clip(0.5 - art_distance * SCALE / 2, 0, 1)
    t = np.clip(((x - art_cx) + (y - art_cy)) / (4 * art_half) + 0.5, 0, 1)[..., None]
    art_colors = np.array([0.75, 0.33, 0.95]) * (1 - t) + np.array([1.0, 0.62, 0.08]) * t
    rgb = blend(rgb, art_colors, art)

    bars = np.zeros_like(x)
    bar_heights = [34, 62, 46, 74, 40]
    bar_x0 = island_cx + half_width - radius - 66
    for index, height in enumerate(bar_heights):
        bx = bar_x0 + index * 26
        bar = stadium_distance(y, x, island_cy, bx, height / 2, 7.5)  # vertical capsule
        bars = np.maximum(bars, np.clip(0.5 - bar * SCALE / 2, 0, 1))
    bar_colors = conic_colors(x, y, island_cx, island_cy, rotation=0.55)
    rgb = blend(rgb, np.clip(bar_colors * 0.3 + 0.7, 0, 1), bars)

    # A thin highlight along the top of the body.
    edge = squircle_mask(x, y, cx, cy, half - 3)
    rim_light = np.clip(body - edge, 0, 1) * np.clip((cy - y) / half, 0, 1) * 0.35
    rgb = blend(rgb, np.ones(3), rim_light)

    art_layer = np.dstack([np.clip(rgb, 0, 1), body])
    image = Image.fromarray((art_layer * 255 + 0.5).astype(np.uint8), "RGBA")
    image = image.resize((SIZE, SIZE), Image.LANCZOS)

    # Soft drop shadow in the margin, as on the macOS icon grid.
    shadow_alpha = Image.fromarray((body * 255).astype(np.uint8), "L").resize((SIZE, SIZE), Image.LANCZOS)
    shadow_alpha = shadow_alpha.filter(ImageFilter.GaussianBlur(14)).point(lambda value: int(value * 0.45))
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow.putalpha(shadow_alpha)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(shadow, (0, 12))
    canvas.alpha_composite(image)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT, optimize=True)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
