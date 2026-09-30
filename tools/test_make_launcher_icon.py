import os
import unittest

from PIL import Image

import make_launcher_icon as icons

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ci", "launcher", "res")


def runs(values):
    """how many separate stretches of true there are"""
    count, inside = 0, False
    for v in values:
        if v and not inside:
            count += 1
        inside = v
    return count


class NotificationIconTest(unittest.TestCase):
    def icon(self, density):
        return Image.open(os.path.join(ROOT, "drawable-%s" % density, "ic_stat_tyria.png")).convert("RGBA")

    def test_every_density_has_the_size_of_a_24dp_icon(self):
        for density, px in icons.NOTIFICATION_DENSITIES.items():
            self.assertEqual(self.icon(density).size, (px, px), density)

    def test_it_is_white_on_clear_because_android_shows_only_its_outline(self):
        for density in icons.NOTIFICATION_DENSITIES:
            img = self.icon(density)
            for r, g, b, a in img.getdata():
                if a > 0:
                    self.assertEqual((r, g, b), (255, 255, 255), density)
            self.assertEqual(img.getpixel((0, 0))[3], 0, "a clear corner")

    def test_it_fills_its_square_where_the_adaptive_layer_left_a_third(self):
        for density in icons.NOTIFICATION_DENSITIES:
            img = self.icon(density)
            box = img.split()[3].point(lambda a: 255 if a > 40 else 0).getbbox()
            share = (box[2] - box[0]) / img.size[0]
            self.assertGreater(share, 0.75, "%s fills %.0f%%" % (density, share * 100))
        mono = Image.open(os.path.join(ROOT, "mipmap-xxxhdpi", "ic_launcher_monochrome.png")).convert("RGBA")
        box = mono.split()[3].getbbox()
        self.assertLess((box[2] - box[0]) / mono.size[0], 0.5, "the layer it replaces is small")

    def test_the_three_parts_of_the_emblem_stay_apart(self):
        # along the middle row from the edge to the centre: the outer outline, the inner
        # outline and the core, with clear gaps between them, at the sizes a phone uses
        for density in ("xhdpi", "xxhdpi", "xxxhdpi"):
            img = self.icon(density)
            mid = img.size[1] // 2
            row = [img.getpixel((x, mid))[3] > 128 for x in range(img.size[0] // 2 + 1)]
            self.assertEqual(runs(row), 3, "%s: %s" % (density, "".join("#" if v else "." for v in row)))

    def test_the_other_icons_are_drawn_as_before(self):
        # bold is only for the notification: the default proportions are unchanged
        a = icons.render(96, (0, 0, 0, 0), (255, 255, 255, 255), 0.42)
        b = icons.render(96, (0, 0, 0, 0), (255, 255, 255, 255), 0.42, bold=False)
        self.assertEqual(list(a.getdata()), list(b.getdata()))


if __name__ == "__main__":
    unittest.main()
