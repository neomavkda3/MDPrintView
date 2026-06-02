# mdview — Design Document

**Date:** 2026-06-01
**Status:** Brainstorm validated, ready for implementation planning
**Author:** Chris Magsisi (with Claude Code)

## Summary

`mdview` is a native macOS markdown editor + viewer with print-quality typography. Inspired by MacDown's editor+preview pattern and MDviewer's print-ready rendering, rewritten ground-up in SwiftUI/AppKit for Mac App Store distribution on macOS 26.

The app ships two editor modes (source+preview and Typora-style hybrid live-format), an outline sidebar, an integrated Mermaid diagram editing experience, and a screen/print preview toggle so users see exactly what their printed output will look like while they edit.

## Goals

- Edit `.md`/`.markdown`/`.mdown`/`.txt` files with adjustable text size and a markdown formatting toolbar.
- Render Mermaid diagrams inline with an integrated editing experience.
- Provide a "print preview" view mode while editing that shows page breaks, margins, and print typography.
- Ship to Mac App Store with full sandbox, privacy manifest, and signed/notarized build.

## Non-goals (v1)

- iOS / iPadOS / visionOS targets.
- Cloud sync, collaboration, version history beyond macOS's native document versions.
- Plugins or extensions.
- Custom themes beyond the bundled default + a dark variant.

## Constraints

- **Distribution:** Mac App Store.
- **Minimum OS:** macOS 26.
- **Language/UI:** Swift, SwiftUI shell with AppKit (`NSViewRepresentable`) where SwiftUI doesn't reach.
- **Editor mode coverage:** both source+preview and hybrid Typora-style, day one.
- **Sandbox:** strict — no network entitlement, all third-party JS bundled locally.

---

## A. App architecture & document model

- **App lifecycle:** SwiftUI `DocumentGroup`. Gives per-file windows, autosave, versions, Edited badge, Recent Documents, tabbed windows, file coordination, and sandboxed file access via standard open/save panels — all for free on macOS 26.
- **Document type:** `MarkdownDocument: ReferenceFileDocument` holding raw markdown `String` + `MarkdownMetadata` (frontmatter, computed outline). Reference-type chosen for fine-grained undo and to avoid full-string snapshots on every keystroke.
- **UTIs registered:** `net.daringfireball.markdown` + `public.plain-text` (extensions: `.md`, `.markdown`, `.mdown`, `.txt`).
- **Scenes:** one `DocumentGroup` scene + a `Settings` scene (font size, default theme, default page size).
- **State ownership:**
  - `MarkdownDocument` — file contents, dirty state, undo.
  - `EditorViewModel` (Observable, per-window) — UI state: pane visibility, current mode, scroll sync, mermaid overlays. Not persisted.
  - `AppSettings` (Observable, `@AppStorage`-backed) — user preferences.
- Strict view/view-model/data separation per `axiom-swiftui-architecture`.

## B. Editor: TextKit 2 source view + hybrid live-format

- One `NSTextView` wrapped via `NSViewRepresentable` as `MarkdownTextView`. Both editor modes share this view.
- **Markdown parsing:** `swift-markdown` (Apple) — used both for syntax-highlighting tokens and for the HTML render pipeline.
- **Source mode:**
  - Monospaced font, syntax highlighting applied as `NSAttributedString` attributes (headings, emphasis, code, links).
  - Editor font size in `AppSettings`. Cmd+Plus / Cmd+Minus to adjust.
  - Writing Tools free from `NSTextView` on macOS 26.
- **Hybrid live-format mode:**
  - Same `NSTextView`, with `NSTextContentStorage` + `NSTextLayoutManager` delegates that hide markdown syntax marks (`**`, `_`, `#`) when the cursor is outside their span, and reveal them when the cursor enters.
  - Headings get proportional/larger fonts via attribute overrides.
  - Isolated as `LiveFormatStyler` with unit tests (doc + cursor → expected attribute ranges).
  - **Gating:** 1-week spike on real docs. If the cursor-aware reveal proves rough, defer hybrid mode to v1.1.
- **Undo:** NSTextView's default undo coordinator; `MarkdownDocument` coalesces edits into undoable bursts.
- **Mermaid editing in editor:** when cursor sits inside a ` ```mermaid ` fence, a Liquid Glass overlay in the editor margin shows a mini live render. Click to expand into the modal mermaid editor sheet (see Section D).

## C. Preview pipeline & print-mode toggle

- **Preview:** `WKWebView` with all assets bundled (no network entitlement).
- **Render pipeline:**
  1. Editor text changes → 80ms debounce.
  2. `MarkdownRenderer` (Swift actor) parses with `swift-markdown` → emits HTML.
  3. HTML piped to WebView via `evaluateJavaScript("setBody(html)")` — DOM swap, preserves scroll.
  4. Mermaid + KaTeX re-scan after each swap.
- **Decision:** HTML rendered in **Swift**, not JS — testable without a WebView, deterministic, no renderer-quirk lock-in.
- **Bundled assets:**
  - `preview.css` — adapted from MDviewer's print-ready CSS (serif body, `@page` rules).
  - `mermaid.min.js` (bundled).
  - `katex.min.js` + KaTeX CSS.
  - `dompurify.min.js` — sanitize HTML before injection.
  - Strict CSP: `default-src 'none'; style-src 'self' 'unsafe-inline'; script-src 'self';`.
- **View modes (preview pane):**
  - **Screen** — flowing, viewport-width.
  - **Print** — simulated paper size from `NSPrintInfo` (Letter/A4), visible page breaks, margins, optional header/footer placeholders. Same DOM, `<body>` class swap.
  - `Cmd+P` uses WKWebView's `print(_:)` and inherits print CSS — WYSIWYG print.

## D. UI layout, toolbar, mermaid editing

```
┌─────────────────────────────────────────────────────┐
│  Toolbar  [B I S]  [H1 H2 H3]  [• 1. ☐]  [</>] ...  │
├──────────────┬────────────────────┬─────────────────┤
│  Outline     │   Editor           │   Preview       │
│  (TOC)       │   (TextKit 2)      │   (WKWebView)   │
│  collapsible │                    │   screen/print  │
└──────────────┴────────────────────┴─────────────────┘
```

- **Outline sidebar:** auto from headings, SwiftUI `List` + `OutlineGroup`, click scrolls editor + preview, collapsible.
- **Editor / preview split:** AppKit `HSplitView` (better divider drag than SwiftUI's split on macOS). Either pane hideable.
- **Mode switch:** toolbar segmented control `Source` / `Hybrid`. Hybrid collapses the preview pane.
- **Preview view-mode switch:** inline above preview, `Screen` / `Print`. Per-window state.
- **Liquid Glass:** toolbar, mode switches, mermaid overlay (`axiom-liquid-glass`).
- **Formatting toolbar actions:** bold, italic, strikethrough; H1/H2/H3; bulleted/numbered/task lists; inline code; code block; link (URL sheet); insert mermaid. Toolbar actions operate on the markdown source string; in Hybrid mode the view-model translates rendered-space selections to source ranges.
- **Mermaid UX (lighter-touch decision):** "Insert mermaid" inserts a ` ```mermaid ` skeleton inline and shows the in-margin live preview. Modal mermaid editor sheet opens only on explicit user action (click in-margin preview or `Cmd+Shift+M` with cursor inside a mermaid block). Sheet has `NSTextView` source on the left, live `WKWebView` mermaid render on the right, Apply/Cancel.
- **Keyboard shortcuts:** `Cmd+B/I/U`, `Cmd+1/2/3`, `Cmd+K` (link), `Cmd+Shift+M` (mermaid), `Cmd+Opt+S` (source/hybrid), `Cmd+Opt+P` (screen/print), `Cmd+P` (print), `Cmd+Shift+E` (export PDF).
- **Accessibility:** all controls labeled, VoiceOver outline navigation. `axiom-ios-accessibility` patterns apply to macOS.

## E. App Store readiness, sandbox, privacy, testing

### Sandbox & entitlements

- `com.apple.security.app-sandbox` = YES
- `com.apple.security.files.user-selected.read-write` (DocumentGroup handles)
- `com.apple.security.files.bookmarks.app-scope` (live reload from external editors)
- **No network entitlement.** All JS/CSS bundled. WebView CSP enforces it.
- No microphone / camera / location.

### Privacy manifest (`PrivacyInfo.xcprivacy`)

- `NSPrivacyTracking` = false
- `NSPrivacyTrackingDomains` = []
- `NSPrivacyCollectedDataTypes` = []
- Required Reason APIs: `UserDefaults` (CA92.1) and `FileTimestamp` (C617.1) if used.

### Testing (`axiom-swift-testing`)

- `MarkdownRendererTests` — swift-markdown → HTML snapshot tests, no WebView.
- `LiveFormatStylerTests` — doc + cursor → expected attribute ranges.
- `EditorViewModelTests` — toolbar actions → text mutations.
- `MermaidExtractorTests` — finding/replacing mermaid fences.
- One end-to-end UI test: open sample → toggle modes → print to PDF → diff PDF text.

### Phased build plan

1. **Week 1** — Project skeleton, `DocumentGroup` + UTI, file open/save, raw `NSTextView` (no highlight), Swift-side markdown→HTML, `WKWebView` preview, screen mode only. **Milestone:** open .md, see preview, edit, save.
2. **Week 2** — Syntax highlighting, formatting toolbar, outline sidebar, Liquid Glass styling, print-mode CSS, WebView print dialog, PDF export.
3. **Week 3** — Hybrid-mode spike. **Gate:** ship in v1 or defer.
4. **Week 4** — Mermaid editor (inline skeleton + in-margin preview + expand sheet), KaTeX, settings, accessibility pass.
5. **Week 5** — Privacy manifest, signing/notarization dry-run, MAS internal testing, screenshots, App Store Connect metadata.

### Skills queued for implementation

`axiom-app-composition`, `axiom-swiftui-architecture`, `axiom-textkit-ref`, `axiom-swiftui-layout`, `axiom-liquid-glass`, `axiom-hig`, `axiom-storage`, `axiom-privacy-ux`, `axiom-swift-testing`, `axiom-app-store-connect-ref`, `axiom-ios-accessibility`.

---

## Open decisions deferred to implementation

- Bundle ID (proposed: `net.cmagsisi.mdview` — confirm before App Store Connect registration).
- App icon and marketing assets.
- Pricing model (free, paid one-time, or freemium).
- Exact swift-markdown version pin.
- Whether to additionally ship a Quick Look extension (post-v1).
