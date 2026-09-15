#!/bin/bash
#
# Compare a directory of freshly captured UI-test screenshots against a
# baseline directory (built from a previous release tag against the same
# fixture repo commit), and write a visual diff PNG for every image that
# differs into $diffDir.
#
# Usage: compare-screenshots.sh <baselineDir> <actualDir> <diffDir>
#
# Exit status is 0 if every screenshot present in both directories matches,
# 1 if at least one differs. Screenshots that only exist on one side (e.g. a
# new screenshot added by this PR) are reported but do not count as a diff,
# since there is nothing to compare them against yet.

set -o errexit
set -o nounset
set -o pipefail

baselineDir="$1"
actualDir="$2"
diffDir="$3"

mkdir -p "$diffDir"

status=0
shopt -s nullglob

for actual in "$actualDir"/*.png; do
	name=$(basename "$actual")
	baseline="$baselineDir/$name"

	if [ ! -f "$baseline" ]; then
		echo "==> No baseline for $name (new screenshot?), skipping comparison"
		continue
	fi

	diffPng="$diffDir/$name"
	# `compare -metric AE` prints the number of differing pixels to stderr
	# and always writes a visual diff image; it exits 0 when the images are
	# the same (within ImageMagick's fuzz-free tolerance) and 1 otherwise.
	aeOutput=$(compare -metric AE "$baseline" "$actual" "$diffPng" 2>&1) && compareStatus=0 || compareStatus=$?

	if [ "$compareStatus" = "0" ]; then
		rm -f "$diffPng"
	else
		status=1
		echo "==> $name differs from baseline ($aeOutput differing pixels)"
	fi
done

for baseline in "$baselineDir"/*.png; do
	name=$(basename "$baseline")
	if [ ! -f "$actualDir/$name" ]; then
		echo "==> $name exists in baseline but was not produced this run, skipping comparison"
	fi
done

exit $status
