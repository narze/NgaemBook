#!/bin/sh
# Builds "build/NgaemBook.app": a universal (arm64 + x86_64) menu bar app
# (no Dock icon) with an ad-hoc signature and a Thai display name.
set -eu

cd "$(dirname "$0")/.."

NAME="NgaemBook"
THAI_NAME="แง้มบุ๊ค"
EXECUTABLE="NgaemBook"
BUNDLE_ID="com.narze.NgaemBook"
VERSION="${VERSION:-$(git describe --tags --always 2>/dev/null | sed 's/^v//' || echo 0)}"
APP="build/$NAME.app"

swift build -c release --arch arm64 --arch x86_64 --product "$EXECUTABLE"
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$EXECUTABLE"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/th.lproj"
cp "$BIN" "$APP/Contents/MacOS/$EXECUTABLE"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$NAME</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
</dict>
</plist>
EOF

printf 'CFBundleDisplayName = "%s";\nCFBundleName = "%s";\n' "$THAI_NAME" "$THAI_NAME" \
    > "$APP/Contents/Resources/th.lproj/InfoPlist.strings"

codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
echo "Built $APP"
