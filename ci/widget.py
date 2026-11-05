#!/usr/bin/env python3
"""Adds the home screen widget to the generated android project.

The android folder is made by `flutter create` on every build and is not committed, so what the
widget needs is kept in ci/widget and put in place here: the provider (Kotlin), its layout, the
description of the widget and its background, and the receiver in the manifest. Safe to run twice.
Run from the repository root after `flutter create --platforms=android .`"""
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).parent
MANIFEST = Path("android/app/src/main/AndroidManifest.xml")
RES = Path("android/app/src/main/res")
KOTLIN = Path("android/app/src/main/kotlin/com/yesanith/wondrous_compass")
PROVIDER = "TyriaWidgetProvider"

RECEIVER = """    <receiver android:name=".%s" android:exported="true" android:label="Wondrous Compass">
        <intent-filter>
            <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
        </intent-filter>
        <meta-data android:name="android.appwidget.provider" android:resource="@xml/tyria_widget_info"/>
    </receiver>
""" % PROVIDER


def patch_manifest(src: str) -> str:
    if PROVIDER in src:
        return src
    assert "</application>" in src, "no application element in the manifest"
    return src.replace("</application>", RECEIVER + "    </application>", 1)


def main() -> int:
    if not MANIFEST.exists():
        print("run flutter create --platforms=android . first", file=sys.stderr)
        return 1
    KOTLIN.mkdir(parents=True, exist_ok=True)
    shutil.copy(ROOT / "widget/kotlin/TyriaWidgetProvider.kt", KOTLIN / "TyriaWidgetProvider.kt")
    shutil.copytree(ROOT / "widget/res", RES, dirs_exist_ok=True)
    MANIFEST.write_text(patch_manifest(MANIFEST.read_text(encoding="utf-8")), encoding="utf-8")
    assert PROVIDER in MANIFEST.read_text(encoding="utf-8")
    print("widget ready")
    return 0


if __name__ == "__main__":
    sys.exit(main())
