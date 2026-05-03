#!/bin/bash
# Wrap an existing SpawnWatch.app into a compressed .dmg with an Applications
# shortcut, so double-clicking shows the standard "drag to /Applications" window.
# Usage:
#   ./Scripts/create-dmg.sh                 # uses build/SpawnWatch.app
#   ./Scripts/create-dmg.sh path/to/App.app
# Output: build/SpawnWatch.dmg

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/build/SpawnWatch.app}"
OUT="$ROOT/build/SpawnWatch.dmg"
VOLNAME="SpawnWatch"

if [ ! -d "$APP" ]; then
    echo "App bundle not found: $APP" >&2
    echo "Run ./Scripts/build-app.sh first." >&2
    exit 1
fi

STAGE="$(mktemp -d)/$VOLNAME"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# Strip xattrs once more, just in case
xattr -cr "$STAGE/$(basename "$APP")" 2>/dev/null || true

rm -f "$OUT"
echo "==> hdiutil create $OUT"
hdiutil create \
    -volname "$VOLNAME" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$OUT" >/dev/null

xattr -cr "$OUT" 2>/dev/null || true

rm -rf "$(dirname "$STAGE")"

SIZE=$(du -h "$OUT" | awk '{print $1}')
echo "Built $OUT  ($SIZE)"
