#!/usr/bin/env python3
"""
Applies Homesky's privacy and network settings to the Android project that
`flutter create` generates. Run automatically by .github/workflows/build.yml.

What it changes in android/app/src/main/AndroidManifest.xml, and why:

  INTERNET permission
      Android calls ALL network access "internet", even talking to a plug on
      your own Wi-Fi. Homesky still only ever talks to private home-network
      addresses: that rule is enforced in lib/services/local_network.dart.

  android:usesCleartextTraffic="true"
      Tasmota and WLED only speak plain HTTP (no HTTPS) on your home network,
      and Android blocks plain HTTP unless this is set.

  android:allowBackup="false" + dataExtractionRules
      Stops Android copying the app's data (your device list, IP addresses
      and any device passwords) into Google cloud backups or onto another
      phone during a device transfer.

  android:label="Homesky"
      The name under the app icon.

It also copies the Homesky icon (assets/icon/ic_launcher_*.png, made by
tool/make_icons.py) over Flutter's default launcher icon.

Safe to run more than once: it skips anything already applied.
"""

from pathlib import Path
import sys

MANIFEST = Path("android/app/src/main/AndroidManifest.xml")
RULES_DIR = Path("android/app/src/main/res/xml")

if not MANIFEST.exists():
    sys.exit(f"Could not find {MANIFEST}. Run `flutter create --platforms=android .` first.")

text = MANIFEST.read_text(encoding="utf-8")

# 1) Permissions, added right after the opening <manifest ...> tag.
permissions = [
    # Needed for any network access, including the local network.
    '<uses-permission android:name="android.permission.INTERNET"/>',
]
for perm in permissions:
    if perm not in text:
        head_end = text.index(">", text.index("<manifest")) + 1
        text = text[:head_end] + "\n    " + perm + text[head_end:]

# 2) Attributes on the <application> tag.
attributes = {
    'android:usesCleartextTraffic': 'true',
    'android:allowBackup': 'false',
    'android:fullBackupContent': 'false',
    'android:dataExtractionRules': '@xml/data_extraction_rules',
}
app_start = text.index("<application")
app_end = text.index(">", app_start)
app_tag = text[app_start:app_end]
for name, value in attributes.items():
    if name not in app_tag:
        app_tag += f'\n        {name}="{value}"'
# Friendly app name.
app_tag = app_tag.replace('android:label="homesky"', 'android:label="Homesky"')
text = text[:app_start] + app_tag + text[app_end:]

MANIFEST.write_text(text, encoding="utf-8")

# 3) Android 12+ rules: exclude everything from cloud backup and device transfer.
RULES_DIR.mkdir(parents=True, exist_ok=True)
(RULES_DIR / "data_extraction_rules.xml").write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<!-- Homesky: never copy app data to the cloud or to another device. -->
<data-extraction-rules>
    <cloud-backup>
        <exclude domain="root" />
        <exclude domain="file" />
        <exclude domain="database" />
        <exclude domain="sharedpref" />
        <exclude domain="external" />
    </cloud-backup>
    <device-transfer>
        <exclude domain="root" />
        <exclude domain="file" />
        <exclude domain="database" />
        <exclude domain="sharedpref" />
        <exclude domain="external" />
    </device-transfer>
</data-extraction-rules>
""",
    encoding="utf-8",
)

# 4) App icon: replace Flutter's default with the Homesky icon.
import shutil
ICONS = Path("assets/icon")
for density in ["mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"]:
    source = ICONS / f"ic_launcher_{density}.png"
    target = Path(f"android/app/src/main/res/mipmap-{density}/ic_launcher.png")
    if source.exists() and target.parent.exists():
        shutil.copyfile(source, target)

print("Homesky Android settings applied:")
print(text)
