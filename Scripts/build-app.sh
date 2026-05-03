#!/bin/bash
# Build SpawnWatch.app bundle (unsigned).
# Usage: ./Scripts/build-app.sh [debug|release] [--universal]
#   --universal  Builds a universal binary for arm64 + x86_64 (Apple Silicon + Intel).
#                Default is host-arch only (faster local iteration).
# Output: build/SpawnWatch.app

set -euo pipefail

CONFIG="release"
UNIVERSAL=0
for arg in "$@"; do
    case "$arg" in
        debug|release) CONFIG="$arg" ;;
        --universal) UNIVERSAL=1 ;;
        *) echo "unknown arg: $arg" >&2; exit 1 ;;
    esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build"
APP="$OUT/SpawnWatch.app"
ICON_OUT="$OUT/Brand"
ICON="$ICON_OUT/AppIcon.icns"

if [ "$UNIVERSAL" -eq 1 ]; then
    echo "==> swift build -c $CONFIG --arch arm64 --arch x86_64  (universal)"
    swift build -c "$CONFIG" --package-path "$ROOT" --arch arm64 --arch x86_64
    # SwiftPM places multi-arch builds at .build/apple/Products/<Config>/<Binary>
    # The path uses Title-case ("Release", "Debug") regardless of -c value.
    CONFIG_TITLE="$(printf '%s' "$CONFIG" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
    BIN_PATH="$ROOT/.build/apple/Products/$CONFIG_TITLE/SpawnWatch"
else
    echo "==> swift build -c $CONFIG  (host arch only)"
    swift build -c "$CONFIG" --package-path "$ROOT"
    BIN_PATH="$ROOT/.build/$CONFIG/SpawnWatch"
fi

if [ ! -f "$BIN_PATH" ]; then
    echo "Build did not produce $BIN_PATH" >&2
    exit 1
fi

# Generate the app icon if missing or stale (older than the brand source).
if [ ! -f "$ICON" ] || [ "$ROOT/Brand/AppIcon.svg" -nt "$ICON" ] || [ "$ROOT/Scripts/generate-icon.swift" -nt "$ICON" ]; then
    echo "==> Generating AppIcon.icns from Brand sources"
    swift "$ROOT/Scripts/generate-icon.swift" "$ICON_OUT"
fi

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/SpawnWatch"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>SpawnWatch</string>
    <key>CFBundleIdentifier</key><string>dev.spawnwatch.SpawnWatch</string>
    <key>CFBundleName</key><string>SpawnWatch</string>
    <key>CFBundleDisplayName</key><string>SpawnWatch</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSAppleEventsUsageDescription</key><string>SpawnWatch uses AppleScript to launch eslogger with administrator privileges so it can observe process spawns in real time.</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
</dict>
</plist>
PLIST

# Strip extended attributes so Gatekeeper "damaged app" warning doesn't appear locally
xattr -cr "$APP" 2>/dev/null || true

# Touch the bundle so Finder/LaunchServices picks up the new icon
touch "$APP"

echo ""
echo "Built $APP"
echo "Architectures: $(lipo -archs "$APP/Contents/MacOS/SpawnWatch" 2>/dev/null || file "$APP/Contents/MacOS/SpawnWatch")"
echo ""
echo "Run: open \"$APP\""
echo "Or:  \"$APP/Contents/MacOS/SpawnWatch\""
