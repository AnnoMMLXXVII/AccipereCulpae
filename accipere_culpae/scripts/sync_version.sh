#!/bin/bash

VERSION_FILE="../android/app/version.properties"
PUBSPEC_FILE="../pubspec.yaml"

# Read version from properties file
VERSION_CODE=$(grep VERSION_CODE $VERSION_FILE | cut -d'=' -f2)
VERSION_NAME=$(grep VERSION_NAME $VERSION_FILE | cut -d'=' -f2)

# Update pubspec.yaml
sed -i.bak "s/^version: .*/version: $VERSION_NAME+$VERSION_CODE/" $PUBSPEC_FILE

echo "Synced version to pubspec.yaml: $VERSION_NAME+$VERSION_CODE"
