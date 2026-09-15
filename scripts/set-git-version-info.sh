#!/bin/bash

# This script automatically sets the version and short version string of
# an Xcode project from the Git repository containing the project.
#
# To use this script in Xcode, add the script's path to a "Run Script" build
# phase for your application target.

set -o errexit
set -o nounset

# Alternatively, we could use Xcode's copy of the Git binary,
# but old Xcodes don't have this.
GIT=$(xcrun -find git)

# Run Script build phases that operate on product files of the target that
# defines them should use the value of this build setting [TARGET_BUILD_DIR].
# But Run Script build phases that operate on product files of other targets
# should use "BUILT_PRODUCTS_DIR" instead.
INFO_PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

# Build version (closest-tag-or-branch "-" commits-since-tag "-" short-hash dirty-flag)
BRANCH_NAME=$("$GIT" rev-parse --abbrev-ref HEAD)
if [ "$BRANCH_NAME" = "HEAD" ]; then
	# Detached HEAD (e.g. archive/CI builds that check out a specific commit
	# rather than a branch) - omit the branch suffix entirely.
	BUILD_VERSION=$("$GIT" describe --tags --always --dirty=-dirty)
else
	BUILD_VERSION=$("$GIT" describe --tags --always --dirty=-dirty)-$BRANCH_NAME
fi

# Use the latest tag for short version (expected tag format "vn[.n[.n]]")
# or if there are no tags, we make up version 0.0.<commit count>
LATEST_TAG=$("$GIT" describe --tags --abbrev=0 2>/dev/null)
LATEST_TAG=${LATEST_TAG##v} # Remove the "v" from the front of the tag
ARCHITECTURE=$(uname -p)
SHORT_VERSION="$LATEST_TAG"

MASTER_COMMIT_COUNT=$("$GIT" rev-list --count HEAD)
BRANCH_COMMIT_COUNT=0
BUNDLE_VERSION="$SHORT_VERSION"."$MASTER_COMMIT_COUNT [$ARCHITECTURE]"

# For debugging:
echo "BUILD VERSION: $BUILD_VERSION"
echo "SHORT VERSION: $SHORT_VERSION"
echo "BUNDLE_VERSION: $BUNDLE_VERSION"

/usr/libexec/PlistBuddy -c "Add :CFBundleBuildVersion string $BUILD_VERSION" "$INFO_PLIST" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :CFBundleBuildVersion $BUILD_VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $BUILD_VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUNDLE_VERSION" "$INFO_PLIST"
