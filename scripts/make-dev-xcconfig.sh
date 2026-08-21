#!/bin/sh
#
# Write a Dev.xcconfig holding the signing settings the local build needs,
# reading them off the Apple development certificate in the keychain.
#
#   scripts/make-dev-xcconfig.sh [output-file]
#
# Set TEAM to pick between teams when the keychain holds several, and FORCE=1
# to overwrite a config that is already there.
#
# Note that `security find-identity` is not used to find the certificate: it
# pairs certificates with private keys through the old keychain API, and it
# reports nothing for a key that Xcode filed in the data protection keychain,
# even while xcodebuild signs with it happily.

set -eu

OUTPUT=${1:-Dev.xcconfig}
TEAM=${TEAM:-}
FORCE=${FORCE:-}

if [ -e "$OUTPUT" ] && [ -z "$FORCE" ]; then
	echo "$OUTPUT is already there; re-run with FORCE=1 to replace it." >&2
	exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

for kind in "Apple Development" "Mac Development"; do
	security find-certificate -a -c "$kind" -p >>"$WORK/all.pem" 2>/dev/null || true
done

if ! grep -q "BEGIN CERTIFICATE" "$WORK/all.pem" 2>/dev/null; then
	cat >&2 <<'MESSAGE'
No Apple Development certificate found in the keychain.

You may well not need one. The tests, `make build`, `make run` and `make dmg`
all work unsigned; a certificate only buys a build with the hardened runtime
turned on, and `make dmg-signed`.

If you do want one, the reason it is missing is one of these:

  Nothing set up on this Mac yet. In Xcode: Settings > Accounts, add your
  Apple ID if it is not listed, select your team, then Manage Certificates
  > + > Apple Development. A certificate issued on another Mac does not
  follow you to this one, as its private key stays in that keychain unless
  you export it.

  No developer account. A free Apple ID is enough for a development
  certificate; a paid membership only matters for distributing the app.

  An agreement waiting on you, which Xcode reports as "PLA Update
  available". Accept it at https://developer.apple.com/account and ask for
  the certificate again. Should Xcode keep reporting the old error, quit
  and reopen it.
MESSAGE
	exit 1
fi

awk '/BEGIN CERTIFICATE/ { n++ } { print > (dir "/cert" n ".pem") }' \
	dir="$WORK" "$WORK/all.pem"

for cert in "$WORK"/cert*.pem; do
	field() {
		openssl x509 -in "$cert" -noout -subject -nameopt multiline 2>/dev/null \
			| sed -n "s/^ *$1 *= *//p"
	}
	name=$(field commonName)
	team=$(field organizationalUnitName)
	[ -n "$name" ] && [ -n "$team" ] || continue

	if openssl x509 -in "$cert" -noout -checkend 0 >/dev/null 2>&1; then
		printf '%s\t%s\n' "$team" "$name" >>"$WORK/usable"
	else
		expiry=$(openssl x509 -in "$cert" -noout -enddate | sed 's/notAfter=//')
		printf '%s (expired %s)\n' "$name" "$expiry" >>"$WORK/expired"
	fi
done

# The same certificate can answer to more than one of the names looked up
# above, and can sit in more than one keychain.
if [ -s "$WORK/usable" ]; then sort -u "$WORK/usable" -o "$WORK/usable"; fi
if [ -s "$WORK/expired" ]; then sort -u "$WORK/expired" -o "$WORK/expired"; fi

if [ ! -s "$WORK/usable" ]; then
	echo "Every development certificate in the keychain has expired:" >&2
	sed 's/^/  /' "$WORK/expired" >&2
	echo "Renew one in Xcode: Settings > Accounts > Manage Certificates." >&2
	exit 1
fi

if [ -n "$TEAM" ]; then
	grep "^$TEAM	" "$WORK/usable" >"$WORK/chosen" || {
		echo "No usable certificate for team $TEAM. The keychain holds:" >&2
		sed 's/^/  /' "$WORK/usable" >&2
		exit 1
	}
else
	cp "$WORK/usable" "$WORK/chosen"
fi

if [ "$(cut -f1 "$WORK/chosen" | sort -u | wc -l)" -gt 1 ]; then
	echo "Certificates for more than one team are in the keychain:" >&2
	sed 's/^/  /' "$WORK/chosen" >&2
	echo "Name the one you want, as in: TEAM=XXXXXXXXXX $0" >&2
	exit 1
fi

team=$(head -1 "$WORK/chosen" | cut -f1)
name=$(head -1 "$WORK/chosen" | cut -f2)
kind=${name%%:*}

cat >"$OUTPUT" <<CONFIG
// Written by scripts/make-dev-xcconfig.sh from $name
//
// Local settings, kept out of git by .gitignore. Regenerate after renewing
// the certificate with: FORCE=1 scripts/make-dev-xcconfig.sh
DEVELOPMENT_TEAM = $team
CODE_SIGN_IDENTITY = $kind
ENABLE_HARDENED_RUNTIME = YES
CONFIG

echo "Wrote $OUTPUT for team $team using $name"
