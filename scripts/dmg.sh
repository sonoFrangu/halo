#!/usr/bin/env bash
# Packs build/Halo.app (from scripts/bundle.sh) into build/Halo-<version>.dmg: a disk image
# whose window shows Halo.app, an arrow and a link to /Applications, so installing is a drag
# from one to the other.
#
# The window layout (background, icon size and positions) is stored in the image's
# .DS_Store, which only Finder writes: the script drives Finder through AppleScript, so the
# first run asks for permission to control Finder (Privacy & Security › Automation).
#
# Usage: scripts/dmg.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/Halo.app"
[[ -d "$APP" ]] || { echo "Missing $APP: run scripts/bundle.sh first" >&2; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$ROOT/build/Halo-$VERSION.dmg"
VOLUME="Halo"
LINK="Applicazioni"
[[ ! -e "/Volumes/$VOLUME" ]] || { echo "Eject /Volumes/$VOLUME first" >&2; exit 1; }

WORK="$(mktemp -d)"
MOUNT=""
cleanup() {
    [[ -n "$MOUNT" ]] && hdiutil detach "$MOUNT" -quiet -force || true
    rm -rf "$WORK"
}
trap cleanup EXIT

STAGING="$WORK/staging"
mkdir -p "$STAGING/.background"
ditto "$APP" "$STAGING/Halo.app"
ln -s /Applications "$STAGING/$LINK"
# One TIFF with both resolutions, so the background stays sharp on Retina screens.
tiffutil -cathidpicheck "$ROOT/Support/DMGBackground.png" "$ROOT/Support/DMGBackground@2x.png" \
    -out "$STAGING/.background/background.tiff" 2> /dev/null

echo "==> Laying out the window"
hdiutil create -volname "$VOLUME" -srcfolder "$STAGING" -fs HFS+ -format UDRW -ov "$WORK/rw.dmg" > /dev/null
MOUNT="$(hdiutil attach -readwrite -noverify -noautoopen "$WORK/rw.dmg" | awk -F '\t' '/\/Volumes\// { print $3 }')"

# 660 x 420 pt of content, as Support/DMGBackground.png; the icon centers match
# scripts/dmg/render-background.py.
osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 120, 860, 540}
        set options to icon view options of container window
        set arrangement of options to not arranged
        set icon size of options to 128
        -- Finder's labels come out dark on the background, where they vanish: the background
        -- carries the names in white, just under Finder's, which stay as small as allowed.
        set text size of options to 10
        set label position of options to bottom
        set extension hidden of item "Halo.app" to true
        set background picture of options to file ".background:background.tiff"
        set position of item "Halo.app" of container window to {180, 215}
        set position of item "$LINK" of container window to {480, 215}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

rm -rf "$MOUNT/.fseventsd"
sync
hdiutil detach "$MOUNT" -quiet
MOUNT=""

rm -f "$DMG"
hdiutil convert "$WORK/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG" > /dev/null
hdiutil verify "$DMG" > /dev/null 2>&1
echo "==> Done: $DMG"
