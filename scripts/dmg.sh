#!/usr/bin/env bash
# Packs build/Halo.app (from scripts/bundle.sh) into build/Halo-<version>.dmg: a disk image
# with Halo.app next to a link to /Applications, so installing is a drag from one to the other.
#
# Usage: scripts/dmg.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/Halo.app"
[[ -d "$APP" ]] || { echo "Missing $APP: run scripts/bundle.sh first" >&2; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$ROOT/build/Halo-$VERSION.dmg"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

ditto "$APP" "$STAGING/Halo.app"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create -volname "Halo $VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" > /dev/null
hdiutil verify "$DMG" > /dev/null
echo "==> Done: $DMG"
