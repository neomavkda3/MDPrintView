<div align="center">

# MDPrintView

A native macOS markdown editor with print-quality typography.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![macOS 26+](https://img.shields.io/badge/macOS-26.0+-black?logo=apple)](https://www.apple.com/macos/)
[![Latest release](https://img.shields.io/github/v/release/neomavkda3/MDPrintView?include_prereleases)](https://github.com/neomavkda3/MDPrintView/releases)

<!-- Screenshot placeholder — replace with an actual hero shot after first release tag -->
<!-- ![MDPrintView screenshot](assets/hero.png) -->

</div>

MDPrintView is a markdown editor that takes printing seriously. Three pane modes (Editor / Split / Preview), four reading themes, native NSTextView editing, Mermaid diagrams, LaTeX math, and a print pipeline that keeps headings, code blocks, and tables together across page breaks. Built in SwiftUI + AppKit on macOS 26.

## Features

- **Three layout modes** — Editor, Split, Preview-only — switch with `⌥⌘1` / `⌥⌘2` / `⌥⌘3`
- **Four reading themes** — Original, Focus, Sepia, Print
- **Live external-edit reload** — edit the file from another tool (vim, Claude Code, VS Code) and MDPrintView updates in place
- **Mermaid diagrams + LaTeX math** — KaTeX (display via `$$...$$`, inline via `\(...\)`)
- **Print-quality output** — page breaks respect headings, code, and tables
- **PDF export** — `⌘⇧E`
- **Eleven editor fonts** plus full system font picker via the standard Fonts panel
- **System / Light / Dark appearance** — overrides macOS preference per-app
- **Welcome screen** — recent + pinned documents with search and content previews
- **Document tabs** — multiple files cluster as tabs in a single window
- **Privacy-first** — zero network calls, sandbox-ready, Privacy Manifest declared

## Requirements

- macOS 26.0 (Tahoe) or later
- Apple Silicon or Intel

## Install

### Direct download (recommended)

Grab the latest `.dmg` from [Releases](https://github.com/neomavkda3/MDPrintView/releases) and drag MDPrintView to `/Applications`.

The DMG is signed with a Developer ID Application certificate and notarized by Apple, so Gatekeeper accepts it without any "unidentified developer" warnings. The app self-updates via Sparkle — checks on launch (daily) and on demand via **MDPrintView → Check for Updates…**.

### Homebrew Cask

Planned after a few stable point releases, once the install flow has real-world miles:

```sh
brew install --cask mdprintview
```

### Mac App Store

Planned as a paid SKU — same app, "support development" pricing. Use the free OSS build above if you'd rather not pay. No ETA yet.

## Build from source

```sh
brew install xcodegen
git clone https://github.com/neomavkda3/MDPrintView.git
cd MDPrintView
xcodegen generate
xcodebuild -project MDPrintView.xcodeproj -scheme MDPrintView -configuration Debug build
```

Full contributor build notes in [CONTRIBUTING.md](CONTRIBUTING.md).

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `⌘N` / `⌘O` | New / Open document |
| `⌘B` / `⌘I` | Bold / Italic |
| `⌘1` `⌘2` `⌘3` | Heading 1 / 2 / 3 |
| `⌘K` | Insert link |
| `⌘⇧M` | Mermaid editor |
| `⌘P` / `⌘⇧E` | Print preview / Export PDF |
| `⌥⌘1` `⌥⌘2` `⌥⌘3` | Editor only / Split / Preview only |
| `⌘,` | Settings |

## Contributing

Issues, ideas, and PRs welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first and the [Code of Conduct](CODE_OF_CONDUCT.md).

## Funding

If MDPrintView is useful to you, sponsorship covers the Apple Developer Program fee and helps me keep shipping:

- [GitHub Sponsors](https://github.com/sponsors/neomavkda3) — 0% platform fee
- Mac App Store SKU (post-v1.0) — same app, "support development" pricing

## License

[GNU General Public License v3.0](LICENSE). The OSS build under this license can be freely modified and redistributed, but cannot be repackaged for sale (Section 6 anti-Tivoization is incompatible with Mac App Store terms). The MAS SKU is published separately under proprietary terms by the copyright holder.

## Architecture + history

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — how the pieces fit together
- [`docs/STATUS.md`](docs/STATUS.md) — what's shipped vs. deferred
- [`docs/plans/`](docs/plans/) — design + implementation plans (dated, accreting)
