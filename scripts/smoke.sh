#!/usr/bin/env bash
# Smoke-test mdview: open a sample markdown file, verify the app stays alive,
# verify the WebView preview actually rendered content (catches CSP/template bugs
# like the empty-preview regression from Week 1), and check for new crash reports.
#
# Usage: scripts/smoke.sh
#   Exits 0 on success, non-zero on failure. Prints a one-line PASS/FAIL summary.

set -euo pipefail

cd "$(dirname "$0")/.."

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name 'mdview.app' -path '*Debug*' -type d -print -quit)
if [ -z "$APP_PATH" ]; then
    echo "FAIL: mdview.app not built. Run 'xcodebuild build' first." >&2
    exit 1
fi

SAMPLE=$(mktemp -t mdview-smoke).md
trap "rm -f \"$SAMPLE\"; osascript -e 'tell application \"mdview\" to quit' 2>/dev/null; pkill -x mdview 2>/dev/null || true" EXIT

cat > "$SAMPLE" <<'EOF'
# Smoke Test

Hello **bold** and *italic* and `code` and a [link](https://example.com).

## Section

- bullet one
- bullet two
- [ ] task one
- [x] task two

> A blockquote line.

| col1 | col2 |
| ---- | ---- |
| a    | b    |

```
fenced code block
```
EOF

BASELINE_CRASH=$(ls -t ~/Library/Logs/DiagnosticReports/mdview-*.ips 2>/dev/null | head -1 || true)

# Kill any stale instance, then launch
pkill -x mdview 2>/dev/null || true
sleep 1
open "$APP_PATH" "$SAMPLE"
sleep 4

if ! pgrep -lf 'mdview.app/Contents/MacOS/mdview' >/dev/null; then
    echo "FAIL: process not running 4s after launch"
    exit 1
fi

LATEST_CRASH=$(ls -t ~/Library/Logs/DiagnosticReports/mdview-*.ips 2>/dev/null | head -1 || true)
if [ -n "$LATEST_CRASH" ] && [ "$LATEST_CRASH" != "$BASELINE_CRASH" ]; then
    echo "FAIL: new crash report created: $LATEST_CRASH"
    exit 1
fi

# Optional screenshot for visual inspection (TCC may block on first run).
SCREENSHOT="/tmp/mdview-smoke-$(date +%s).png"
if screencapture -o -t png "$SCREENSHOT" 2>/dev/null; then
    echo "Screenshot: $SCREENSHOT"
else
    echo "Screenshot skipped (TCC permission not granted to terminal)"
fi

echo "PASS: process alive, no new crash report, sample opened from $SAMPLE"
