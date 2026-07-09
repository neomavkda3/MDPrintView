# Changelog

All notable changes to MDPrintView are listed here. Format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

For downloads and Sparkle-signed release artifacts, see [Releases](https://github.com/neomavkda3/MDPrintView/releases).

## [Unreleased]

### Planned for v0.3.3
- Find in the preview pane (WKWebView find bar overlay)
- Custom Find & Replace bar with regex support (replaces the native AppKit find bar in the editor)

### Planned for v0.4.0
- Word count and reading time in the editor status area

### Planned for v0.5.0
- Focus mode + typewriter scrolling

---

## [0.3.2] — 2026-07-08

### Added
- **Line-number gutter in the editor.** Always on. Numbers hard source lines (a soft-wrapped paragraph gets one number on its first visual row) — which is the version you want when talking about "line 47." The gutter widens as the digit count grows; the number font scales with the editor font. `NSRulerView` installed as the scroll view's vertical ruler so scroll sync comes free; geometry comes from TextKit 2 layout fragments. 7 new `LineIndex` tests covering UTF-16 offsets (emoji, CJK), trailing newlines, consecutive newlines, past-the-end clamping. Thanks to [@xtreme-andy-shen](https://github.com/xtreme-andy-shen) (PR #5).

### Fixed
- **File → New (`⌘N`) and File → Open (`⌘O`)** are now wired app-wide. Pre-existing v0.1.0 bug — SwiftUI only auto-injects New/Open into the File menu when a `DocumentGroup` is the first scene, but ours is `Window` (the Welcome scene) so it can present at launch. Wired explicitly through `NSDocumentController`. Reported by [@xtreme-andy-shen](https://github.com/xtreme-andy-shen) while smoke-testing #5.

---

## [0.3.1] — 2026-07-08

Two contributor features from [@xtreme-andy-shen](https://github.com/xtreme-andy-shen): preview-placed page breaks, and raw HTML rendering with a GitHub-parity sanitizer.

### Added
- **Page breaks from the preview pane.** Hover the gap between two blocks → click to insert a page break; click ✕ on the divider to remove. Breaks paginate `⌘P` and PDF export via `@media print { break-after: page }`. Session-only, in-memory (`PageBreakStore`, one per document window) — nothing is written to the markdown source, and breaks are gone when the window closes. Anchors are `(block index, 64-char text fingerprint)` pairs re-resolved on every render, so breaks follow their content while you edit; orphans are dropped. Thanks to [@xtreme-andy-shen](https://github.com/xtreme-andy-shen) (PR #3).
- **Raw HTML in the preview** via a GitHub-parity sanitizer. `<div align="center">` headers, `<details>`/`<summary>` folds, `<kbd>`, `<sup>`/`<sub>` render as they do on GitHub — including this repo's own README header. Hand-written 302-line sanitizer, no new dependencies. Mirrors GitHub's html-pipeline `SanitizationFilter` allowlist: `script`/`style`/`iframe`/`object`/`embed` drop with contents; unknown tags strip keeping children; malformed input fails closed to escaped text; `on*` and `style` attributes are dropped; `javascript:` and other non-`http(s)`/`mailto` URL schemes rejected. Reviewed against 15 additional adversarial vectors (HTML-entity-encoded schemes, tab/newline obfuscation, DOCTYPE/CDATA smuggling, SVG `<foreignObject>`, attribute breakout) — all handled safely. Thanks to [@xtreme-andy-shen](https://github.com/xtreme-andy-shen) (PR #4).

### Fixed
- Negative-index guard on the page-break `.add` message handler — currently unreachable but hardened as defense-in-depth at the WKWebView message boundary.

---

## [0.3.0] — 2026-07-06

Table-stakes Find and Spelling menu items — the biggest gap from the competitive audit.

### Added
- **Find in the editor.** `⌘F` opens macOS's native find bar. `⌘G` and `⌘⇧G` step forward and backward through matches, `⌘E` seeds the find field from the current selection, and `⌘J` jumps the editor to the current selection.
- **Spelling and Grammar submenu** under Edit. `⌘:` opens the standard Show Spelling and Grammar panel; `⌘;` runs Check Document Now; the `Check Spelling While Typing` and `Check Grammar With Spelling` toggles bind to macOS's system spell-checker.

---

## [0.2.1] — 2026-07-03

Sparkle UX polish: silent auto-install by default plus a Release Notes link in the update dialog.

### Added
- **Silent auto-install** — updates now download and install on your next relaunch without a dialog. Users who prefer to be asked can turn it off in **Settings → Software Updates**, or via Sparkle's own update-dialog checkbox. Anyone who previously set an explicit preference keeps their choice.
- **Software Updates** section in Settings with an explanation of what the toggle does.
- **Release Notes link** in the Sparkle update dialog. Clicking it opens the GitHub release page for the incoming version.

### Fixed
- A duplicate `env:` block in the release workflow that had crept into the appcast-generation step.

---

## [0.2.0] — 2026-07-02

Drag-and-drop file opening — first contribution from an external collaborator.

### Added
- **Drag and drop to open files** — drop `.md` or `.txt` files onto the Welcome window or an open document window, anywhere on the editor, preview, sidebar, or gaps. Each file opens as a tab in the existing window. Acceptance rule mirrors the Open panel exactly: no content sniffing, no extensionless-file surprises. Editor text selection drag still works; unsupported file types are rejected without insertion or navigation. Thanks to [@xtreme-andy-shen](https://github.com/xtreme-andy-shen) for the well-scoped PR (#1) with 11 new tests.

---

## [0.1.1] — 2026-06-12

Audit-pass fixes surfaced by a batch of code, concurrency, and memory reviews.

### Fixed
- **Welcome-on-launch toggle** now actually suppresses the welcome window at launch (previously a no-op).
- **External-reload race** during autosave no longer eats typed text. The editor tracks last-saved content and ignores reload events that correspond to our own save, or when we have unsaved in-app edits.
- **Pinned documents** survive transient bookmark resolution failures (unmounted external drives, offline network shares, evicted iCloud items). They reappear when the resource is back.

### Changed
- **File watcher** retries with backoff (50/250/1000 ms) when the watched file is briefly missing — slow atomic writes and deleted-then-recreated files no longer leave the watcher dormant.
- **System-wide Fonts panel** target is restored when MDPrintView's font picker closes (was hijacking `changeFont:` in other text views).
- Several concurrency and memory hygiene fixes around debounced highlighting, render scheduling, and welcome-screen formatters.

### Performance
- Welcome screen no longer re-reads pinned files from disk on every search keystroke.

---

## [0.1.0] — 2026-06-11

First public OSS binary release. Signed, notarized, Sparkle auto-updating, GPL-3.0.

### Added

#### Editor
- NSTextView via TextKit 2.
- Two editor modes: Source (default) and Hybrid ("Rich" — E1 + E2).
- Source mode: syntax highlighting for headings, code, and links.
- Hybrid mode: rich inline styling with faded marks.
- Eleven curated editor fonts grouped by category (Mono / Serif / Sans) plus a **Browse…** button opening the native macOS Fonts panel for any installed family.
- Editor font size in Settings: 10–24 pt.
- Writing Tools (Rewrite / Proofread / Compose) opted in on macOS 26.
- Formatting toolbar: Bold / Italic / Strike / Heading menu / Link / Lists / Code menu.
- Mermaid editor sheet (`⌘⇧M`): split-pane NSTextView with live WKWebView preview.
- Outline sidebar via `NavigationSplitView`.
- Debounced syntax highlight (80 ms) and debounced preview render (40 ms).

#### File handling
- DocumentGroup with `.md` / `.markdown` / `.mdown` UTI registration.
- Live external-edit reload via kqueue (`DispatchSource`) — files edited by vim, sed, Claude Code, VS Code, or other tools that write raw are reflected in place without switching apps.
- Tabbed document windows (Safari-style) via `tabbingMode = .preferred`.
- Recent and pinned documents on the welcome screen with content previews, search, and date grouping.

#### Preview
- WKWebView with fully bundled JS/CSS (no network entitlement).
- Mermaid 11.x diagrams (fenced ` ```mermaid ` blocks).
- KaTeX 0.16.x math — `$$…$$` display, `\(…\)` inline. Single-`$` deliberately not a delimiter, to avoid mangling currency in prose.
- Four reading themes: Original, Sepia, Quiet, Focus.
- Screen / Print preview mode toggle.
- Print-mode CSS with `@page` rules and page-break avoidance for headings, code blocks, tables, and images.

#### App-level UX
- Welcome window at launch (SwiftUI `Window` scene, `.defaultLaunchBehavior(.presented)`) — hidden behind a Settings toggle if undesired.
- System / Light / Dark appearance picker.
- First-launch prompt offering to set MDPrintView as the default `.md` handler.
- Settings sheet (`⌘,`): Appearance / Editor / Print / File handling.

#### Print and export
- `⌘P` opens the system print dialog.
- `⌘⇧E` exports PDF via `NSPrintInfo` with `.save` disposition.

#### Layout
- Three layout modes: Editor only, Split, Preview only.
- Toolbar 3-icon segmented picker.
- View menu shortcuts: `⌥⌘1`, `⌥⌘2`, `⌥⌘3`.
- Persisted globally via `AppSettings.defaultLayoutMode`.

#### Distribution
- Developer ID Application signed, Apple-notarized, stapled `.dmg`.
- Sparkle 2.9.3 auto-update via **MDPrintView → Check for Updates…**.
- Appcast served from `raw.githubusercontent.com` (Maccy pattern); binary from GitHub Releases.
- GitHub Actions release workflow (`tag → notarized DMG → Release → signed appcast`).
- Privacy Manifest declared: `NSPrivacyAccessedAPICategoryUserDefaults` (CA92.1), `NSPrivacyAccessedAPICategoryFileTimestamp` (C617.1).

### Testing
- 50+ tests across renderer, highlighter, styler, controller, outline, and MermaidBlock (Swift Testing).
- `scripts/smoke.sh` end-to-end manual verification.
- `scripts/release.sh` local end-to-end release dry-run.

---

[Unreleased]: https://github.com/neomavkda3/MDPrintView/compare/v0.3.2...HEAD
[0.3.2]: https://github.com/neomavkda3/MDPrintView/releases/tag/v0.3.2
[0.3.1]: https://github.com/neomavkda3/MDPrintView/releases/tag/v0.3.1
[0.3.0]: https://github.com/neomavkda3/MDPrintView/releases/tag/v0.3.0
[0.2.1]: https://github.com/neomavkda3/MDPrintView/releases/tag/v0.2.1
[0.2.0]: https://github.com/neomavkda3/MDPrintView/releases/tag/v0.2.0
[0.1.1]: https://github.com/neomavkda3/MDPrintView/releases/tag/v0.1.1
[0.1.0]: https://github.com/neomavkda3/MDPrintView/releases/tag/v0.1.0
