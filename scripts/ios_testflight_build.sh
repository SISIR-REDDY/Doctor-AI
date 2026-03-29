#!/bin/sh
set -eu

# Builds iOS release artifacts from a clean staging copy outside Desktop/iCloud paths.
# This avoids macOS file-provider metadata (xattrs) that can break codesign/validation.

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE_DIR="${STAGE_DIR:-$HOME/Library/Caches/docpilot_release_stage}"
MODE="${1:-ipa}"

# Remove duplicate artifacts across the project before staging/build.
"${PROJECT_ROOT}/scripts/cleanup_duplicate_artifacts.sh" "${PROJECT_ROOT}" || true

echo "Using stage directory: ${STAGE_DIR}"
rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}"

rsync -a --delete \
  --exclude '.git/' \
  --exclude '.dart_tool/' \
  --exclude 'build/' \
  --exclude 'ios/Pods/' \
  --exclude 'ios/.symlinks/' \
  --exclude 'ios/Flutter/ephemeral/' \
  "$PROJECT_ROOT/" "$STAGE_DIR/"

cd "$STAGE_DIR"
xattr -rc . 2>/dev/null || true
flutter pub get

if [ "$MODE" = "no-codesign" ]; then
  echo "Building release app without codesigning..."
  flutter build ios --release --no-codesign
  echo "Done: build/ios/iphoneos/Runner.app"
else
  echo "Building signed IPA for TestFlight upload..."
  flutter build ipa --release
  echo "Done: build/ios/ipa/*.ipa"
fi

