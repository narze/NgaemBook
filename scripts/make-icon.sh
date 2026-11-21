#!/bin/sh
# Draws the logo (scripts/icon.swift) and builds Resources/AppIcon.icns
# and docs/logo.png from it. Run again after changing icon.swift.
set -eu

cd "$(dirname "$0")/.."

WORK="build/icon"
ICONSET="$WORK/AppIcon.iconset"
rm -rf "$WORK"
mkdir -p "$ICONSET" Resources docs

swift scripts/icon.swift "$WORK/icon-1024.png"

for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" > /dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" > /dev/null
done

iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
sips -z 256 256 "$WORK/icon-1024.png" --out docs/logo.png > /dev/null
rm -rf "$WORK"
echo "Built Resources/AppIcon.icns and docs/logo.png"
