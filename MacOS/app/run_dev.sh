#!/usr/bin/env bash
# Build and launch LUDO Desktop (macOS) for local dev — no full Xcode required.
# Compiles the SwiftUI sources with swiftc, wraps them in a .app bundle, ad-hoc
# signs it, and opens the app window. Re-run after each code change.
#
#   ./run_dev.sh              build + launch
#   ./run_dev.sh --autopilot  build + launch, auto-walking every screen (demo)
#
# Once full Xcode is installed you can instead use:
#   xcodegen generate && open LudoDesktop.xcodeproj   # then press CMD-R

set -euo pipefail

APPDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$APPDIR/build/LudoDesktop.app"
BIN="$APP/Contents/MacOS/LudoDesktop"

# Stop any running instance so the new build takes its place.
pkill -f "LudoDesktop.app/Contents/MacOS/LudoDesktop" 2>/dev/null || true

# Ensure the .app bundle + Info.plist exist (idempotent; registers ludo-desktop://).
mkdir -p "$APP/Contents/MacOS"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>LUDO Desktop</string>
  <key>CFBundleIdentifier</key><string>de.euroblaze.ludodesktop</string>
  <key>CFBundleExecutable</key><string>LudoDesktop</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.2.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleURLTypes</key><array><dict>
    <key>CFBundleURLName</key><string>de.euroblaze.ludodesktop.auth</string>
    <key>CFBundleURLSchemes</key><array><string>ludo-desktop</string></array>
  </dict></array>
</dict></plist>
PLIST

echo "Building LUDO Desktop…"
# shellcheck disable=SC2046
swiftc -parse-as-library \
  -target "$(uname -m)-apple-macosx14.0" \
  -sdk "$(xcrun --show-sdk-path)" \
  $(find "$APPDIR/Sources" -name '*.swift') \
  -o "$BIN"

codesign --force --sign - "$APP" >/dev/null
echo "Launching $APP"

if [[ "${1:-}" == "--autopilot" ]]; then
  open -n "$APP" --args --autopilot
else
  open "$APP"
fi
