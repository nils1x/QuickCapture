#!/bin/bash
# build.sh — compiles QuickCapture.swift into a standalone .app bundle
set -e

APP_NAME="QuickCapture"
DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/$APP_NAME.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Building $APP_NAME…"

# Compile to a standalone executable
swiftc \
  -O \
  -o "$DIR/$APP_NAME" \
  "$DIR/$APP_NAME.swift" \
  -framework AppKit \
  -framework Carbon \
  -framework Foundation

echo "Packaging into .app bundle…"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"
mv "$DIR/$APP_NAME" "$MACOS/$APP_NAME"

# Info.plist — LSUIElement=true keeps it out of the Dock
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>QuickCapture</string>
  <key>CFBundleDisplayName</key>
  <string>QuickCapture</string>
  <key>CFBundleIdentifier</key>
  <string>com.nilslin.quickcapture</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleExecutable</key>
  <string>QuickCapture</string>
  <key>LSUIElement</key>
  <true/>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "Done."
echo "App: $APP"
echo "Run: open \"$APP\""
