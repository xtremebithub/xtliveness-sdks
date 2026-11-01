#!/usr/bin/env bash
# One-time set-up of the demo app (needs Node 18 or newer):  ./setup.sh
# Builds the SDK in the folder above, installs the demo's packages, and lets Expo pick the versions that fit each other.
# Then:  npx expo start     and open it in Expo Go on your phone (same Wi-Fi), or press a / i for an emulator.
#   Or:  ./setup.sh apk      builds an APK on this computer (needs a JDK 17 and the Android SDK, which Android Studio or Flutter already gave you).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
command -v node >/dev/null || { echo "Node is not installed (https://nodejs.org)" >&2; exit 1; }

( cd .. && npm install --no-audit --no-fund && npm run build )
npm install --no-audit --no-fund   # the versions in package.json are "any"; the next line fixes them
npx expo install --fix   # aligns expo, react-native and the modules to one Expo release
if [[ "${1:-}" == "apk" ]]; then
  command -v java >/dev/null || { echo "Java (JDK 17) is not installed" >&2; exit 1; }
  [[ -n "${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}" ]] || { echo "Set ANDROID_HOME to your Android SDK folder (on a Mac: ~/Library/Android/sdk)" >&2; exit 1; }
  npx expo prebuild --platform android --no-install --clean   # makes the android/ project from app.json
  ( cd android && ./gradlew assembleRelease )
  echo "APK: $(pwd)/android/app/build/outputs/apk/release/app-release.apk   (copy it to the phone and open it)"
else
  echo "Ready. Run:  npx expo start"
fi
