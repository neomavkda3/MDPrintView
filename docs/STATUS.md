# MDPrintView Status

Current shipping state, near-term roadmap, and indefinitely-deferred items.

## Shipped — v0.1.0 (2026-06-11)

First public OSS binary release. Signed, notarized, Sparkle auto-updating, GPL-3.0.

### Editor
- NSTextView via TextKit 2 (TextKit 1 fallback never triggered)
- Two editor modes: Source (default) and Hybrid ("Rich" — E1 + E2)
- Source mode: syntax highlighting (headings, code, links) — `SyntaxHighlighter`
- Hybrid mode: rich inline styling + faded marks — `LiveFormatStyler`
- 11 editor fonts grouped by category (Mono / Serif / Sans) plus a "Browse…" button opening the native macOS Fonts panel for any installed family
- Editor font size in Settings: 10–24 pt
- Writing Tools (Rewrite / Proofread / Compose) opted in on macOS 26
- Formatting toolbar: Bold / Italic / Strike / Heading menu / Link / Lists menu / Code & diagrams menu
- Mermaid editor sheet (`⌘⇧M`): split-pane NSTextView + WKWebView live render
- Outline sidebar (NavigationSplitView)
- Debounced syntax highlight (80 ms) + debounced preview render (40 ms) — typing stays smooth on large docs

### File handling
- DocumentGroup with `.md` / `.markdown` / `.mdown` UTI registration
- Live external-edit reload via `DispatchSource` / kqueue — files changed by Claude Code, vim, sed, etc. reload in place
- Tabbed document windows (Safari-style) via `tabbingMode = .preferred`
- Recent + pinned documents on the welcome screen with content previews, search, and date grouping
- Pinned URLs persisted as security-scoped bookmarks

### Preview
- WKWebView with bundled JS/CSS (no network entitlement)
- Swift-side markdown → HTML renderer (`MarkdownRenderer`)
- HTML escape on all user content
- Mermaid 11.x diagrams (fenced ` ```mermaid ` blocks)
- KaTeX 0.16.x math — `$$…$$` display, `\(…\)` inline (single-`$` deliberately *not* a delimiter to avoid mangling currency in prose)
- Four reading themes: Original, Sepia, Quiet, Focus
- Screen / Print preview mode toggle
- Print-mode CSS with `@page` rules + page-break avoidance for headings/code/tables/images

### App-level UX
- Welcome window at launch via `Window` scene + `.defaultLaunchBehavior(.presented)`, hidden behind a Settings toggle if undesired
- System / Light / Dark appearance picker — flips `NSApp.appearance` so AppKit alerts/panels follow
- First-launch prompt offering to set MDPrintView as the default `.md` handler (dismissable)
- Settings sheet (`⌘,`): Appearance / Editor (font + size) / Print (page size) / File handling

### Print & export
- `⌘P` → system print dialog (WKWebView print operation)
- `⌘⇧E` → PDF export via NSSavePanel + `NSPrintInfo` with `.save` disposition

### Layout
- Three layout modes: Editor only / Split / Preview only
- Toolbar 3-icon segmented picker
- View menu shortcuts: `⌥⌘1`, `⌥⌘2`, `⌥⌘3`
- Persisted globally via `AppSettings.defaultLayoutMode` (@AppStorage)

### Distribution
- Developer ID Application signed + Apple-notarized + stapled `.dmg`
- Sparkle 2.9.3 auto-update on launch + on-demand via **MDPrintView → Check for Updates…**
- Appcast served from `raw.githubusercontent.com` (Maccy pattern); binary from GitHub Releases
- GitHub Actions release workflow (`tag → notarized DMG → published Release → signed appcast`) — see [`docs/RELEASING.md`](RELEASING.md)
- Privacy manifest declared: NSPrivacyAccessedAPICategoryUserDefaults (CA92.1), NSPrivacyAccessedAPICategoryFileTimestamp (C617.1)

### Testing
- 50+ tests across renderer, highlighter, styler, controller, outline, MermaidBlock (Swift Testing)
- `scripts/smoke.sh` end-to-end manual verification
- `scripts/release.sh` local end-to-end release dry-run (mirrors CI)

## Near-term roadmap

| Item | Why | Likely version |
|---|---|---|
| Real app icon artwork | Placeholder is functional but generic | v0.2.0 |
| Homebrew Cask submission | Convenience install path for power users | After ~2 stable point releases |
| Hero screenshot / GIF in README | First-impression matters for OSS discovery | v0.2.0 |
| `WelcomeViewModel` extraction | Architecture audit flagged business logic in view body | v0.2.0 |
| `@Environment` injection for PinnedDocuments + FontPickerCoordinator | Move off singletons for testability | v0.2.0 |
| Mac App Store SKU (paid, "support development") | Same codebase, separate `Release-MAS` config (sandboxed, no Sparkle) | Indefinite — wait for some traction |

## Indefinitely deferred

| Item | Why deferred | Source |
|---|---|---|
| Hybrid mode E3 cursor-aware fold/reveal | `LiveFormatStyler.apply` is 8.4 s on 50 KB; wiring to selection changes freezes the editor. Optimization roadmap (4 options) documented. | `docs/plans/2026-06-05-hybrid-mode-decision.md` |
| In-margin Mermaid live preview overlay | Would need precise NSTextView range-to-frame conversion + glass overlay positioning + scroll sync. Modal sheet pattern (`⌘⇧M`) shipped instead. | `docs/plans/2026-06-06-MDPrintView-week4.md` |
| KaTeX woff2 font bundling | Math currently uses system fallback fonts — slightly degraded metrics but functional | `docs/plans/2026-06-06-vendored-assets.md` |
| Editor-side math rendering | Preview pane only in v1; source mode shows raw `$$…$$` | Week 4 scope decision |
| Outline click-to-scroll | Outline rows are display-only today | Not yet attempted |
| Per-document layout preference | Layout is a global @AppStorage today; per-doc would need URL-keyed storage | Polish.E intentionally global |
| Quick Look extension | Out of scope | Design doc non-goals |
| Cloud sync / collaboration | Out of scope | Design doc non-goals |
| End-to-end XCUITest | Requires TCC plumbing for the test runner; smoke script + 50 unit tests cover the highest-risk regressions | `docs/plans/2026-06-02-MDPrintView-week2.md` F2 |

## Distribution history snapshots

- **2026-06-11 — v0.1.0**: first public OSS release. Distribution pivoted from MAS-first to OSS-first based on realistic revenue research; MAS SKU retained as a planned secondary channel. Repo public at github.com/neomavkda3/MDPrintView. GPL-3.0 selected to block third-party MAS clones while leaving dual-licensing options open for our own MAS build.

## Debugging notes (in case they recur)

| Symptom | Cause | Fix |
|---|---|---|
| Preview pane empty after opening a doc | Inline `<script>` in `preview.html` blocked by CSP `script-src 'self'` | Moved JS to bundled file + `evaluateJavaScript` injection |
| Crash opening any `.md` file | `MarkdownDocument` had `@MainActor` but `NSDocumentController` invokes `init(configuration:)` off-main | Removed `@MainActor` from class |
| Preview empty again after sandbox added | Debug build was ad-hoc-signed + sandboxed; macOS 26 WKWebView WebContent helper refuses to spawn | Debug uses `MDPrintView-debug.entitlements` (no sandbox) |
| Typing felt sticky on 10 KB+ docs | `SyntaxHighlighter.apply` ran synchronously on every keystroke | 80 ms cancel-and-reschedule Task |
| External edits not reflected in editor | NSFilePresenter doesn't reliably fire for non-coordinated writers | Switched watcher to `DispatchSource.makeFileSystemObjectSource` (kqueue) |
| `$X.XB in 2025 ... $13.2B` rendered as `XBin2025...13.2B` | KaTeX `$...$` auto-pairing eats currency, strips whitespace in math mode | Dropped single-`$` delimiter; require `$$...$$` or `\(...\)` |
| Notarization rejected Sparkle XPC binaries | Sparkle ships pre-signed by Sparkle team; Xcode's `--preserve-metadata` kept those signatures | `scripts/codesign-sparkle.sh` re-signs each nested binary with our Developer ID + timestamp |
| Notarization rejected with `get-task-allow=true` | Empty entitlements file → Xcode auto-injects the debug default | Explicitly set `com.apple.security.get-task-allow=false` in `MDPrintView.entitlements` |
