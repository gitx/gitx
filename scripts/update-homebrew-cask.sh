#!/bin/sh
#
# Write a new version and the checksums of its two disk images into the
# Homebrew cask, changing only those three values wherever they sit in the
# file, so that the rest of the cask stays exactly as Homebrew keeps it.
#
#   scripts/update-homebrew-cask.sh <gitx.rb> <version> <arm64.dmg> <x86_64.dmg>
#
# Should the cask no longer hold those values in the shape this expects, it
# leaves the file alone and fails, rather than let a broken cask go out in a
# pull request.

set -eu

if [ $# -ne 4 ]; then
	echo "usage: $0 <gitx.rb> <version> <arm64.dmg> <x86_64.dmg>" >&2
	exit 2
fi

CASK=$1
VERSION=$2
ARM=$(shasum -a 256 "$3" | cut -d ' ' -f 1)
INTEL=$(shasum -a 256 "$4" | cut -d ' ' -f 1)
echo "arm64 sha256=$ARM"
echo "x86_64 sha256=$INTEL"

WORK=$(mktemp)
trap 'rm -f "$WORK"' EXIT

sed -E \
	-e "s/^( *version )\"[^\"]*\"/\\1\"$VERSION\"/" \
	-e "s/(arm: *)\"[0-9a-f]{64}\"/\\1\"$ARM\"/" \
	-e "s/(intel: *)\"[0-9a-f]{64}\"/\\1\"$INTEL\"/" \
	"$CASK" >"$WORK"

for expected in "version \"$VERSION\"" "arm: *\"$ARM\"" "intel: *\"$INTEL\""; do
	if [ "$(grep -c -E "$expected" "$WORK")" -ne 1 ]; then
		echo "error: $CASK no longer has one place for $expected; the cask needs updating by hand" >&2
		exit 1
	fi
done

diff -u "$CASK" "$WORK" || true
cp "$WORK" "$CASK"
