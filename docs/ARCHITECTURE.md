# MDPrintView Architecture

The shape of the actual code as of v1.0. Where this differs from `docs/plans/2026-06-01-MDPrintView-design.md`, this doc wins — the design doc captures the original brainstorm; this captures what shipped.

## High level

```
┌─────────────────────────────────────────────────────────────────────┐
│  Toolbar  [Layout] [Source/Hybrid]  [B I S] [H▾] [Link] [Lists▾] [Code▾]
├──────────────┬────────────────────────┬─────────────────────────────┤
│  Outline     │   MarkdownTextView      │  ┌─[Screen/Print] [🎨]──┐ │
│  Sidebar     │   (NSTextView in        │  │ PreviewWebView      │ │
│  (List +     │   NSScrollView via      │  │ (WKWebView)         │ │
│  OutlineGroup│   NSViewRepresentable)  │  │                     │ │
│  from        │                         │  │ bundled JS/CSS,     │ │
│  Outline.    │   SyntaxHighlighter or  │  │ themes via body     │ │
│  extract)    │   LiveFormatStyler      │  │ class swap          │ │
│              │   applied to            │  │                     │ │
│              │   NSTextStorage         │  │ Mermaid + KaTeX     │ │
│              │                         │  │ post-pass on swap   │ │
│              │                         │  └─────────────────────┘ │
└──────────────┴────────────────────────┴─────────────────────────────┘
                          NavigationSplitView           HSplitView
                          (sidebar)                     (editor + preview)
```

`HSplitView`'s children are conditional based on `LayoutMode` (editor only / split / preview only).

## Composition (top-down ownership)

```
MDPrintViewApp (MDPrintViewApp.swift)
  ├─ @State AppSettings (single instance, injected via .environment)
  ├─ DocumentGroup { file in DocumentView(document: file.document) }
  ├─ Settings { SettingsView() }
  └─ .commands {
       CommandGroup(replacing: .printItem) { PrintMenuItem, ExportPDFMenuItem }
       LayoutCommands(settings: …)   ← Cmd+Opt+1/2/3
     }

DocumentView (Views/DocumentView.swift)
  ├─ @Bindable document: MarkdownDocument  ← from DocumentGroup
  ├─ @Environment AppSettings              ← global preferences
  ├─ @State RenderState                    ← debounced markdown→HTML
  ├─ @State PreviewPrintController         ← weak ref to the WKWebView
  ├─ @State EditorController               ← weak ref to the NSTextView
  ├─ @State outline: [OutlineNode]
  ├─ @State previewMode, previewTheme, editorMode  ← per-window UI state
  │
  ├─ Body:
  │   NavigationSplitView {
  │     OutlineSidebar(nodes: outline)
  │   } detail: {
  │     HSplitView {
  │       if showsEditor: MarkdownTextView(…)
  │       if showsPreview: VStack { picker bar + PreviewWebView(…) }
  │     }
  │   }
  │   .onChange(document.text): RenderState.schedule + Outline.extract
  │   .focusedSceneValue(printPreview, exportPDF)
  │   .toolbar { EditorToolbar(...) }
  │   .sheet(item: editor.editingMermaidBlock) { MermaidEditorSheet(...) }
```

## Document model

`MarkdownDocument: ReferenceFileDocument` (class). Holds just `var text: String` and the standard `init(configuration:)`/`snapshot`/`fileWrapper` methods. Reference-type chosen because:
- SwiftUI's `@Bindable` works on classes
- DocumentGroup handles autosave + versions transparently
- We never had to land the planned `MarkdownMetadata` substructure — outline + render state are computed from `text` ad-hoc, faster than caching

**UTIs registered in `Info.plist`:**
- `net.daringfireball.markdown` (Owner) — `.md` `.markdown` `.mdown`
- `public.plain-text` (Alternate) — `.txt` and friends

## Rendering pipeline

```
NSTextView typing
  → Coordinator.textDidChange
    → text.wrappedValue = textView.string             [SYNC, immediate]
    → Coordinator.scheduleStyling(...)                [DEBOUNCED 80 ms]
       → SyntaxHighlighter or LiveFormatStyler
         → NSTextStorage attribute swap (begin/endEditing)

document.text changes (via @Binding)
  → DocumentView.onChange
    → RenderState.schedule(text)                      [DEBOUNCED 40 ms]
       → MarkdownRenderer.renderHTML(...)
         → swift-markdown Document → HTMLEmitter MarkupWalker
            → HTML string; text/code htmlEscaped, raw HTML sanitized
              (GitHub-parity allowlist — see HTMLSanitizer.swift)
       → RenderState.html = result                    [SwiftUI invalidates]
    → Outline.extract(text)                           [SYNC, fast]

RenderState.html changes
  → PreviewWebView.updateNSView
    → Coordinator.templateReady ? Inject : Queue
    → Inject: 2 evaluateJavaScript calls
       1. setBody (className swap + innerHTML, each wrapped in try/catch)
       2. KaTeX renderMathInElement + Mermaid.run, terminated with `null;`
```

Two debounce stages keep typing snappy: the highlighter (80 ms) and the preview render (40 ms) both cancel-and-reschedule on every keystroke. The renderer runs Swift-side (testable without WebView) and emits a complete HTML string — no diff / patch — pushed into `<main id="content">` via `innerHTML`.

## Editor — two modes

### Source mode (default)
- `SyntaxHighlighter` walks the swift-markdown AST and applies `NSAttributedString` attributes to the live `NSTextStorage`
- Default font: `AppSettings.editorFontFamily.nsFont(size: settings.editorFontSize)` — Mono, NY Serif, or SF Sans
- Headings scale relative to base size; code gets `secondaryLabelColor`; links get `linkColor`
- Marks (`#`, `**`, etc.) remain fully visible

### Hybrid mode ("Rich" — E1 + E2 only)
- Same NSTextView, different styler: `LiveFormatStyler`
- Heading point sizes `[28, 22, 18, 16, 16, 16]` with bold trait
- Real bold trait on `**bold**`, italic trait on `*italic*`
- Inline code monospaced; code blocks monospaced + secondary color
- Mark delimiters faded to `tertiaryLabelColor` (visible but de-emphasized)
- **E3 cursor-aware fold/reveal is NOT wired** — full `apply()` measured at 8.4 s on a 50 KB doc in W3 spike; would freeze the editor on every cursor move. The `apply(to:cursorAt:)` overload remains in code for v1.1.

## Preview — bundled WebView

`WKWebView` loaded from a local `file://` URL. CSP is `default-src 'none'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:;`. The `'unsafe-inline'` for scripts is required because Mermaid generates inline `<script>` and `<style>` at render time.

**Bundled JS/CSS** (`MDPrintView/Preview/Resources/`):
- `preview.html` template (loaded once; navigation handled in Coordinator)
- `preview.css` — typography + per-theme overrides
- `mermaid.min.js` (Mermaid 11.x)
- `katex.min.js`, `katex.min.css`, `auto-render.min.js` (KaTeX 0.16.x)

KaTeX woff2 fonts are NOT bundled in v1 — math renders with system fallback fonts. v1.1 polish.

**Themes** (Polish.A) are body-class CSS swaps: `body.theme-sepia`, `body.theme-quiet`, `body.theme-focus`. `theme-original` is a no-op (inherits system color-scheme rules).

**Modes** (Screen / Print) are also body-class swaps. `body.print` simulates paper-card layout; `@media print` rules in CSS apply the same styles for actual `Cmd+P` output (WKWebView's `printOperation` runs the page through its own CSS engine).

## Settings persistence

`AppSettings: @Observable @MainActor final class` backed by `@AppStorage` for each property:
- `editorFontSize: Double` (10–24 pt)
- `editorFontFamily: EditorFontFamily` (Mono / Serif / Sans)
- `defaultPageSize: PageSize` (Letter / A4)
- `defaultLayoutMode: LayoutMode` (Editor / Split / Preview)

Single instance lives on `MDPrintViewApp` as `@State`, injected via `.environment(settings)` into both the `DocumentGroup` (per-doc windows) and the `Settings` scene. Mutations from the Settings sheet, View menu, or toolbar all funnel through the same observable — instant fan-out to all open windows.

## Print

`PreviewPrintController: @MainActor @Observable` holds a `weak var webView: WKWebView?` written by `PreviewWebView.makeNSView`. It exposes two methods:

- `printPreview()` — `webView.printOperation(with: NSPrintInfo.shared).runModal(for: window)`
- `exportPDF()` — `NSSavePanel` → `NSPrintInfo` with `.jobDisposition = .save` and `jobSavingURL` → silent print to that URL

Surfaced to the menu bar via `@FocusedValue(\.printPreview)` and `@FocusedValue(\.exportPDF)`. `DocumentView.focusedSceneValue` publishes them; menu items in `MDPrintViewApp.swift` read them. Disabled when no document window is focused.

## Mermaid editor

`MermaidBlock.containing(cursor:in:)` parses the source via swift-markdown, finds a `CodeBlock` with `language == "mermaid"` containing the cursor offset, and returns `(code, fullRange)`. When the toolbar Mermaid item or `Cmd+Shift+M` fires:

- If cursor IS in a mermaid block → set `editor.editingMermaidBlock = block`, sheet appears
- If cursor IS NOT in a mermaid block → insert ` ```mermaid\n…\n``` ` skeleton at cursor first, then sheet

`MermaidEditorSheet` is a SwiftUI `HSplitView` of NSTextView (source) + WKWebView (live render). The preview WebView loads the same `preview.html` template; on each source change it injects a single-mermaid-block document into `#content` and re-runs `mermaid.run`.

## Outline

`Outline.extract(from:) -> [OutlineNode]` walks `Document.children`, picks out `Heading` nodes, and `nest`s by level (h3 becomes a child of the most-recent h2 which is itself a child of an h1, etc.). Rendered by `OutlineSidebar` with `List` + `OutlineGroup`.

Click-to-scroll behavior is NOT wired — selecting an outline row does nothing today. v1.1 polish.

## What lives where (decision rationale)

- **`@MainActor` on everything UI-adjacent.** SwiftUI views, Coordinators, AppSettings, PreviewPrintController, EditorController. The exception: `MarkdownDocument`, which is *not* @MainActor because `NSDocumentController` invokes `init(configuration:)` from a background queue — we hit this as a crash in W1.T8 and removed the annotation.
- **No view-model layer.** The design doc proposed an `EditorViewModel` per window; in practice the per-window UI state (preview mode, theme, editor mode, outline) is a handful of `@State` properties on `DocumentView`, and the cross-window state lives in `AppSettings`. Adding a view-model abstraction added more weight than it removed.
- **Renderer is Swift-side, not JS-side.** Tradeoff: deterministic, unit-testable without a WebView, but we re-implement (a subset of) common markdown render features. The bundled JS only does math + diagrams — both client-side libraries with no equivalent Swift implementation.
- **Two evaluateJavaScript calls, not one.** Splitting setBody from render-pass means a Mermaid or KaTeX failure doesn't leave the preview pane empty. Diagnosed during the empty-preview debugging session — also added `null;` at the end of the render pass so `evaluateJavaScript`'s completion handler stops reporting `WKErrorDomain Code=5` on Mermaid's Promise return.

## Known limitations / v1.1 candidates

See [`docs/STATUS.md`](STATUS.md). Short list:

- Hybrid mode E3 (cursor-aware fold/reveal) — perf cliff, deferred
- In-margin mermaid live preview overlay (design doc Section D) — modal sheet shipped instead
- Editor-side math rendering — preview pane only in v1
- KaTeX woff2 fonts — system fallback in v1
- Outline click-to-scroll — not wired
- Per-document layout preference — currently global via AppSettings
