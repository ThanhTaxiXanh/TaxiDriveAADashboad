#!/usr/bin/env bash
set -euo pipefail
# Generate only Gradle wrapper from the pinned Flutter SDK's template.
# Keep all reviewed Android application files untouched.
task_temp=$(mktemp -d)
trap 'rm -rf "$task_temp"' EXIT
flutter create --platforms=android --org com.thanhtaxixanh --project-name wrapper_seed "$task_temp/wrapper_seed"
cp "$task_temp/wrapper_seed/android/gradlew" android/gradlew
cp "$task_temp/wrapper_seed/android/gradle/wrapper/gradle-wrapper.jar" android/gradle/wrapper/
chmod +x android/gradlew
printf 'flutter.sdk=%s\nsdk.dir=%s\n' "$FLUTTER_ROOT" "$ANDROID_HOME" > android/local.properties
