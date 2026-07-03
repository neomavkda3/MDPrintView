#!/usr/bin/env python3
"""Splice a <sparkle:releaseNotesLink> element into appcast.xml.

Runs after `generate_appcast` in the release workflow. `generate_appcast`
does not emit release-notes links that point at GitHub Release pages
(its own --release-notes-url-prefix appends ".html" to the version),
so we splice one in ourselves. Sparkle then shows a "Release Notes"
button in the update dialog that links to the GitHub release page.

Idempotent: re-running is a no-op.

Environment:
  VERSION   e.g. "0.2.1"           (required)
  REPO      e.g. "neomavkda3/MDPrintView"  (required)
"""
import os
import sys


def main() -> int:
    version = os.environ.get("VERSION", "").strip()
    repo    = os.environ.get("REPO", "").strip()
    if not version or not repo:
        print("[appcast] VERSION / REPO env not set; nothing to do", file=sys.stderr)
        return 1

    url  = f"https://github.com/{repo}/releases/tag/v{version}"
    tag  = f"<sparkle:shortVersionString>{version}</sparkle:shortVersionString>"
    link = f"<sparkle:releaseNotesLink>{url}</sparkle:releaseNotesLink>"

    with open("appcast.xml", encoding="utf-8") as f:
        content = f.read()

    if tag not in content:
        print(f"[appcast] {tag} not found; skipping", file=sys.stderr)
        return 0
    if link in content:
        print(f"[appcast] releaseNotesLink for v{version} already present; skipping")
        return 0

    content = content.replace(tag, tag + f"\n            {link}", 1)
    with open("appcast.xml", "w", encoding="utf-8") as f:
        f.write(content)
    print(f"[appcast] added releaseNotesLink for v{version} → {url}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
