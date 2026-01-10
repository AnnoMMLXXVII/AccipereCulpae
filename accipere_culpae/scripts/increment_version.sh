#!/bin/bash

# Path to version properties file
VERSION_FILE="android/app/version.properties"

# Read current version code and name
VERSION_CODE=$(grep VERSION_CODE $VERSION_FILE | cut -d'=' -f2)
VERSION_NAME=$(grep VERSION_NAME $VERSION_FILE | cut -d'=' -f2)

# Increment version code
NEW_VERSION_CODE=$((VERSION_CODE + 1))

# Parse semantic version (major.minor.patch)
IFS='.' read -ra VERSION_PARTS <<< "$VERSION_NAME"
MAJOR=${VERSION_PARTS[0]}
MINOR=${VERSION_PARTS[1]}
PATCH=${VERSION_PARTS[2]}

# Increment patch by default (can be customized with arguments)
if [ "$1" == "major" ]; then
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
elif [ "$1" == "minor" ]; then
    MINOR=$((MINOR + 1))
    PATCH=0
else
    PATCH=$((PATCH + 1))
fi

NEW_VERSION_NAME="$MAJOR.$MINOR.$PATCH"

# Write new version to file
echo "VERSION_CODE=$NEW_VERSION_CODE" > $VERSION_FILE
echo "VERSION_NAME=$NEW_VERSION_NAME" >> $VERSION_FILE

# Sync to pubspec.yaml
sed -i.bak "s/^version: .*/version: $NEW_VERSION_NAME+$NEW_VERSION_CODE/" pubspec.yaml
rm -f pubspec.yaml.bak

echo "Version updated: $VERSION_NAME ($VERSION_CODE) → $NEW_VERSION_NAME ($NEW_VERSION_CODE)"
