#!/bin/sh
set -eu

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Ensure generated Flutter iOS files exist before CocoaPods reads Podfile.
/Users/sisirreddy/development/flutter/bin/flutter pub get

# Warm up generated iOS xcconfig if still missing (can happen after aggressive clean).
if [ ! -f "$PROJECT_ROOT/ios/Flutter/Generated.xcconfig" ]; then
  /Users/sisirreddy/development/flutter/bin/flutter build ios --simulator --debug --no-codesign >/dev/null 2>&1 || true
fi

cd "$PROJECT_ROOT/ios"
pod install --no-repo-update
