#!/usr/bin/env bash
# Builds Halo in release mode and assembles an ad-hoc signed build/Halo.app:
#
#   Halo.app/Contents/
#     Info.plist                      (Support/Info.plist, LSUIElement = true)
#     MacOS/Halo                      (swift build -c release)
#     Resources/AppIcon.icns          (from Support/AppIcon.png, via sips + iconutil)
#     Resources/MediaRemoteAdapter/
#       mediaremote-adapter.pl        (vendored Perl entry point)
#       MediaRemoteAdapter.framework  (scripts/build-adapter.sh)
#       LICENSE                       (BSD 3-Clause, required for redistribution)
#
# Usage: scripts/bundle.sh
#
# Signing: ad-hoc by default. macOS ties privacy permissions (Accessibility, needed by the
# brightness/volume HUD) to the signature, and an ad-hoc signature changes on every build,
# so the permission would have to be granted again after each rebuild. To keep it, create a
# self-signed code-signing certificate named "Halo Local" in Keychain Access (Certificate
# Assistant › Create a Certificate…, identity type "Self Signed Root", certificate type
# "Code Signing"): the script picks it up automatically. HALO_SIGN_IDENTITY overrides the
# identity explicitly.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/Halo.app"
ADAPTER_SRC="$ROOT/Vendor/mediaremote-adapter"
ADAPTER_OUT="$BUILD_DIR/adapter"
ADAPTER_DEST="$APP/Contents/Resources/MediaRemoteAdapter"

cd "$ROOT"

echo "==> Toolchain: $(xcode-select -p)"
swift --version 2>&1 | sed -n 1p
echo "    macOS SDK $(xcrun --show-sdk-version)"

echo "==> Building Halo (release)"
swift build -c release --product Halo
BIN_DIR="$(swift build -c release --show-bin-path)"

"$ROOT/scripts/build-adapter.sh" "$ADAPTER_OUT"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$ADAPTER_DEST"
cp "$BIN_DIR/Halo" "$APP/Contents/MacOS/Halo"
cp "$ROOT/Support/Info.plist" "$APP/Contents/Info.plist"
# Which build is running, shown in Settings › Informazioni and in the diagnostics.
BUILD_STAMP="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo "senza git") $(date '+%Y-%m-%d %H:%M')"
plutil -insert HaloBuild -string "$BUILD_STAMP" "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" > /dev/null
echo "    build $BUILD_STAMP"

# App icon: every size of the iconset from the 1024 pt master (scripts/icon/render-icon.py).
ICONSET="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET" "$APP/Contents/Resources"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ROOT/Support/AppIcon.png" --out "$ICONSET/icon_${size}x${size}.png" > /dev/null
    sips -z "$((size * 2))" "$((size * 2))" "$ROOT/Support/AppIcon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" > /dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
ditto "$ADAPTER_OUT/MediaRemoteAdapter.framework" "$ADAPTER_DEST/MediaRemoteAdapter.framework"
cp "$ADAPTER_SRC/bin/mediaremote-adapter.pl" "$ADAPTER_DEST/mediaremote-adapter.pl"
cp "$ADAPTER_SRC/LICENSE" "$ADAPTER_DEST/LICENSE"

SIGN_IDENTITY="${HALO_SIGN_IDENTITY:-}"
if [[ -z "$SIGN_IDENTITY" ]]; then
    # No -v: a self-signed certificate is not "trusted", yet codesign can use it.
    identities="$(security find-identity -p codesigning 2>/dev/null || true)"
    if [[ "$identities" == *'"Halo Local"'* ]]; then
        SIGN_IDENTITY="Halo Local"
    fi
fi
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo "==> Signing (ad-hoc)"
else
    echo "==> Signing with \"$SIGN_IDENTITY\""
fi
# Inside-out: the adapter framework first, then the app that seals it.
codesign --force --sign "$SIGN_IDENTITY" "$ADAPTER_DEST/MediaRemoteAdapter.framework"
codesign --force --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Done: $APP"
