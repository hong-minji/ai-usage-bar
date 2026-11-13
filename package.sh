#!/bin/bash
# Create an ad-hoc signed, NOT notarized universal release package.
set -euo pipefail
cd "$(dirname "$0")"
command -v node >/dev/null 2>&1 || { echo "Packaging requires Node.js for extension tests." >&2; exit 1; }
node --test ChromeExtension/tests.cjs
./build.sh universal
APP="build/AIUsageBar.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ARCHIVE="AIUsageBar-$VERSION-universal.zip"
STAGING="$(mktemp -d "$PWD/build/.release.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/AIUsageBar.app"
cp docs/START-HERE.txt "$STAGING/START-HERE.txt"
cp LICENSE "$STAGING/LICENSE.txt"
ditto -c -k --sequesterRsrc "$STAGING" "build/$ARCHIVE"
(cd build && shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256")
echo "Created build/$ARCHIVE (ad-hoc signed; not notarized)"
