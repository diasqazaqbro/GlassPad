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
VERSION="1.0"
BUILD="1"
APP="dist/${APP_NAME}.app"

echo "▸ Building release…"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/${APP_NAME}"

echo "▸ Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/${APP_NAME}"

# Copy the SwiftPM resource bundle (localizations) so Bundle.module resolves in
# the packaged app — without this, RU/EN strings fall back to the keys.
RES_BUNDLE="$(swift build -c release --show-bin-path)/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$RES_BUNDLE" ]; then
  cp -R "$RES_BUNDLE" "$APP/Contents/Resources/"
  echo "▸ Bundled resources: $(basename "$RES_BUNDLE")"
else
  echo "⚠︎ resource bundle not found at $RES_BUNDLE (localizations may be missing)"
fi

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
