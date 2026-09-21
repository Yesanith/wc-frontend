#!/usr/bin/env python3
"""Points the generated android project at the release keystore.

flutter create writes a template that signs release builds with the debug
key. That key is public, so scanners treat those apks as test builds and
warn on install. This rewrites the signing config to use ci/release.keystore.
"""
import os
import re
import sys

GRADLE_KTS = "android/app/build.gradle.kts"
GRADLE_GROOVY = "android/app/build.gradle"

SIGNING_KTS = '''
    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("KEYSTORE_PATH"))
            storePassword = System.getenv("KEYSTORE_PASSWORD")
            keyAlias = System.getenv("KEY_ALIAS")
            keyPassword = System.getenv("KEY_PASSWORD")
        }
    }
'''

SIGNING_GROOVY = '''
    signingConfigs {
        release {
            storeFile file(System.getenv("KEYSTORE_PATH"))
            storePassword System.getenv("KEYSTORE_PASSWORD")
            keyAlias System.getenv("KEY_ALIAS")
            keyPassword System.getenv("KEY_PASSWORD")
        }
    }
'''


def patch(path, signing_block, debug_ref, release_ref):
    with open(path, encoding="utf-8") as f:
        src = f.read()
    if "KEYSTORE_PATH" in src:
        print("already patched")
        return True
    if debug_ref not in src:
        print("could not find the debug signing config in " + path)
        return False
    src = src.replace(debug_ref, release_ref)
    # drop the signing block right after the android { line
    src = re.sub(r"(android\s*\{)", r"\1" + signing_block, src, count=1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("patched " + path)
    return True


if os.path.exists(GRADLE_KTS):
    ok = patch(
        GRADLE_KTS,
        SIGNING_KTS,
        'signingConfig = signingConfigs.getByName("debug")',
        'signingConfig = signingConfigs.getByName("release")',
    )
elif os.path.exists(GRADLE_GROOVY):
    ok = patch(
        GRADLE_GROOVY,
        SIGNING_GROOVY,
        "signingConfig signingConfigs.debug",
        "signingConfig signingConfigs.release",
    )
else:
    print("no gradle file found")
    ok = False

sys.exit(0 if ok else 1)
