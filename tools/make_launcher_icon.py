"""Render the Android launcher icon from the app's emblem.

The icon is the DiamondEmblem the menu header draws next to the app name
(lib/widgets/common.dart): two nested diamond outlines and a small filled
diamond, in the theme's gold, here on the theme's dark background.

Writes into ci/launcher/res, which the release job copies over the default
Flutter icons after `flutter create`:

  * mipmap-*/ic_launcher.png            classic square icons, every density
  * mipmap-*/ic_launcher_foreground.png adaptive icon layer (android 8+)
  * mipmap-*/ic_launcher_monochrome.png themed icon layer (android 13+)
  * mipmap-anydpi-v26/ic_launcher.xml   ties the adaptive layers together
  * values/ic_launcher_background.xml   the adaptive background colour
  * drawable-*/ic_stat_tyria.png        the small icon of notifications, white on clear,
                                        drawn bolder and filling its square because the
                                        status bar shows it about 24dp across
  * ci/launcher/play_store_512.png      for a store listing later

Usage: python tools/make_launcher_icon.py
"""

import os

from PIL import Image, ImageDraw

GOLD = (0xDF, 0xC2, 0x95, 255)
BG = (0x0D, 0x0B, 0x09, 255)
WHITE = (255, 255, 255, 255)
OUT = os.path.join("ci", "launcher")
RES = os.path.join(OUT, "res")

# classic icon size in pixels per density, the adaptive layers are 108/48 of it
DENSITIES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
SUPERSAMPLE = 8


def diamond(cx, cy, r):
    return [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)]


def draw_emblem(draw, cx, cy, size, color, bold=False):
    """same proportions as _EmblemPainter: outer and inner outline, filled core.
    bold makes the lines and the core thicker, for an icon a few pixels wide"""
    stroke = max(1, round(size * (0.075 if bold else 0.055)))
    outer = size / 2 - stroke
    # a bold emblem keeps a clear gap between its three parts, they are only a few pixels apart
    inner = size / 2 - size * (0.245 if bold else 0.22)
    core = size * (0.11 if bold else 0.1)
    for r in (outer, inner):
        # a closed polygon joins its last side to the first cleanly, a
        # polyline back to its start leaves a notch at the top corner
        draw.polygon(diamond(cx, cy, r), outline=color, width=stroke)
    draw.polygon(diamond(cx, cy, core), fill=color)


def render(px, background, color, emblem_share, bold=False):
    """one square image, drawn large and scaled down for smooth edges"""
    big = px * SUPERSAMPLE
    img = Image.new("RGBA", (big, big), background)
    draw_emblem(ImageDraw.Draw(img), big / 2, big / 2, big * emblem_share, color, bold)
    return img.resize((px, px), Image.LANCZOS)


# a notification's small icon is 24dp, in pixels per density. android shows only its
# outline, colour is ignored, so it is white on clear
NOTIFICATION_DENSITIES = {"mdpi": 24, "hdpi": 36, "xhdpi": 48, "xxhdpi": 72, "xxxhdpi": 96}


def write_notification_icons():
    """the emblem fills nearly all of its square: the adaptive icon's monochrome layer leaves
    the emblem a third of its width for a safe zone, which made it tiny in the status bar"""
    clear = (0, 0, 0, 0)
    for density, px in NOTIFICATION_DENSITIES.items():
        write(render(px, clear, WHITE, 0.92, bold=True), RES, "drawable-%s" % density, "ic_stat_tyria.png")


def write(img, *parts):
    path = os.path.join(*parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)


def main():
    clear = (0, 0, 0, 0)
    for density, px in DENSITIES.items():
        folder = os.path.join(RES, "mipmap-%s" % density)
        # the classic icon fills its square, launchers round it themselves
        write(render(px, BG, GOLD, 0.62), folder, "ic_launcher.png")
        # adaptive layers are 108dp with a 66dp safe circle in the middle
        layer = round(px * 108 / 48)
        write(render(layer, clear, GOLD, 0.42), folder, "ic_launcher_foreground.png")
        write(render(layer, clear, WHITE, 0.42), folder, "ic_launcher_monochrome.png")

    write_notification_icons()

    anydpi = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    with open(os.path.join(anydpi, "ic_launcher.xml"), "w") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background"/>\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
            "</adaptive-icon>\n"
        )
    values = os.path.join(RES, "values")
    os.makedirs(values, exist_ok=True)
    with open(os.path.join(values, "ic_launcher_background.xml"), "w") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<resources>\n"
            '    <color name="ic_launcher_background">#0D0B09</color>\n'
            "</resources>\n"
        )
    write(render(512, BG, GOLD, 0.62), OUT, "play_store_512.png")
    print("launcher icons written to", RES)


if __name__ == "__main__":
    main()
