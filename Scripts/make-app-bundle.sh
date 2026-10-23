#!/usr/bin/env bash
#
# Wrap the release SwiftPM binary into a proper GlassPad.app bundle.
# A real bundle gives the app a stable identity for launch-at-login
# (SMAppService) and a clean ScreenCaptureKit/TCC attribution. Ad-hoc signed so
# it runs locally without a Developer ID.
#
# Usage: Scripts/make-app-bundle.sh   (then: open dist/GlassPad.app)
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="GlassPad"
BUNDLE_ID="com.glasspad.GlassPad"
VERSION="1.0.1"
BUILD="2"
APP="dist/${APP_NAME}.app"

# Built with xcodebuild, not `swift build`: SwiftPM's Bundle.module accessor
# only looks in the .app root (which codesign rejects) and then falls back to an
# absolute .build path — so a `swift build` bundle crashes on any other machine.
# Xcode's accessor looks in Contents/Resources first.
echo "▸ Building release…"
xcodebuild -scheme "$APP_NAME" -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build -quiet build
PRODUCTS="build/Build/Products/Release"

echo "▸ Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$PRODUCTS/${APP_NAME}" "$APP/Contents/MacOS/${APP_NAME}"

# Resource bundles (our localizations + KeyboardShortcuts' Recorder strings).
for RES_BUNDLE in "$PRODUCTS"/*.bundle; do
  cp -R "$RES_BUNDLE" "$APP/Contents/Resources/"
  echo "▸ Bundled resources: $(basename "$RES_BUNDLE")"
done

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>     <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>      <string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key>      <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>${VERSION}</string>
    <key>CFBundleVersion</key>         <string>${BUILD}</string>
    <key>LSMinimumSystemVersion</key>  <string>26.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "▸ Ad-hoc signing…"
codesign --force --options runtime --sign - "$APP"

echo "✓ Built $APP"
echo "  Run it:  open \"$APP\""
