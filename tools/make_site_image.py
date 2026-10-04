#!/usr/bin/env python3
"""Makes the picture that a chat shows with a link to the site: site/og.png, 1200 by 630.

The mark of the app (a diamond in a diamond in a diamond, as its icon has it) on the dark of the site, with the name and what the app is.
Run it again to change the picture; the result is kept in the repository, and the site is published with it.

    python3 tools/make_site_image.py
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
TARGET = os.path.normpath(os.path.join(HERE, "..", "site", "og.png"))
SIZE = (1200, 630)
BG = (13, 11, 9)
GOLD = (223, 194, 149)
SOFT = (209, 201, 189)
MUTED = (163, 154, 139)
FONTS = ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
         "C:/Windows/Fonts/segoeuib.ttf", "/System/Library/Fonts/Helvetica.ttc"]
REGULAR = ["/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
           "C:/Windows/Fonts/segoeui.ttf", "/System/Library/Fonts/Helvetica.ttc"]


def font(paths, size):
    for path in paths:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    raise SystemExit("no font found for the picture: put a TrueType font in FONTS")


def fitted(paths, text, size, width):
    """the font at the size, or smaller when the text is not as narrow as the place for it"""
    f = font(paths, size)
    while f.getlength(text) > width and size > 8:
        size -= 2
        f = font(paths, size)
    return f


def mark(layer, cx, cy, radii, stroke, centre):
    """a diamond in a diamond in a diamond, drawn as a shape cut out of another so that every corner is sharp: a ring is the diamond
    that is as far out as the line reaches, less the one that is as far in"""
    draw = ImageDraw.Draw(layer)

    def points(r):
        return [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)]

    reach = stroke / 2 * 2 ** 0.5  # how much further a corner is than the middle of its line, for lines at 45 degrees
    for r in radii:
        draw.polygon(points(r + reach), fill=255)
        draw.polygon(points(r - reach), fill=0)
    draw.polygon(points(centre), fill=255)


def make():
    scale = 2  # drawn twice as large and made smaller, which is what makes the edges smooth
    w, h = SIZE[0] * scale, SIZE[1] * scale
    image = Image.new("RGB", (w, h), BG)
    # a glow of gold behind the mark, not more than a hint
    glow = Image.new("RGB", (w, h), BG)
    ImageDraw.Draw(glow).ellipse((60 * scale, 80 * scale, 540 * scale, 560 * scale), fill=(58, 47, 33))
    image = Image.blend(image, glow.filter(ImageFilter.GaussianBlur(110 * scale)), 1.0)

    layer = Image.new("L", (w, h), 0)
    mark(layer, 300 * scale, 315 * scale, (183 * scale, 112 * scale), 14 * scale, 44 * scale)
    image.paste(Image.new("RGB", (w, h), GOLD), (0, 0), layer)
    draw = ImageDraw.Draw(image)

    # what it says, as wide as the place for it and no wider
    x, room = 560 * scale, 580 * scale
    draw.text((x, 200 * scale), "Tyria Codex", font=fitted(FONTS, "Tyria Codex", 96 * scale, room), fill=(239, 232, 220))
    sub = "Unofficial Guild Wars 2 companion"
    draw.text((x, 326 * scale), sub, font=fitted(REGULAR, sub, 34 * scale, room), fill=GOLD)
    line = "Android  ·  Browser  ·  9 languages"
    draw.text((x, 400 * scale), line, font=fitted(REGULAR, line, 28 * scale, room), fill=SOFT)
    free = "Free  ·  No ads  ·  No analytics  ·  Open source"
    draw.text((x, 452 * scale), free, font=fitted(REGULAR, free, 24 * scale, room), fill=MUTED)

    # a line of gold along the bottom
    draw.rectangle((0, h - 10 * scale, w, h), fill=GOLD)
    return image.resize(SIZE, Image.LANCZOS)


def main():
    make().save(TARGET, optimize=True)
    print("%s: %d bytes" % (TARGET, os.path.getsize(TARGET)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
