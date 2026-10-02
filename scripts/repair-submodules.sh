#!/bin/sh
#
# Repair the submodules that an interrupted `git submodule update` leaves in a
# state that running it again cannot get out of:
#
#   - a clone cut off before its first commit arrived, which every later
#     update fails on with "Unable to find current revision"
#   - a clone that was never checked out, which every later update skips,
#     since it already sits at the commit this tree wants
#
# Neither holds anything to lose, so the first is removed for the next update
# to clone again, and the second is checked out. A submodule in any other
# state, local changes and commits included, is left alone.
#
#   scripts/repair-submodules.sh [--check]
#
# With --check, list them one per line and change nothing.

set -u

CHECK=
[ "${1:-}" = "--check" ] && CHECK=1

repair() {
	repo=$1
	[ -f "$repo/.gitmodules" ] || return 0
	git -C "$repo" config -f .gitmodules --get-regexp '^submodule\..*\.path$' |
	while read -r _ path; do
		if [ "$repo" = . ]; then sub=$path; else sub=$repo/$path; fi
		[ -e "$sub/.git" ] || continue

		if ! git -C "$sub" rev-parse -q --verify HEAD >/dev/null 2>&1; then
			gitdir=$(git -C "$sub" rev-parse --absolute-git-dir 2>/dev/null) || continue
			case $gitdir in */modules/*) ;; *) continue ;; esac
			[ -z "$(git -C "$sub" for-each-ref 2>/dev/null)" ] || continue
			if [ -n "$CHECK" ]; then
				echo "$sub was cut off while cloning"
			else
				echo "Removing $sub, whose clone was cut off, for the update to clone it again"
				rm -rf "$gitdir" "$sub/.git"
			fi
			continue
		fi

		if [ "$(ls -A "$sub")" = .git ] &&
			[ -z "$(git -C "$sub" ls-files | head -n 1)" ] &&
			[ -n "$(git -C "$sub" ls-tree HEAD | head -n 1)" ]; then
			if [ -n "$CHECK" ]; then
				echo "$sub was never checked out"
				continue
			fi
			echo "Checking out $sub, which was cloned but never checked out"
			git -C "$sub" reset -q --hard HEAD || continue
		fi

		(repair "$sub")
	done
}

repair .
