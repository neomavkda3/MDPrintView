#!/usr/bin/env bash
# scripts/run.sh — launch the Debug build of mdview, optionally opening files.
#
# Usage:
#   ./scripts/run.sh                  # launch with no document → welcome window
#   ./scripts/run.sh path/to/file.md  # launch and open that file
#   ./scripts/run.sh --logs           # launch attached to terminal so print() output streams here
#
# Kills any running mdview first.
set -euo pipefail

cd "$(dirname "$0")/.."

LOGS=0
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --logs) LOGS=1 ;;
        *) ARGS+=("$arg") ;;
    esac
done

APP="$(find ~/Library/Developer/Xcode/DerivedData -name 'mdview.app' -path '*Debug*' -type d -print -quit)"
if [ -z "$APP" ]; then
    echo "FAIL: no Debug build of mdview.app found. Run 'xcodebuild build' first." >&2
    exit 1
fi

pkill -x mdview 2>/dev/null || true
sleep 0.3

if [ "$LOGS" -eq 1 ]; then
    # Attached run — print() output lands in this terminal.
    "$APP/Contents/MacOS/mdview" "${ARGS[@]}"
else
    open "$APP" "${ARGS[@]}"
fi
