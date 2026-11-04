#!/usr/bin/env bash
# Generates the Android platform folder, applies Sortapp's settings, fetches
# packages and runs the tests. Safe to re-run.
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

echo "==> flutter pub get"
flutter pub get

echo "==> flutter analyze"
flutter analyze

echo "==> flutter test"
flutter test

echo
echo "Done. Debug signing SHA-1 for your Google Cloud Android OAuth client:"
if command -v keytool >/dev/null && [ -f "$HOME/.android/debug.keystore" ]; then
  keytool -list -v -alias androiddebugkey -keystore "$HOME/.android/debug.keystore" \
    -storepass android -keypass android 2>/dev/null | grep -E 'SHA1:' || true
else
  echo "  (run 'cd android && ./gradlew signingReport' after the first build)"
fi
echo
echo "Run on a device or emulator:  flutter run --dart-define=OPENAI_API_KEY=sk-..."
