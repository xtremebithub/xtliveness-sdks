#!/usr/bin/env bash
# One-time set-up of the demo app (run on a Mac with Flutter installed):  ./setup.sh
# Adds the android/ ios/ web/ folders, the camera permissions and the permission_handler setting, then fetches packages.
# Then:  flutter run -d <device>     or     ./setup.sh apk   (builds small per-phone-type APKs (no fat APK))
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
command -v flutter >/dev/null || { echo "Flutter is not installed or not on PATH (https://docs.flutter.dev/get-started/install)" >&2; exit 1; }

if [[ ! -d android || ! -d ios ]]; then
  flutter create --project-name xtliveness_demo --org com.xtremebit --platforms android,ios,web .
fi

python3 - <<'PY'
import re, pathlib
# Android: camera + internet permissions
p = pathlib.Path('android/app/src/main/AndroidManifest.xml'); s = p.read_text()
add = ''
for perm in ('android.permission.CAMERA', 'android.permission.INTERNET'):
    if perm not in s:
        add += f'    <uses-permission android:name="{perm}"/>\n'
if 'android.hardware.camera.front' not in s:
    add += '    <uses-feature android:name="android.hardware.camera.front" android:required="false"/>\n'
if 'TTS_SERVICE' not in s:
    add += '    <queries><intent><action android:name="android.intent.action.TTS_SERVICE"/></intent></queries>\n'
if add:
    s = s.replace('<application', add + '    <application', 1)
p.write_text(s)

# iOS: usage descriptions
p = pathlib.Path('ios/Runner/Info.plist'); s = p.read_text()
for key, text in (('NSCameraUsageDescription', 'We use the camera to check that it is really you.'),
                  ('NSPhotoLibraryUsageDescription', 'The demo lets you pick photos to compare faces.')):
    if key not in s:
        s = s.replace('</dict>\n</plist>', f'\t<key>{key}</key>\n\t<string>{text}</string>\n</dict>\n</plist>')
p.write_text(s)

# iOS: permission_handler needs the camera switched on in the Podfile (iOS 15 or higher for the camera in a WebView)
p = pathlib.Path('ios/Podfile')
if p.exists():
    s = p.read_text()
    s = re.sub(r"^# platform :ios, '[0-9.]+'", "platform :ios, '15.0'", s, flags=re.M)
    if 'PERMISSION_CAMERA' not in s:
        s = s.replace('flutter_additional_ios_build_settings(target)',
            "flutter_additional_ios_build_settings(target)\n    target.build_configurations.each do |config|\n"
            "      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)', 'PERMISSION_CAMERA=1']\n    end", 1)
    p.write_text(s)
PY

flutter pub get
dart run flutter_launcher_icons   # the launcher icon and web favicon from assets/icon.png
if [[ "${1:-}" == "apk" ]]; then flutter build apk --release --split-per-abi; echo "APKs (use app-arm64-v8a-release.apk for almost every phone): build/app/outputs/flutter-apk/"; else echo "Ready. Run:  flutter run -d <device>"; fi
