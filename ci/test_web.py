import json
import unittest

import web

# what flutter create writes, in the parts that matter here
TEMPLATE = """<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="description" content="A new Flutter project.">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <title>wondrous_compass</title>
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
"""


class WebTest(unittest.TestCase):
    patched = web.patch_index(TEMPLATE)

    def test_the_page_has_the_name_and_what_it_is(self):
        self.assertIn("<title>Wondrous Compass</title>", self.patched)
        self.assertIn(web.DESCRIPTION, self.patched.split("og:description")[0])
        self.assertNotIn("A new Flutter project", self.patched)

    def test_a_link_to_the_page_shows_its_name_what_it_is_and_the_picture_of_the_app(self):
        for needle in (
            '<meta property="og:title" content="Wondrous Compass">',
            '<meta property="og:url" content="https://yesanith.github.io/wc-frontend/app/">',
            '<meta property="og:image" content="https://yesanith.github.io/wc-frontend/app/icons/Icon-512.png">',
            '<link rel="canonical" href="https://yesanith.github.io/wc-frontend/app/">',
            '<meta name="twitter:card" content="summary">',
            '<meta property="og:type" content="website">',
        ):
            self.assertIn(needle, self.patched)

    def test_what_is_written_in_a_tag_cannot_end_it(self):
        description = self.patched.split('property="og:description" content="')[1].split('">')[0]
        self.assertNotIn('"', description)
        self.assertNotIn("<", description)

    def test_the_page_is_patched_once_and_twice_is_the_same(self):
        self.assertEqual(web.patch_index(self.patched), self.patched)
        self.assertEqual(self.patched.count('property="og:title"'), 1)
        self.assertEqual(self.patched.count('id="loading"'), 1)

    def test_the_phone_and_the_loading_screen_are_still_set_up(self):
        self.assertIn('<meta name="theme-color" content="#0D0B09">', self.patched)
        self.assertIn('<div id="loading">', self.patched)
        self.assertIn("flutter-first-frame", self.patched)

    def test_the_manifest_is_the_apps(self):
        manifest = web.patch_manifest(json.loads('{"name": "x", "short_name": "x"}'))
        self.assertEqual(manifest["name"], "Wondrous Compass")
        self.assertEqual(manifest["display"], "standalone")
        self.assertEqual(manifest["description"], web.DESCRIPTION)


if __name__ == "__main__":
    unittest.main()
