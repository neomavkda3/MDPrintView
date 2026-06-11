#!/usr/bin/env bash
# Local end-to-end release: build → re-sign Sparkle → DMG → sign DMG →
# notarize → staple. Mirrors what .github/workflows/release.yml does on
# the CI runner. Use this to verify changes to the signing pipeline
# without pushing a tag first.
#
# Required env:
#   ASC_API_KEY_P8   path to App Store Connect .p8
#   ASC_KEY_ID
#   ASC_ISSUER_ID
#
# Optional env:
#   VERSION       defaults to 0.0.0-dev (CI passes from git tag)
#   BUILD_NUMBER  defaults to 1 (CI passes GITHUB_RUN_NUMBER)
#   OUTPUT_DIR    defaults to ./build
set -euo pipefail

VERSION="${VERSION:-0.0.0-dev}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
OUTPUT_DIR="${OUTPUT_DIR:-./build}"
mkdir -p "$OUTPUT_DIR"

: "${ASC_API_KEY_P8:?ASC_API_KEY_P8 path required}"
: "${ASC_KEY_ID:?ASC_KEY_ID required}"
: "${ASC_ISSUER_ID:?ASC_ISSUER_ID required}"
[ -f "$ASC_API_KEY_P8" ] || { echo "FAIL: ASC_API_KEY_P8 file not found at $ASC_API_KEY_P8"; exit 1; }

DMG="$OUTPUT_DIR/MDPrintView-${VERSION}.dmg"

echo "[1/6] xcodebuild Release ($VERSION, build $BUILD_NUMBER)"
/usr/bin/xcodebuild \
    -project MDPrintView.xcodeproj \
    -scheme MDPrintView \
    -configuration Release \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    build 2>&1 | tail -3

APP=$(/usr/bin/find ~/Library/Developer/Xcode/DerivedData -name 'MDPrintView.app' -path '*Release*' -type d -print -quit)
[ -d "$APP" ] || { echo "FAIL: built app not found"; exit 1; }

echo "[2/6] re-sign Sparkle internals"
./scripts/codesign-sparkle.sh "$APP"

echo "[3/6] build DMG"
/bin/rm -f "$DMG"
/usr/bin/hdiutil create -srcfolder "$APP" -volname MDPrintView -format UDZO -ov "$DMG" 2>&1 | /usr/bin/tail -1

echo "[4/6] sign DMG"
/usr/bin/codesign --force --sign "Developer ID Application" --timestamp "$DMG"

echo "[5/6] notarize (1-5 min)"
/usr/bin/xcrun notarytool submit "$DMG" \
    --key "$ASC_API_KEY_P8" \
    --key-id "$ASC_KEY_ID" \
    --issuer "$ASC_ISSUER_ID" \
    --wait

echo "[6/6] staple"
/usr/bin/xcrun stapler staple "$DMG"

echo ""
echo "✓ Notarized DMG: $DMG"
/usr/sbin/spctl --assess --type open --context context:primary-signature --verbose "$DMG"
