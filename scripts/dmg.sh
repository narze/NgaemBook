#!/bin/sh
# Builds "build/NgaemBook-<version>.dmg" with the app and an Applications
# link for drag-to-install.
set -eu

cd "$(dirname "$0")/.."

NAME="NgaemBook"
VERSION="${VERSION:-$(git describe --tags --always 2>/dev/null | sed 's/^v//' || echo 0)}"
export VERSION
DMG="build/$NAME-$VERSION.dmg"
STAGE="build/dmg"

scripts/bundle.sh

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "build/$NAME.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "$NAME" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG"
rm -rf "$STAGE"
hdiutil verify "$DMG"
echo "Built $DMG"
