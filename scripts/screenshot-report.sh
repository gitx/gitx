#!/bin/bash
#
# Compare this run's UI-test screenshots against a baseline built from an
# older release tag, and (on a pull request) upload any diffs and post a PR
# comment about them.
#
# This replaces the old approach of diffing against a baseline that was
# committed into the repo (via screenShotScript/screenShotCompare.sh + git
# diff-image): that baseline only matched the tag it was captured from, so it
# drifted on every unrelated merge to master and produced diffs unrelated to
# the PR being tested. Building the baseline fresh from a pinned release tag
# against the same fixture repo commit as the PR build keeps the comparison
# meaningful: real UI differences from the PR, not history drift.
#
# Usage: scripts/screenshot-report.sh <baselineDir> <actualDir> <emulatorApi> [forceFail]
#   baselineDir  Directory of baseline PNGs (built from $BASELINE_TAG).
#   actualDir    Directory of PNGs from this run's UI tests.
#   emulatorApi  Label used in the PR comment (e.g. the CPU architecture).
#   forceFail    "true" (default) to exit 1 when screenshots differ, "false"
#                to only report.

set -o errexit
set -o nounset
set -o pipefail

baselineDir="$1"
actualDir="$2"
emulatorApi="$3"
forceFail="${4:-true}"

scriptDir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=screenShotScript/lib.sh
source "$scriptDir/../screenShotScript/lib.sh"

diffFiles=./screenshotDiffs
rm -rf "$diffFiles"
mkdir "$diffFiles"

if [ -d "$baselineDir" ] && [ -n "$(ls -A "$baselineDir" 2>/dev/null)" ]; then
	echo "==> Comparing $actualDir against baseline $baselineDir"
	"$scriptDir/compare-screenshots.sh" "$baselineDir" "$actualDir" "$diffFiles" || true
else
	echo "==> No baseline screenshots found at $baselineDir (baseline build skipped or produced nothing), skipping comparison"
fi

echo "GITHUB_REF_NAME=${GITHUB_REF_NAME:-}"
PR=$(echo "${GITHUB_REF_NAME:-}" | sed "s/\// /" | awk '{print $1}')
echo "PR=$PR GITHUB_REF_NAME=${GITHUB_REF_NAME:-}"

if [ -z "${CLASSIC_TOKEN:-}" ]; then
	echo -e "\e[31m!! You must provide CLASSIC_TOKEN environment variable.\e[0m Otherwise screenshot compare doesn't work properly"
fi
if [ -z "${SCREENSHOT_USER:-}" ]; then
	echo -e "\e[31m!! You must provide SCREENSHOT_USER environment variable.\e[0m Otherwise screenshot compare doesn't work properly"
fi
if [ -z "${SCREENSHOT_PASSWORD:-}" ]; then
	echo -e "\e[31m!! You must provide SCREENSHOT_PASSWORD environment variable.\e[0m Otherwise screenshot compare doesn't work properly"
fi

if [ "$PR" != "master" ]; then
	echo "==> Delete all old comments, starting with 'Screenshot differs:"
	oldCommentsJson=$(curl_gh -X GET "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$PR/comments")
	# the fallback echo fixes a merge to master, where no such comments exist
	oldCommentsList=$(echo "$oldCommentsJson" | jq '.[] | (.id |tostring) + "|" + (.body | test("Screenshot differs:.*") | tostring)' || echo "")
	oldCommentsList=$(echo "$oldCommentsList" | grep true || echo "")
	if [ -n "$oldCommentsList" ]; then
		oldCommentsFiltered=$(echo "$oldCommentsList" | grep "|true" | tr -d "\"" | cut -f1 -d"|")
		echo "$oldCommentsFiltered" | while read -r commentLine; do
			[ -z "$commentLine" ] && continue
			echo "==> delete commentLine=$commentLine"
			curl_gh -X DELETE "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/comments/$commentLine"
		done
	fi

	if [ -n "$(ls -A "$diffFiles" 2>/dev/null)" ]; then
		pushd "$diffFiles" >/dev/null
		body=""
		COUNTER=0
		for f in *.png; do
			COUNTER=$((COUNTER + 1))
			echo "==> Uploaded #$COUNTER screenshot=$f"
			request_result="$(curl -i -F "file=@$f" https://www.mxtracks.info/github -u "$SCREENSHOT_USER:$SCREENSHOT_PASSWORD")"
			http_status=$(echo "$request_result" | grep HTTP | awk '{print $2}')
			if [ "$http_status" != "200" ] && [ "$http_status" != "302" ]; then
				echo -e "!! Screenshot upload failed for $f \e[31m$http_status\e[0m"
				body="$body ${f} Upload http_status=<strong>$http_status</strong> <br/><br/>"
				continue
			fi
			echo -e "==> Screenshot upload successful for $f with http_status=\e[32m$http_status\e[0m"
			body="$body ${f}![screenshot](https://www.mxtracks.info/github/uploads/$f) <br/><br/>"
		done
		popd >/dev/null

		if [ -n "$body" ]; then
			echo "==> Post commentLine to $PR"
			if [ -z "${CLASSIC_TOKEN:-}" ]; then
				echo -e "!! You must provide a \e[31mCLASSIC_TOKEN\e[0m environment variable. Exiting...."
				exit 1
			fi
			curl_gh -X POST "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$PR/comments" -d "{ \"body\" : \"Screenshot differs: emulatorApi=$emulatorApi with $COUNTER screenshot(s) against baseline tag ${BASELINE_TAG:-unknown}<br/><br/>diff | actual screenshot (new)<br/><br/> $body \" }"
		fi
	fi
fi

echo ""
if [ -n "$(ls -A "$diffFiles" 2>/dev/null)" ]; then
	echo "==> Diff files exist"
	if [ "$forceFail" = "true" ]; then
		echo "==> Force error on diff files exists (forceFail=$forceFail)"
		exit 1
	else
		echo "==> Not forcing error (forceFail=$forceFail)"
		exit 0
	fi
else
	echo "==> all is fine"
	exit 0
fi
