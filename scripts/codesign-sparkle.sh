#!/usr/bin/env bash
# Re-sign Sparkle.framework's nested binaries from inside out with our
# Developer ID Application identity + secure timestamp.
#
# Why we need this: Sparkle's SPM-distributed framework ships with its
# inner XPC services and Updater.app pre-signed by the Sparkle team.
# Xcode's automatic codesign step signs the *outer* Sparkle.framework
# wrapper with our identity, but uses `--preserve-metadata` for nested
# binaries — so the Sparkle-team signatures inside stay intact. Apple's
# notarization rejects any binary signed with a non-Developer-ID-of-
# OUR-team identity ("The binary is not signed with a valid Developer
# ID certificate"). We sweep through every embedded executable and
# re-sign with our identity + `--timestamp` to make notary happy.
#
# Order matters: sign innermost binaries first, then their containers,
# finally the framework itself. The main .app is re-signed last with
# entitlements (so we can assert get-task-allow=false explicitly).
#
# Usage:
#   scripts/codesign-sparkle.sh <path-to-MDPrintView.app>
#
# Env overrides:
#   CODE_SIGN_IDENTITY  defaults to "Developer ID Application"
set -euo pipefail

APP="${1:?usage: $0 <path-to-app>}"
[ -d "$APP" ] || { echo "FAIL: app bundle not found at $APP"; exit 1; }
# Resolve the app path to absolute BEFORE changing directory, then cd to
# the repo root so the relative entitlements path below works no matter
# where the script is invoked from.
APP="$(cd "$APP" && pwd)"
cd "$(dirname "$0")/.."

SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
[ -d "$SPARKLE" ] || { echo "FAIL: Sparkle.framework not found inside $APP"; exit 1; }

IDENTITY="${CODE_SIGN_IDENTITY:-Developer ID Application}"
# `--preserve-metadata=entitlements,flags` keeps each binary's existing
# entitlements and runtime flags — Sparkle's XPC services rely on
# specific runtime entitlements that the framework needs intact.
# We swap only the signing identity + add the secure timestamp.
ARGS=(--force --sign "$IDENTITY" --timestamp --options runtime --preserve-metadata=entitlements,flags)

for path in \
    "$SPARKLE/Versions/B/Autoupdate" \
    "$SPARKLE/Versions/B/Updater.app/Contents/MacOS/Updater" \
    "$SPARKLE/Versions/B/Updater.app" \
    "$SPARKLE/Versions/B/XPCServices/Downloader.xpc/Contents/MacOS/Downloader" \
    "$SPARKLE/Versions/B/XPCServices/Downloader.xpc" \
    "$SPARKLE/Versions/B/XPCServices/Installer.xpc/Contents/MacOS/Installer" \
    "$SPARKLE/Versions/B/XPCServices/Installer.xpc" \
    "$SPARKLE"
do
    /usr/bin/codesign "${ARGS[@]}" "$path"
done

# Re-sign the main app with our entitlements file (not preserving — we
# want our get-task-allow=false to take effect, not whatever Xcode
# baked in during the build step).
/usr/bin/codesign --force --sign "$IDENTITY" --timestamp --options runtime \
    --entitlements MDPrintView/MDPrintView.entitlements \
    "$APP"

# Sanity check
/usr/bin/codesign --verify --deep --strict "$APP"
echo "✓ Sparkle internals + main app re-signed"
