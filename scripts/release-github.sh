#!/bin/bash

# Uploads the already-built APK as a GitHub release; it does not build it. Build first with
# `scripts/release-builds.sh 2` (or `flutter build apk --flavor normal`).

# GitHub repository the release is published to.
GITHUB_REPO="cygnusx-1-org/Discoverium"

# pubspec.yaml file
PUBSPEC_FILENAME="pubspec.yaml"

# version name: "version: 1.7.01+2358" in pubspec.yaml gives "1.7.01". The part
# after the "+" is the build number, which is not part of the release name.
VERSION_NAME=$(grep '^version:' "${PUBSPEC_FILENAME}" | head -n1 | awk '{ print $2 }' | cut -d'+' -f1)

if [ -z "$VERSION_NAME" ]; then
  echo "Error: Could not find version in ${PUBSPEC_FILENAME}"
  exit 1
fi

# The Gradle build copies the normal release APK to this name, beside Flutter's
# own app-normal-release.apk.
APK_DIR="build/app/outputs/flutter-apk"
APK_FILENAME="${APK_DIR}/discoverium-${VERSION_NAME}.apk"

# Guard the APK before uploading anything to GitHub. This is exactly the file the release
# uploads; a missing APK means no build was run for this version.
if [ ! -f "${APK_FILENAME}" ]; then
  echo "Error: ${APK_FILENAME} was not found."
  echo "Build it first with: scripts/release-builds.sh 2"
  exit 1
fi

CHANGELOG_OVERRIDE_FILENAME="changelog_override.txt"

RELEASE_NOTES="${1}"
# Fall back to changelog_override.txt when no release notes were passed on the command line, so a
# direct `scripts/release-github.sh` invocation still picks up this release's notes.
if [ -z "${RELEASE_NOTES}" ] && [ -f "${CHANGELOG_OVERRIDE_FILENAME}" ]; then
  RELEASE_NOTES="$(cat "${CHANGELOG_OVERRIDE_FILENAME}")"
fi

if [ -z "${RELEASE_NOTES}" ]; then
  echo "Error: release notes are empty and ${CHANGELOG_OVERRIDE_FILENAME} was not found or is empty." >&2
  exit 1
fi

echo "Release version: ${VERSION_NAME}"
echo "Release notes set to: $RELEASE_NOTES"

gh release create "${VERSION_NAME}" "${APK_FILENAME}" \
  --repo "${GITHUB_REPO}" \
  --title "${VERSION_NAME}" \
  --notes "${RELEASE_NOTES}" \
  --verify-tag
