# MDPrintView Status

What's shipped in v1.0 vs deferred to v1.1.

## v1.0 — feature-complete

### Editor
- ✅ NSTextView via TextKit 2 (TextKit 1 fallback never triggered)
- ✅ Two editor modes: Source (default) and Hybrid ("Rich" — E1 + E2)
- ✅ Source mode: syntax highlighting (headings, code, links) — `SyntaxHighlighter`
- ✅ Hybrid mode: rich inline styling + faded marks — `LiveFormatStyler`
- ✅ Editor font family in Settings: System Mono / NY Serif / SF Sans
- ✅ Editor font size in Settings: 10–24 pt
- ✅ Formatting toolbar: Bold / Italic / Strike / Heading menu / Link / Lists menu / Code & diagrams menu
- ✅ Mermaid editor sheet (Cmd+Shift+M): split-pane NSTextView + WKWebView live render
- ✅ Outline sidebar (NavigationSplitView)
- ✅ Debounced syntax highlight (80 ms) + debounced preview render (40 ms) — typing stays smooth on large docs

### Preview
- ✅ WKWebView with bundled JS/CSS (no network entitlement)
- ✅ Swift-side markdown → HTML renderer (20 tests)
- ✅ HTML escape on all user content (security audit)
- ✅ Mermaid 11.x diagrams (fenced ` ```mermaid ` blocks)
- ✅ KaTeX 0.16.x math (`$inline$` and `$$block$$`)
- ✅ Four reading themes: Original, Sepia, Quiet, Focus
- ✅ Screen / Print preview mode toggle
- ✅ Print-mode CSS with `@page` rules + page-break avoidance for headings/code/tables/images

### Print & export
- ✅ `Cmd+P` → system print dialog (WKWebView print operation)
- ✅ `Cmd+Shift+E` → PDF export via NSSavePanel + `NSPrintInfo` with `.save` disposition

### Layout (Polish.E)
- ✅ Three layout modes: Editor only / Split / Preview only
- ✅ Toolbar 3-icon segmented picker
- ✅ View menu shortcuts: `Cmd+Opt+1`, `Cmd+Opt+2`, `Cmd+Opt+3`
- ✅ Persisted globally via `AppSettings.defaultLayoutMode` (@AppStorage)

### App Store readiness
- ✅ Sandbox entitlements (Release): app-sandbox + user-selected files + bookmarks
- ✅ Privacy manifest: no tracking, no data collection, UserDefaults reason CA92.1
- ✅ Info.plist: copyright, productivity category, markdown UTI as Owner
- ✅ App icon asset catalog (10 sizes, placeholder artwork)
- ✅ `scripts/archive.sh` produces a signed MAS package
- ✅ App Store listing copy drafted
- ✅ Privacy policy drafted
- ✅ Pre-submission checklist drafted

### Testing
- ✅ 50+ tests across renderer, highlighter, styler, controller, outline, MermaidBlock
- ✅ `scripts/smoke.sh` end-to-end manual verification

## Pending (user-driven, blocks submission)

| Item | Why blocked |
|---|---|
| Apple Developer Program enrollment | $99/yr, 24–48 h verification |
| Bundle ID registration in App Store Connect | Needs Apple Developer membership |
| Final app icon artwork | Apple rejects placeholder icons under Guideline 4.0 |
| Privacy policy hosting | Need a public URL — Gist or own domain |
| 5 marketing screenshots | All at same dimensions (1440×900 or 2880×1800) |
| ASC listing creation | Bundle ID needs to exist first |
| Final archive + Transporter upload | Needs Team ID |

## v1.1 — known deferred

| Item | Why deferred | Source of decision |
|---|---|---|
| Hybrid mode E3 cursor-aware fold/reveal | `LiveFormatStyler.apply` is 8.4 s on 50 KB; wiring to selection changes freezes the editor. Optimization roadmap (4 options) documented. | `docs/plans/2026-06-05-hybrid-mode-decision.md` |
| In-margin Mermaid live preview overlay | Design doc Section D called for this; would need precise NSTextView range-to-frame conversion + glass overlay positioning + scroll sync. Modal sheet pattern (Cmd+Shift+M) shipped instead. | `docs/plans/2026-06-06-MDPrintView-week4.md` scope decisions |
| KaTeX woff2 font bundling | Math currently uses system fallback fonts — slightly degraded metrics but functional | `docs/plans/2026-06-06-vendored-assets.md` |
| Editor-side math rendering | Preview pane only in v1; source mode shows raw `$…$` | Week 4 scope decision |
| Editor-side Dynamic Type | macOS NSTextView doesn't auto-respond to system text size changes the way iOS does. Settings slider is the workaround. | `docs/plans/2026-06-06-week4-notes.md` |
| Outline click-to-scroll | Currently outline rows are display-only | Not yet attempted |
| Per-document layout preference | Layout is a global @AppStorage today; per-doc would need URL-keyed storage | Polish.E intentionally global |
| Tip-jar IAP | Free-no-IAP simplest for v1 | Week 5 plan |
| Quick Look extension | Out of scope for v1 | Design doc non-goals |
| Cloud sync / collaboration | Out of scope for v1 (and v1.x) | Design doc non-goals |
| End-to-end XCUITest | Requires TCC plumbing for the test runner; smoke script + 50 unit tests cover the highest-risk regressions | `docs/plans/2026-06-02-MDPrintView-week2.md` F2 deferred |
| Quick Window menu items showing checkmarks for current mode | macOS convention; SwiftUI doesn't have a clean primitive for it | Polish follow-up |

## Recent debugging notes (in case they recur)

| Symptom | Cause | Fix commit |
|---|---|---|
| Preview pane empty after opening a doc | Inline `<script>` in `preview.html` blocked by CSP `script-src 'self'` | W1 — moved JS to bundled file + `evaluateJavaScript` injection |
| Crash opening any `.md` file | `MarkdownDocument` had `@MainActor` but `NSDocumentController` invokes `init(configuration:)` off-main | W1.T8 — removed `@MainActor` from class |
| Preview empty again after sandbox added | Debug build was ad-hoc-signed + sandboxed; macOS 26 WKWebView WebContent helper refuses to spawn | W5 — Debug uses `MDPrintView-debug.entitlements` (no sandbox); Release archive keeps sandbox |
| Typing felt sticky on 10 KB+ docs | `SyntaxHighlighter.apply` ran synchronously on every keystroke (full AST walk + attribute pass) | Polish.F — 80 ms cancel-and-reschedule Task |

## Looking at the git history

The git log is a faithful record. Notable shipping commits:

```
84795d8 feat: editor/split/preview layout toggle + responsiveness fix
17a3504 fix: Debug builds drop app-sandbox to unblock WKWebView on ad-hoc signing
3437f79 feat: persist layout via AppSettings + View menu shortcuts (Cmd+Opt+1/2/3)
066e3d1 docs: pre-submission checklist
9148cc0 docs: privacy policy draft
51eedb9 chore: scripts/archive.sh produces MAS distribution package
e56ca16 feat: AppIcon asset catalog with placeholder artwork + regen script
bd99633 feat: PrivacyInfo manifest
5dec5c3 feat: sandbox entitlements (Release config)
cd915fa docs: App Store listing copy (themes, fonts, Versions)
a24b12a feat: consolidate toolbar — Lists and Code groups become menu buttons
1bb82f1 feat: editor font family picker
d1d2c1a feat: preview themes (Original / Sepia / Quiet / Focus)
```
