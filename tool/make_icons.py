#!/usr/bin/env python3
"""
Draws the Homesky app icon (sunset behind a roof) and saves it in every size
Android and Windows need, into assets/icon/.

You only need to run this if you change the icon design:
    pip install pillow
    python3 tool/make_icons.py

The build (.github/workflows/build.yml) copies the finished files into the
generated android/ and windows/ folders, so the build itself needs no Python
image tools.
"""

from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets" / "icon"

# Colours – keep in sync with lib/ui/theme.dart
BG = (9, 11, 17, 255)          # HS.header
PINK = (238, 95, 156, 255)     # HS.pink
PURPLE = (184, 107, 196, 255)  # HS.purple
BLUE = (110, 159, 201, 255)    # HS.mLight
CYAN = (70, 201, 216, 255)     # HS.cyan

MASTER = 1024   # master size in pixels
SUPER = 4       # draw 4× bigger, then shrink, for smooth edges


def draw_master() -> Image.Image:
    size = MASTER * SUPER
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Rounded-square background.
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=int(size * 0.22), fill=BG)

    # The logo is designed on a 140 × 140 grid (same as lib/ui/widgets/logo.dart).
    s = size * 0.0055            # grid unit → pixels (logo ≈ 77 % of the icon)
    ox = size / 2 - 70 * s       # centre the logo
    oy = size / 2 - 72 * s

    def P(x, y):
        return (ox + x * s, oy + y * s)

    # 1) Striped sun: bands clipped to a circle (drawn via a mask).
    sun = Image.new("RGBA", (size, size), BG)  # gaps between bands show the background
    sd = ImageDraw.Draw(sun)
    for top, height, colour in [(24, 44, PINK), (72, 14, PURPLE), (90, 9, BLUE), (103, 5, CYAN)]:
        sd.rectangle([P(0, top), P(140, top + height)], fill=colour)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse([P(20, 20), P(120, 120)], fill=255)
    img.paste(sun, (0, 0), mask)

    # 2) Hide the bottom of the sun behind the house.
    d.polygon([P(0, 118), P(70, 58), P(140, 118), P(140, 140), P(0, 140)], fill=BG)

    # 3) Roof line with round ends.
    width = int(11 * s)
    a, b, c = P(14, 116), P(70, 68), P(126, 116)
    d.line([a, b, c], fill=BLUE, width=width, joint="curve")
    r = width / 2
    for x, y in (a, c):
        d.ellipse([x - r, y - r, x + r, y + r], fill=BLUE)

    return img.resize((MASTER, MASTER), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    master = draw_master()
    master.save(OUT / "icon_1024.png")

    # Android launcher icons (folder name → size in pixels).
    android = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for folder, px in android.items():
        master.resize((px, px), Image.LANCZOS).save(OUT / f"ic_launcher_{folder}.png")

    # Windows icon file containing several sizes.
    master.save(OUT / "app_icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])

    print("Icons written to", OUT)


if __name__ == "__main__":
    main()
