#!/usr/bin/env bash
# Generates the Android platform folder, applies Sortapp's settings, fetches
# packages and runs the checks. Safe to re-run. Used locally and in CI.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null || { echo "Flutter is not installed: https://docs.flutter.dev/get-started/install"; exit 1; }

if [ ! -d android ]; then
  echo "==> Creating Android project (app id: app.sortapp.sortapp)"
  flutter create . --platforms=android --org app.sortapp --project-name sortapp
  # flutter create adds a counter-app test that doesn't apply here.
  rm -f test/widget_test.dart
fi

MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  echo "==> Adding INTERNET permission for release builds"
  perl -0pi -e 's#(<manifest[^>]*>)#$1\n    <uses-permission android:name="android.permission.INTERNET"/>#' "$MANIFEST"
fi
perl -pi -e 's/android:label="sortapp"/android:label="Sortapp"/' "$MANIFEST"

# Sign debug and release builds with the shared prototype key in tool/, so the
# SHA-1 registered in Google Cloud is the same on every machine and in CI.
GRADLE=android/app/build.gradle.kts
[ -f "$GRADLE" ] || GRADLE=android/app/build.gradle
if ! grep -q 'sortapp-debug.keystore' "$GRADLE"; then
  echo "==> Using tool/sortapp-debug.keystore for signing ($GRADLE)"
  if [[ "$GRADLE" == *.kts ]]; then
    perl -0pi -e 's/(\nandroid \{\n)/$1    signingConfigs {\n        getByName("debug") {\n            storeFile = file("..\/..\/tool\/sortapp-debug.keystore")\n            storePassword = "android"\n            keyAlias = "androiddebugkey"\n            keyPassword = "android"\n        }\n    }\n\n/' "$GRADLE"
  else
    perl -0pi -e "s/(\nandroid \{\n)/\$1    signingConfigs {\n        debug {\n            storeFile file('..\/..\/tool\/sortapp-debug.keystore')\n            storePassword 'android'\n            keyAlias 'androiddebugkey'\n            keyPassword 'android'\n        }\n    }\n\n/" "$GRADLE"
  fi
  grep -q 'sortapp-debug.keystore' "$GRADLE" || { echo "Could not patch signing in $GRADLE"; exit 1; }
fi

echo "==> flutter pub get"
flutter pub get

echo "==> flutter analyze"
flutter analyze --no-fatal-infos

echo "==> flutter test"
flutter test

echo
echo "Done. SHA-1 to register on the Google Cloud Android OAuth client:"
echo "  99:7F:AE:21:E3:5A:B9:0C:B7:2A:5E:79:68:00:9E:A4:84:5B:57:AF"
echo
echo "Run on a device:  flutter run"
