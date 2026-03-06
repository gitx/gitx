#!/bin/bash
# Creates /tmp/gitx-screenshot-repo as a symlink to the project root.
# Run this once before running UI tests locally from Xcode or xcodebuild.
#
# In CI this is not needed — BuildPR.yml clones the fixed commit there.
#
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -e /tmp/gitx-screenshot-repo ]; then
    echo "/tmp/gitx-screenshot-repo already exists ($(readlink /tmp/gitx-screenshot-repo 2>/dev/null || echo 'not a symlink'))"
else
    ln -sf "$PROJECT_ROOT" /tmp/gitx-screenshot-repo
    echo "Created symlink: /tmp/gitx-screenshot-repo -> $PROJECT_ROOT"
fi

