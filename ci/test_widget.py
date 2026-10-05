import unittest
from pathlib import Path

import widget

MANIFEST = """<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="x">
        <activity android:name=".MainActivity"/>
    </application>
</manifest>
"""

ROOT = Path(__file__).parent / "widget"


class PatchManifest(unittest.TestCase):
    def test_adds_the_receiver_inside_the_application(self):
        out = widget.patch_manifest(MANIFEST)
        self.assertIn('android:name=".TyriaWidgetProvider"', out)
        self.assertIn("android.appwidget.provider", out)
        self.assertLess(out.index("TyriaWidgetProvider"), out.index("</application>"))

    def test_is_safe_to_run_twice(self):
        once = widget.patch_manifest(MANIFEST)
        self.assertEqual(widget.patch_manifest(once), once)
        self.assertEqual(once.count("TyriaWidgetProvider"), 1)


class Files(unittest.TestCase):
    def test_everything_the_receiver_names_exists(self):
        self.assertTrue((ROOT / "kotlin/TyriaWidgetProvider.kt").exists())
        self.assertTrue((ROOT / "res/xml/tyria_widget_info.xml").exists())
        self.assertTrue((ROOT / "res/layout/tyria_widget.xml").exists())
        self.assertTrue((ROOT / "res/drawable/tyria_widget_bg.xml").exists())

    def test_the_provider_uses_only_views_the_layout_has(self):
        kotlin = (ROOT / "kotlin/TyriaWidgetProvider.kt").read_text(encoding="utf-8")
        layout = (ROOT / "res/layout/tyria_widget.xml").read_text(encoding="utf-8")
        import re

        for name in set(re.findall(r"R\.id\.(\w+)", kotlin)):
            self.assertIn('@+id/%s"' % name, layout, name)

    def test_the_description_points_at_the_layout(self):
        info = (ROOT / "res/xml/tyria_widget_info.xml").read_text(encoding="utf-8")
        self.assertIn("@layout/tyria_widget", info)


if __name__ == "__main__":
    unittest.main()
