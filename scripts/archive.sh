#!/usr/bin/env bash
# scripts/archive.sh — produce a Mac App Store distribution package of MDPrintView.
#
# Usage:
#   DEVELOPMENT_TEAM=ABCD123456 scripts/archive.sh
#
# Reads DEVELOPMENT_TEAM from the environment, archives the Release config,
# emits build/MDPrintView.xcarchive and build/Export-MAS/MDPrintView.pkg ready for
# Transporter upload to App Store Connect.
#
# Requires: active Apple Developer Program membership, Xcode signed in with
# an Apple ID on that team, "App Sandbox" capability enabled at the
# developer portal for the bundle ID.

set -euo pipefail

cd "$(dirname "$0")/.."

if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
    cat >&2 <<'EOF'
FAIL: DEVELOPMENT_TEAM env var is not set.

Find your team ID at https://developer.apple.com/account → Membership Details → Team ID.
It's a 10-character alphanumeric string.

Then run:
    DEVELOPMENT_TEAM=ABCD123456 scripts/archive.sh
EOF
    exit 1
fi

echo "==> Cleaning prior build/ artifacts..."
rm -rf build/MDPrintView.xcarchive build/Export-MAS build/ExportOptions-MAS.plist
mkdir -p build

echo "==> Regenerating Xcode project from project.yml..."
xcodegen generate >/dev/null

echo "==> Archiving Release for macOS..."
xcodebuild archive \
  -project MDPrintView.xcodeproj \
  -scheme MDPrintView \
  -configuration Release \
  -destination 'platform=macOS' \
  -archivePath build/MDPrintView.xcarchive \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  CODE_SIGN_STYLE=Automatic \
  2>&1 | tail -5

if [ ! -d "build/MDPrintView.xcarchive" ]; then
    echo "FAIL: archive not produced — re-run with full xcodebuild output for details" >&2
    exit 1
fi

echo "==> Generating ExportOptions-MAS.plist..."
cat > build/ExportOptions-MAS.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>$DEVELOPMENT_TEAM</string>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
EOF

echo "==> Exporting Mac App Store package..."
xcodebuild -exportArchive \
  -archivePath build/MDPrintView.xcarchive \
  -exportOptionsPlist build/ExportOptions-MAS.plist \
  -exportPath build/Export-MAS \
  2>&1 | tail -5

if [ ! -f build/Export-MAS/MDPrintView.pkg ]; then
    echo "FAIL: MDPrintView.pkg not produced — re-run with full xcodebuild output for details" >&2
    exit 1
fi

echo "==> Inspecting package signature..."
pkgutil --check-signature build/Export-MAS/MDPrintView.pkg | head -10
echo ""

ls -lh build/Export-MAS/
echo ""
echo "==> Done. Upload build/Export-MAS/MDPrintView.pkg via Transporter.app."
