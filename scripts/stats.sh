#!/usr/bin/env bash
# scripts/stats.sh — quick launch-watch dashboard for MDPrintView.
#
# Pulls everything GitHub exposes for free, no third-party services:
#  - DMG downloads per release (lifetime; never resets)
#  - Stars / forks / watchers / open issues
#  - Last-14-day repo traffic (views + unique visitors)
#  - Last-14-day clone count
#
# Caveats GitHub doesn't fix for us:
#  - Traffic + clone history is only retained 14 days. Run this regularly
#    if you want a longer record (or pipe into a CSV — see TODO below).
#  - The GitHub Pages landing site has NO built-in analytics. If you want
#    to know how many people see the page but don't click Download, add
#    GoatCounter (free for low traffic), Plausible (~$9/mo), or similar.
#  - Sparkle update-check hits to raw.githubusercontent.com aren't
#    visible to repo owners. To track "how many existing users have the
#    app installed and checking for updates," we'd have to move the
#    appcast to a host we control (custom domain + Cloudflare logs, etc.).
#
# Usage:  ./scripts/stats.sh
set -euo pipefail

REPO="neomavkda3/MDPrintView"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }

bold "=== MDPrintView launch dashboard ==="
date
echo "Repo: https://github.com/$REPO"
echo

bold "Downloads per release (lifetime)"
gh api "repos/$REPO/releases" --jq \
    '.[] | "  \(.tag_name) (\(.published_at | sub("T.*"; ""))):  \(.assets[] | select(.name | endswith(".dmg")) | .download_count)"'

TOTAL=$(gh api "repos/$REPO/releases" \
    --jq '[.[].assets[] | select(.name | endswith(".dmg")) | .download_count] | add // 0')
echo "  -----"
echo "  TOTAL: $TOTAL"
echo

bold "Repo signal"
gh api "repos/$REPO" --jq \
    '"  Stars:        \(.stargazers_count)
  Forks:        \(.forks_count)
  Watchers:     \(.subscribers_count)
  Open issues:  \(.open_issues_count)"'
echo

bold "Traffic — last 14 days"
gh api "repos/$REPO/traffic/views" --jq \
    '"  Views (14d):   \(.count)
  Unique:        \(.uniques)"'
gh api "repos/$REPO/traffic/clones" --jq \
    '"  Clones (14d):  \(.count)
  Unique:        \(.uniques)"'
echo

bold "Top referrers — last 14 days"
gh api "repos/$REPO/traffic/popular/referrers" --jq \
    '.[] | "  \(.referrer): \(.count) views (\(.uniques) unique)"' || echo "  (no referrer data yet)"
echo

bold "Top content — last 14 days"
gh api "repos/$REPO/traffic/popular/paths" --jq \
    '.[] | "  \(.path): \(.count) views (\(.uniques) unique)"' || echo "  (no path data yet)"
