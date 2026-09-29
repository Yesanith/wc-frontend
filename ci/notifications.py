#!/usr/bin/env python3
"""Sets up the generated android project for scheduled notifications.

The alerts before pinned world events are scheduled with the phone's alarm
system. flutter_local_notifications needs three things flutter create does
not write: permissions and receivers in the manifest, and core library
desugaring in the app's gradle file. Safe to run twice.
"""
import os
import re
import sys

MANIFEST = "android/app/src/main/AndroidManifest.xml"
GRADLE_KTS = "android/app/build.gradle.kts"
GRADLE_GROOVY = "android/app/build.gradle"
DESUGAR = "com.android.tools:desugar_jdk_libs:2.1.4"

PERMISSIONS = [
    # the alarm system forgets alerts when the phone restarts, the plugin sets them again
    "android.permission.RECEIVE_BOOT_COMPLETED",
    # exact timing, the player may allow it in the phone's settings
    "android.permission.SCHEDULE_EXACT_ALARM",
    "android.permission.POST_NOTIFICATIONS",
]

RECEIVERS = """    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
        <intent-filter>
            <action android:name="android.intent.action.BOOT_COMPLETED"/>
            <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
            <action android:name="android.intent.action.QUICKBOOT_POWERON" />
            <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
        </intent-filter>
    </receiver>
"""


def patch_manifest(path):
    with open(path, encoding="utf-8") as f:
        src = f.read()
    for name in PERMISSIONS:
        if name not in src:
            src = src.replace("<application", '<uses-permission android:name="%s"/>\n    <application' % name, 1)
    if "ScheduledNotificationReceiver" not in src:
        src = src.replace("</application>", RECEIVERS + "    </application>", 1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    for name in PERMISSIONS + ["ScheduledNotificationReceiver", "ScheduledNotificationBootReceiver"]:
        assert name in src, "manifest is missing " + name
    print("manifest ready")


def patch_gradle(path, kotlin):
    with open(path, encoding="utf-8") as f:
        src = f.read()
    flag = "isCoreLibraryDesugaringEnabled = true" if kotlin else "coreLibraryDesugaringEnabled true"
    dep = 'coreLibraryDesugaring("%s")' % DESUGAR if kotlin else "coreLibraryDesugaring '%s'" % DESUGAR
    if flag not in src:
        src, n = re.subn(r"(compileOptions\s*\{)", r"\1\n        " + flag, src, count=1)
        if n != 1:
            sys.exit("no compileOptions block in " + path)
    if "coreLibraryDesugaring" not in src.replace(flag, ""):
        src = src.rstrip("\n") + "\n\ndependencies {\n    " + dep + "\n}\n"
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("desugaring enabled in " + path)


if not os.path.exists(MANIFEST):
    sys.exit("no android project, run flutter create first")
patch_manifest(MANIFEST)
if os.path.exists(GRADLE_KTS):
    patch_gradle(GRADLE_KTS, True)
elif os.path.exists(GRADLE_GROOVY):
    patch_gradle(GRADLE_GROOVY, False)
else:
    sys.exit("no app gradle file found")
