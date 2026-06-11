#!/usr/bin/env bash
# scripts/run.sh — launch the Debug build of MDPrintView, optionally opening files.
#
# Usage:
#   ./scripts/run.sh                  # launch with no document → welcome window
#   ./scripts/run.sh path/to/file.md  # launch and open that file
#   ./scripts/run.sh --logs           # launch attached to terminal so print() output streams here
#
# Kills any running MDPrintView first.
# -u (nounset) is intentionally OFF because macOS bash 3.2 errors out on
# empty array expansions like "${ARGS[@]}" even though they're well-formed.
set -eo pipefail

cd "$(dirname "$0")/.."

LOGS=0
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --logs) LOGS=1 ;;
        *) ARGS+=("$arg") ;;
    esac
done

APP="$(find ~/Library/Developer/Xcode/DerivedData -name 'MDPrintView.app' -path '*Debug*' -type d -print -quit)"
if [ -z "$APP" ]; then
    echo "FAIL: no Debug build of MDPrintView.app found. Run 'xcodebuild build' first." >&2
    exit 1
fi

pkill -x MDPrintView 2>/dev/null || true
sleep 0.3

if [ "$LOGS" -eq 1 ]; then
    # Attached run — print() output lands in this terminal.
    if [ ${#ARGS[@]} -gt 0 ]; then
        "$APP/Contents/MacOS/MDPrintView" "${ARGS[@]}"
    else
        "$APP/Contents/MacOS/MDPrintView"
    fi
else
    if [ ${#ARGS[@]} -gt 0 ]; then
        open "$APP" "${ARGS[@]}"
    else
        open "$APP"
    fi
fi
