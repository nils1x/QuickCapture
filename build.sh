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
  -framework EventKit \
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
  <key>NSRemindersUsageDescription</key>
  <string>QuickCapture creates reminders from the global hotkey.</string>
</dict>
</plist>
PLIST

# Entitlements — required for Reminders access (TCC)
cat > "$DIR/$APP_NAME.entitlements" <<ENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <false/>
</dict>
</plist>
ENT

# Ad-hoc sign with entitlements so TCC allows Reminders access
codesign --sign - --entitlements "$DIR/$APP_NAME.entitlements" --force "$APP"
rm -f "$DIR/$APP_NAME.entitlements"

echo "Done."
echo "App: $APP"
echo "Run: open \"$APP\""
