#!/usr/bin/env bash
# Builds Halo in release mode and assembles an ad-hoc signed build/Halo.app:
#
#   Halo.app/Contents/
#     Info.plist                      (Support/Info.plist, LSUIElement = true)
#     MacOS/Halo                      (swift build -c release)
#     Resources/MediaRemoteAdapter/
#       mediaremote-adapter.pl        (vendored Perl entry point)
#       MediaRemoteAdapter.framework  (scripts/build-adapter.sh)
#       LICENSE                       (BSD 3-Clause, required for redistribution)
#
# Usage: scripts/bundle.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/Halo.app"
ADAPTER_SRC="$ROOT/Vendor/mediaremote-adapter"
ADAPTER_OUT="$BUILD_DIR/adapter"
ADAPTER_DEST="$APP/Contents/Resources/MediaRemoteAdapter"

cd "$ROOT"

echo "==> Building Halo (release)"
swift build -c release --product Halo
BIN_DIR="$(swift build -c release --show-bin-path)"

"$ROOT/scripts/build-adapter.sh" "$ADAPTER_OUT"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$ADAPTER_DEST"
cp "$BIN_DIR/Halo" "$APP/Contents/MacOS/Halo"
cp "$ROOT/Support/Info.plist" "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" > /dev/null
ditto "$ADAPTER_OUT/MediaRemoteAdapter.framework" "$ADAPTER_DEST/MediaRemoteAdapter.framework"
cp "$ADAPTER_SRC/bin/mediaremote-adapter.pl" "$ADAPTER_DEST/mediaremote-adapter.pl"
cp "$ADAPTER_SRC/LICENSE" "$ADAPTER_DEST/LICENSE"

echo "==> Signing (ad-hoc)"
# Inside-out: the adapter framework first, then the app that seals it.
codesign --force --sign - "$ADAPTER_DEST/MediaRemoteAdapter.framework"
codesign --force --sign - "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Done: $APP"
