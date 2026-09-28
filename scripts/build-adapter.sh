#!/usr/bin/env bash
# Compiles MediaRemoteAdapter.framework from the vendored ungive/mediaremote-adapter
# sources with plain clang, so building Halo only needs the Xcode command line tools
# (no CMake). Mirrors the upstream CMakeLists.txt: same sources, ARC, default symbol
# visibility (the Perl script resolves exported symbols at runtime), same frameworks.
#
# Usage: scripts/build-adapter.sh [output-dir]   (default: build/adapter)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/Vendor/mediaremote-adapter"
OUT="${1:-$ROOT/build/adapter}"
NAME="MediaRemoteAdapter"
FRAMEWORK="$OUT/$NAME.framework"
DEPLOYMENT_TARGET="26.0"

if [[ ! -f "$SRC/bin/mediaremote-adapter.pl" ]]; then
    echo "==> Fetching the mediaremote-adapter submodule"
    git -C "$ROOT" submodule update --init --recursive Vendor/mediaremote-adapter
fi

sources=()
for dir in adapter private utility; do
    for file in "$SRC/src/$dir"/*.m; do
        sources+=("$file")
    done
done

rm -rf "$FRAMEWORK"
mkdir -p "$FRAMEWORK/Versions/A/Resources" "$FRAMEWORK/Versions/A/Headers"

echo "==> Compiling $NAME.framework (${#sources[@]} sources, $(uname -m))"
xcrun clang \
    -dynamiclib \
    -fobjc-arc \
    -fvisibility=default \
    -O2 \
    -arch "$(uname -m)" \
    -mmacosx-version-min="$DEPLOYMENT_TARGET" \
    -I "$SRC/include" \
    -I "$SRC/src" \
    -framework Foundation \
    -framework AppKit \
    -framework ImageIO \
    -framework UniformTypeIdentifiers \
    -install_name "@rpath/$NAME.framework/Versions/A/$NAME" \
    -o "$FRAMEWORK/Versions/A/$NAME" \
    "${sources[@]}"

cp "$SRC/include/MediaRemoteAdapter.h" "$FRAMEWORK/Versions/A/Headers/"

cat > "$FRAMEWORK/Versions/A/Resources/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>$NAME</string>
	<key>CFBundleIdentifier</key>
	<string>com.vandenbe.$NAME</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$NAME</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>0.7.7</string>
	<key>CFBundleVersion</key>
	<string>0.7.7</string>
</dict>
</plist>
PLIST

ln -s A "$FRAMEWORK/Versions/Current"
ln -s "Versions/Current/$NAME" "$FRAMEWORK/$NAME"
ln -s Versions/Current/Resources "$FRAMEWORK/Resources"
ln -s Versions/Current/Headers "$FRAMEWORK/Headers"

codesign --force --sign - "$FRAMEWORK"
echo "==> $FRAMEWORK"
