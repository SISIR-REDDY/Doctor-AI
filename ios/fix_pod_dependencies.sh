#!/bin/bash

# Script to fix GoogleUtilities dependency conflict
# This script should be run if pod install fails with the GoogleUtilities version conflict

echo "🔧 Fixing GoogleUtilities dependency conflict..."

# Navigate to ios directory
cd "$(dirname "$0")"

echo "🧹 Removing duplicate folders/files like 'Pods 2' and 'AppAuth 3'..."
../scripts/cleanup_duplicate_artifacts.sh ios || true

# Remove existing Podfile.lock and Pods directory to force fresh resolution
echo "📦 Cleaning existing pods..."
rm -rf Podfile.lock
rm -rf Pods/
rm -rf ~/Library/Caches/CocoaPods

# Run pod install
echo "📥 Installing pods with GoogleUtilities override..."
pod install --repo-update

echo "✅ Done! If you still see errors, try:"
echo "   1. pod deintegrate"
echo "   2. pod install"

