#!/bin/bash

echo "🔧 Building APK..."

# Optional: Increment version before building
if [ "$1" == "--increment" ]; then
    ./scripts/increment_version.sh $2
fi

# Clean previous builds
flutter clean
flutter pub get  # This refreshes package_info_plus cache

# Build release APK
flutter build apk --release

# Copy APK to releases folder with version name
VERSION_NAME=$(grep VERSION_NAME android/app/version.properties | cut -d'=' -f2)
mkdir -p releases
cp build/app/outputs/flutter-apk/app-release.apk "releases/anno-accipere-culpae-v$VERSION_NAME.apk"

echo "APK built successfully: releases/anno-accipere-culpae-v$VERSION_NAME.apk"
