#!/usr/bin/env python3
"""Renders the DMG window background, Support/DMGBackground.png and @2x (660 x 420 pt).

The artwork matches the app icon: a dark canvas lit by soft halo-colored glows, a title,
and a glowing arrow from where Halo.app sits to where the Applications link sits. The icon
names are drawn here in white: Finder draws its own labels dark on a background picture,
where they vanish, and offers no way to change their color. The PNGs
are committed, so packing the DMG needs neither Python nor these packages.

    python3 -m pip install numpy pillow
    python3 scripts/dmg/render-background.py

scripts/dmg.sh places the icons at the centers below (APP and APPLICATIONS); keep the two
in sync.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

WIDTH, HEIGHT = 660, 420
APP = (180, 215)
APPLICATIONS = (480, 215)
ICON = 128
NAMES_Y = 303
FONT = "/System/Library/Fonts/SFNS.ttf"
OUT = Path(__file__).resolve().parents[2] / "Support"

# Halo colors along the arrow, left to right (as in scripts/icon/render-icon.py).
STOPS = [
    (0.00, (10, 132, 255)),   # blue
    (0.35, (191, 90, 242)),   # purple
    (0.70, (255, 55, 95)),    # pink
    (1.00, (255, 159, 10)),   # orange
]


def gradient(t):
    t = np.clip(t, 0, 1)
    channels = []
    for c in range(3):
        channels.append(np.interp(t, [s[0] for s in STOPS], [s[1][c] for s in STOPS]))
    return np.stack(channels, axis=-1)


def glow(xx, yy, center, radius, color, strength):
    d2 = ((xx - center[0]) ** 2 + (yy - center[1]) ** 2) / radius**2
    return np.exp(-d2)[..., None] * np.array(color) * strength


def render(scale):
    w, h = WIDTH * scale, HEIGHT * scale
    xx, yy = np.meshgrid((np.arange(w) + 0.5) / scale, (np.arange(h) + 0.5) / scale)

    # Canvas: near black, a touch lighter at the top, with faint glows behind the icons.
    base = np.array([14, 14, 18]) + (1 - yy / HEIGHT)[..., None] * np.array([10, 9, 12])
    image = base
    image = image + glow(xx, yy, APP, 170, (10, 132, 255), 0.16)
    image = image + glow(xx, yy, APPLICATIONS, 170, (255, 55, 95), 0.13)
    image = image + glow(xx, yy, ((APP[0] + APPLICATIONS[0]) / 2, APP[1]), 120, (191, 90, 242), 0.10)
    canvas = Image.fromarray(np.clip(image, 0, 255).astype(np.uint8), "RGB")

    # Arrow: a gradient stroke with a head, plus a blurred copy as its glow.
    y = APP[1] * scale
    x0 = (APP[0] + ICON / 2 + 26) * scale
    x1 = (APPLICATIONS[0] - ICON / 2 - 26) * scale
    stroke = 5 * scale
    head = 14 * scale
    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    draw.line([(x0, y), (x1 - head * 0.6, y)], fill=255, width=stroke)
    draw.ellipse([x0 - stroke / 2, y - stroke / 2, x0 + stroke / 2, y + stroke / 2], fill=255)
    draw.polygon([(x1, y), (x1 - head * 1.3, y - head), (x1 - head * 1.3, y + head)], fill=255)
    colors = Image.fromarray(gradient((xx * scale - x0) / (x1 - x0)).astype(np.uint8), "RGB")
    halo = mask.filter(ImageFilter.GaussianBlur(9 * scale)).point(lambda v: int(v * 0.9))
    canvas = Image.composite(colors, canvas, halo)
    canvas = Image.composite(colors, canvas, mask)

    # Title and hint, centered above the icons.
    draw = ImageDraw.Draw(canvas)
    title = ImageFont.truetype(FONT, 30 * scale)
    title.set_variation_by_name("Bold")
    hint = ImageFont.truetype(FONT, 14 * scale)
    hint.set_variation_by_name("Medium")
    draw.text((w / 2, 62 * scale), "Installa Halo", font=title, fill=(255, 255, 255), anchor="mm")
    draw.text(
        (w / 2, 96 * scale),
        "Trascina Halo nella cartella Applicazioni",
        font=hint,
        fill=(160, 160, 170),
        anchor="mm",
    )
    # Icon names right under Finder's own small dark labels, which vanish on this canvas.
    name = ImageFont.truetype(FONT, 14 * scale)
    name.set_variation_by_name("Semibold")
    for center, text in ((APP, "Halo"), (APPLICATIONS, "Applicazioni")):
        draw.text((center[0] * scale, NAMES_Y * scale), text, font=name, fill=(255, 255, 255), anchor="mm")
    return canvas


if __name__ == "__main__":
    render(1).save(OUT / "DMGBackground.png")
    render(2).save(OUT / "DMGBackground@2x.png")
    print(f"Wrote {OUT / 'DMGBackground.png'} and @2x")
