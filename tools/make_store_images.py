#!/usr/bin/env python3
"""Makes the pictures of the store listing and of the repository, in docs/store:

  * feature-1024x500.png   the feature graphic of the Play store listing, no transparency
  * social-preview.png     1280 by 640, what GitHub shows with a link to the repository (Settings, Social preview)

The mark and the colours are those of the picture of the site (tools/make_site_image.py); the icon of the listing is made with
the launcher icons (tools/make_launcher_icon.py). The screenshots in docs/screenshots are taken from the app, not made here.

    python3 tools/make_store_images.py
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

from make_site_image import BG, FONTS, GOLD, MUTED, REGULAR, SOFT, fitted, mark

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "docs", "store"))
TITLE = (239, 232, 220)


def banner(size, centre, radii, stroke, core, x, top, sizes, lines):
    """the mark on the left in a soft glow, and what it says on the right: the name, then the lines under it, each smaller"""
    scale = 2
    w, h = size[0] * scale, size[1] * scale
    image = Image.new("RGB", (w, h), BG)
    glow = Image.new("RGB", (w, h), BG)
    cx, cy = centre
    reach = radii[0] + 50
    ImageDraw.Draw(glow).ellipse(((cx - reach) * scale, (cy - reach) * scale, (cx + reach) * scale, (cy + reach) * scale),
                                 fill=(58, 47, 33))
    image = Image.blend(image, glow.filter(ImageFilter.GaussianBlur(90 * scale)), 1.0)

    layer = Image.new("L", (w, h), 0)
    mark(layer, cx * scale, cy * scale, tuple(r * scale for r in radii), stroke * scale, core * scale)
    image.paste(Image.new("RGB", (w, h), GOLD), (0, 0), layer)

    draw = ImageDraw.Draw(image)
    room = (size[0] - x - 40) * scale
    y = top
    colours = (TITLE, GOLD, SOFT, MUTED)
    for (text, px, gap), colour in zip(zip(lines, sizes[0], sizes[1]), colours):
        draw.text((x * scale, y * scale), text, font=fitted(FONTS if colour == TITLE else REGULAR, text, px * scale, room),
                  fill=colour)
        y += gap
    draw.rectangle((0, h - 8 * scale, w, h), fill=GOLD)
    return image.resize(size, Image.LANCZOS)


LINES = ("Wondrous Compass", "Your Guild Wars 2 companion", "World bosses  ·  Trading post  ·  Characters",
         "Free  ·  No ads  ·  9 languages")


def main():
    os.makedirs(OUT, exist_ok=True)
    feature = banner((1024, 500), (240, 250), (150, 92), 12, 36, 450, 150, ((76, 32, 22, 20), (102, 60, 40, 0)), LINES)
    social = banner((1280, 640), (310, 320), (190, 116), 15, 46, 560, 190, ((96, 40, 28, 25), (130, 76, 50, 0)), LINES)
    for name, image in (("feature-1024x500.png", feature), ("social-preview.png", social)):
        path = os.path.join(OUT, name)
        image.save(path, optimize=True)
        print("%s: %d bytes" % (path, os.path.getsize(path)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
