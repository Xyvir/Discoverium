#!/bin/bash

# pubspec.yaml file
PUBSPEC_FILENAME="pubspec.yaml"

# version name: "version: 1.7.01+2358" in pubspec.yaml gives "1.7.01". The part
# after the "+" is the build number, which is not part of the release name.
VERSION_NAME=$(grep '^version:' "${PUBSPEC_FILENAME}" | head -n1 | awk '{ print $2 }' | cut -d'+' -f1)

if [ -z "$VERSION_NAME" ]; then
  echo "Error: Could not find version in ${PUBSPEC_FILENAME}"
  exit 1
fi

COMMIT_MESSAGE_PREFIX='    '
COMMIT_MESSAGE_SPECIAL_PREFIX='\* '

CHANGELOG_OVERRIDE_FILENAME="changelog_override.txt"

if [ ! -f ${CHANGELOG_OVERRIDE_FILENAME} ]; then
  # Grab commit messages since that tag, matching specific format. Upstream
  # Obtainium's v-prefixed tags come in with each merge, so only this repo's
  # own release tags count.
  RELEVANT_COMMIT_MESSAGES=`git log $(git describe --tags --abbrev=0 --exclude 'v*')..HEAD | grep "^${COMMIT_MESSAGE_PREFIX}${COMMIT_MESSAGE_SPECIAL_PREFIX}" | sed "s/^${COMMIT_MESSAGE_PREFIX}//g"`

  if [ -z "$RELEVANT_COMMIT_MESSAGES" ]; then
    echo "Warning: No relevant commit messages found after latest tag"
  fi
else
  RELEVANT_COMMIT_MESSAGES=`cat ${CHANGELOG_OVERRIDE_FILENAME}`
fi

# Section 1: everything before "flutter build apk"
1() {
  # A release must not reuse a tag; bump the version in pubspec.yaml first.
  if git rev-parse -q --verify "refs/tags/${VERSION_NAME}" > /dev/null; then
    echo "Error: tag ${VERSION_NAME} already exists. Bump the version in ${PUBSPEC_FILENAME} first."
    exit 1
  fi

  # Commit the version bump, if it has not been committed yet
  if [ -n "$(git status --porcelain -- "${PUBSPEC_FILENAME}")" ]; then
    git add "${PUBSPEC_FILENAME}"

    COMMIT_MESSAGE="Updated version to ${VERSION_NAME}"

    # Make a new commit for a new release
    git commit -m "${COMMIT_MESSAGE}"
  fi

  # Refuse to tag from a dirty working tree — anything still uncommitted here
  # was not captured by the release commit, so the tag would point at a tree
  # that does not match what actually gets built and released.
  if [ -n "$(git status --porcelain)" ]; then
    echo "Error: working tree is dirty after the release commit. Commit or stash your changes before releasing."
    git status --short
    exit 1
  fi

  # Creating new tag for the new release
  git tag -a "${VERSION_NAME}" -m "Version ${VERSION_NAME}"

  # Push tags to the git repository
  git push --tags
}

# Section 2: "flutter build apk"
2() {
  # Creating build/app/outputs/flutter-apk/discoverium-<version>.apk
  flutter build apk --flavor normal

  RC="${?}"

  # Check return code, and exit with the return code if it is not zero.
  if [ "${RC}" -ne 0 ]; then
    exit "${RC}"
  fi
}

# Section 3: everything after "flutter build apk"
3() {
  # Upload the APK built in section 2 to GitHub as a new release. release-github.sh does not
  # build it itself.
  scripts/release-github.sh "${RELEVANT_COMMIT_MESSAGES}"

  RC="${?}"

  # Check return code, and exit with the return code if it is not zero.
  if [ "${RC}" -ne 0 ]; then
    exit "${RC}"
  fi

  # Push the release commit (e.g. the version bump) to origin.
  git push
}

# Dispatch: run all sections in order by default, or an individual section
# when its name is passed as the argument.
case "${1}" in
  1) 1 ;;
  2) 2 ;;
  3) 3 ;;
  ""|all)
    1
    2
    3
    ;;
  *)
    echo "Usage: ${0} [1|2|3|all]"
    exit 1
    ;;
esac
