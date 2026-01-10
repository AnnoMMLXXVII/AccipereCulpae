Anno Accipere Culpae - Build & Versioning Guide
Complete step-by-step guide for building APKs with automated versioning.

Table of Contents
Prerequisites
Understanding Versioning
Building APKs
Verification
Troubleshooting

Prerequisites
Project Structure
Ensure your project has:
anno_accipere_culpae/
├── android/
│   └── app/
│       ├── build.gradle.kts
│       └── version.properties
├── scripts/
│   ├── increment_version.sh
│   ├── build_apk.sh
│   └── sync_version.sh
├── releases/                    # Created automatically
├── pubspec.yaml
└── README.md
Make Scripts Executable (One-Time Setup)
chmod +x scripts/*.sh
Verify version.properties Exists
Check android/app/version.properties:
VERSION_CODE=1
VERSION_NAME=1.0.0
If missing, create it:
echo "VERSION_CODE=1" > android/app/version.properties
echo "VERSION_NAME=1.0.0" >> android/app/version.properties

🔢 Understanding Versioning
Semantic Versioning Format
Format: MAJOR.MINOR.PATCH (e.g., 2.1.3)
Type
When to Use
Example
PATCH
Bug fixes, minor tweaks
1.0.0 → 1.0.1
MINOR
New features, backward-compatible
1.0.5 → 1.1.0
MAJOR
Breaking changes, major overhaul
1.5.3 → 2.0.0
Version Code
Auto-increments with every version change
Used by Google Play Store to determine update priority
Example: 1.0.0 (code: 1) → 1.0.1 (code: 2)

🏗️ Building APKs
Important: Always run commands from the project root directory (where pubspec.yaml is located).
Option 1: Build Without Changing Version
Use when rebuilding the same version:
./scripts/build_apk.sh
What happens:
Uses current version from version.properties
Cleans previous builds
Builds release APK
Saves to releases/anno-accipere-culpae-v<current-version>.apk

Option 2: Build with Patch Increment (Bug Fixes)
Use for small fixes, UI tweaks, minor improvements:
./scripts/build_apk.sh --increment
Example:
Before: 1.0.0 (code: 1)
After: 1.0.1 (code: 2)
Output: releases/anno-accipere-culpae-v1.0.1.apk
What happens:
Increments patch version (1.0.0 → 1.0.1)
Updates version.properties
Updates pubspec.yaml
Cleans and rebuilds APK
Saves versioned APK to releases/

Option 3: Build with Minor Increment (New Features)
Use for new features, enhancements, non-breaking changes:
./scripts/build_apk.sh --increment minor
Example:
Before: 1.0.5 (code: 6)
After: 1.1.0 (code: 7)
Output: releases/anno-accipere-culpae-v1.1.0.apk
What happens:
Increments minor version (1.0.5 → 1.1.0)
Resets patch to 0
Auto-increments version code
Updates both config files
Builds and saves APK

Option 4: Build with Major Increment (Breaking Changes)
Use for major redesigns, breaking API changes, complete overhauls:
./scripts/build_apk.sh --increment major
Example:
Before: 1.5.3 (code: 20)
After: 2.0.0 (code: 21)
Output: releases/anno-accipere-culpae-v2.0.0.apk
What happens:
Increments major version (1.5.3 → 2.0.0)
Resets minor and patch to 0
Auto-increments version code
Updates both config files
Builds and saves APK

Output Location
All APKs are saved to:
releases/
├── anno-accipere-culpae-v1.0.0.apk
├── anno-accipere-culpae-v1.0.1.apk
├── anno-accipere-culpae-v1.1.0.apk
└── anno-accipere-culpae-v2.0.0.apk
Each build overwrites the APK with the same version name.

Verification
Check Current Version
From terminal:
cat android/app/version.properties
Expected output:
VERSION_CODE=5
VERSION_NAME=1.2.3
Verify Version in pubspec.yaml
grep "^version:" pubspec.yaml
Expected output:
version: 1.2.3+5
Verify APK Installation
Install the APK on a device
Open the app
Navigate to Settings → About
Confirm version matches build

Troubleshooting
Issue: "Permission denied" Error
Cause: Scripts are not executable
Solution:
chmod +x scripts/*.sh

Issue: Version Not Showing in App
Cause: Flutter cache not refreshed
Solution:
flutter clean
flutter pub get
flutter run

Issue: version.properties Not Found
Cause: File missing or in wrong location
Solution:
echo "VERSION_CODE=1" > android/app/version.properties
echo "VERSION_NAME=1.0.0" >> android/app/version.properties

Issue: Build Fails with Gradle Error
Cause: Corrupted Gradle cache
Solution:
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
./scripts/build_apk.sh

Issue: IDE Shows Import Errors (Red Squiggles)
Cause: Android Studio cache out of sync
Solution:
File → Invalidate Caches... → Invalidate and Restart

Issue: "No such file or directory" in Script
Cause: Running script from wrong directory
Solution:
Always run from project root:
# Correct (from project root)
./scripts/build_apk.sh --increment minor

# Wrong (from scripts/ directory)
./build_apk.sh --increment minor

Quick Reference Commands
Task
Command
Build APK (no version change)
./scripts/build_apk.sh
Build + Bug fix (patch)
./scripts/build_apk.sh --increment
Build + New feature (minor)
./scripts/build_apk.sh --increment minor
Build + Major update
./scripts/build_apk.sh --increment major
Check version
cat android/app/version.properties
Verify pubspec sync
grep "^version:" pubspec.yaml

Real-World Workflow Examples
Scenario 1: Fixed a Crash Bug
# Make code fixes
# Then:
./scripts/build_apk.sh --increment

# Output: anno-accipere-culpae-v1.0.1.apk

Scenario 2: Added Scan History Feature
# Implement new feature (like ScanHistoryScreen)
# Then:
./scripts/build_apk.sh --increment minor

# Output: anno-accipere-culpae-v1.1.0.apk

Scenario 3: Complete UI Redesign
# Major redesign complete
# Then:
./scripts/build_apk.sh --increment major

# Output: anno-accipere-culpae-v2.0.0.apk

Scenario 4: Testing Same Version Multiple Times
# No version change needed, just rebuild
./scripts/build_apk.sh

# Output: Overwrites existing APK with same version

## Version Management

### Automated Version Sync

The project uses `version.properties` as the single source of truth for versioning.

#### When to Use `sync_version.sh`

Use this script when version files are out of sync:

```bash
./scripts/sync_version.sh
```
Pre-Release Checklist
Before building a release APK:
Code is tested and working
Run flutter clean && flutter pub get
Test app on physical device with flutter run
Verify version displays correctly in About screen
Choose correct version increment (patch/minor/major)
Build APK: ./scripts/build_apk.sh --increment <type>
Test APK installation on real device
Commit version changes to Git
Tag release: git tag v1.0.0 && git push --tags

Important Notes
Always run from project root - Not from inside scripts/ directory
Version code auto-increments - No manual management needed
APKs are version-named - Easy to identify releases
Both config files sync automatically - version.properties ↔ pubspec.yaml
Commit after versioning - Keep Git history clean

Common Mistakes to Avoid
Don't
Do
Run scripts from scripts/ directory
Run from project root
Manually edit pubspec.yaml version
Let scripts handle versioning
Skip version increment for features
Use --increment minor
Use major increment for bug fixes
Use --increment (patch)
Build without testing
Test before building release APK

Last Updated: 2024-12-20 
Project: Anno Accipere Culpae 
Maintainer: AnnoMMLXXVII 
Flutter Version: 3.5.4+ 
Build System: Gradle 8.x