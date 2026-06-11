# MDPrintView Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build MDPrintView — a native macOS markdown editor + viewer with source/hybrid editing modes and print-quality preview — for Mac App Store distribution on macOS 26.

**Architecture:** SwiftUI `DocumentGroup` shell wrapping a TextKit 2 `NSTextView` editor and a `WKWebView` preview. Markdown parsed and rendered to HTML in Swift (`swift-markdown`); preview is a sandboxed WebView with bundled JS/CSS (Mermaid, KaTeX, DOMPurify). Strict view/view-model/data separation.

**Tech Stack:**
- Swift 6, SwiftUI on macOS 26
- AppKit (`NSViewRepresentable`) for `NSTextView` editor + `HSplitView`
- `swift-markdown` (Apple) — parser and HTML emitter
- `WKWebView` for preview + print
- Bundled: Mermaid, KaTeX, DOMPurify (no network)
- Swift Testing for unit tests; one XCUITest for end-to-end print

**Reference docs:**
- Design: `docs/plans/2026-06-01-MDPrintView-design.md`
- Source inspirations: MDPrintViewer (print CSS), MacDown (editor+preview pattern)

**Axiom skills to invoke at each phase** (load via `Skill` tool before starting tasks that touch the relevant area):
- Project setup: `axiom-app-composition`
- Editor: `axiom-textkit-ref`, `axiom-swiftui-architecture`
- Layout: `axiom-swiftui-layout`
- Visual style: `axiom-liquid-glass`, `axiom-hig`
- Sandbox / file access: `axiom-storage`
- Privacy / MAS: `axiom-privacy-ux`, `axiom-app-store-connect-ref`
- Tests: `axiom-swift-testing`
- Accessibility pass: `axiom-ios-accessibility`

---

## Phasing overview

| Week | Milestone |
|---|---|
| **1** | Project skeleton; open `.md`, edit in left pane, see plain HTML render in right pane, save cleanly. **Detailed below.** |
| **2** | Syntax highlighting, formatting toolbar, outline sidebar, Liquid Glass styling, print-mode CSS, WebView print dialog, PDF export. |
| **3** | Hybrid-mode TextKit 2 spike. Gate: ship in v1 or defer to v1.1. |
| **4** | Mermaid editor (inline skeleton + in-margin preview + expand sheet), KaTeX, settings, accessibility pass. |
| **5** | Privacy manifest, signing/notarization dry-run, MAS internal testing, screenshots, App Store Connect metadata. |

Weeks 2–5 will get their own detailed plans written at the start of each phase. Estimates assume focused part-time work, not 40-hour weeks.

---

# Week 1 — Detailed tasks

## Task 1: Initialize git repo and project metadata

**Files:**
- Create: `/Users/cmagsisi/Dev/MDPrintView/.gitignore`
- Create: `/Users/cmagsisi/Dev/MDPrintView/README.md`

**Step 1: Create `.gitignore` with Xcode + Swift defaults**

```gitignore
# Xcode
build/
DerivedData/
*.xcuserstate
xcuserdata/
*.xcscmblueprint
*.xccheckout
*.dSYM/

# Swift Package Manager
.swiftpm/
.build/

# macOS
.DS_Store

# IDE
.vscode/
.idea/

# Secrets / signing
*.p12
*.cer
ExportOptions.plist
```

**Step 2: Create minimal `README.md`**

```markdown
# MDPrintView

Native macOS markdown editor + viewer with print-quality typography.

Target: macOS 26+. Distribution: Mac App Store.

See `docs/plans/2026-06-01-MDPrintView-design.md` for the design.
```

**Step 3: Init repo and commit**

Run:
```bash
cd /Users/cmagsisi/Dev/MDPrintView
git init -b main
git add .gitignore README.md docs/
git commit -m "init: project skeleton, design docs, gitignore"
```

Expected: clean commit with design doc, implementation doc, README, .gitignore.

---

## Task 2: Create Xcode project (manual — Xcode UI)

**Why manual:** Xcode CLI cannot create new projects. Use the Xcode wizard.

**Step 1: Launch Xcode**

Run: `open -a Xcode`

**Step 2: File → New → Project → macOS → Document App → Next**

**Step 3: Fill in the project wizard:**

| Field | Value |
|---|---|
| Product Name | `MDPrintView` |
| Team | (your team, or "None" for now) |
| Organization Identifier | `net.cmagsisi` (placeholder — to be confirmed before MAS) |
| Bundle Identifier | (auto: `net.cmagsisi.MDPrintView`) |
| Interface | **SwiftUI** |
| Language | **Swift** |
| Document Content Type | `public.plain-text` (we'll add markdown UTIs later) |
| Testing System | **Swift Testing** |
| Storage | **Custom File Format** |
| Include Tests | **checked** |
| Use Core Data | unchecked |

**Step 4: Save into the project directory**

Save location: `/Users/cmagsisi/Dev/MDPrintView`
**Important:** uncheck "Create Git repository" in the save dialog — we already have one.

The resulting tree should be:
```
MDPrintView/
├── MDPrintView.xcodeproj/
├── MDPrintView/                  (sources)
│   ├── MDPrintViewApp.swift
│   ├── ContentView.swift
│   ├── MDPrintViewDocument.swift
│   └── Assets.xcassets/
├── MDPrintViewTests/
└── MDPrintViewUITests/
```

**Step 5: Set deployment target to macOS 26**

In Xcode: project → MDPrintView target → General → Minimum Deployments → macOS = **26.0**.

**Step 6: Build and run**

`Cmd+R` — a blank "Untitled" document window should open. Close it.

**Step 7: Commit**

```bash
cd /Users/cmagsisi/Dev/MDPrintView
git add .
git commit -m "feat: create Xcode SwiftUI Document App project (macOS 26 target)"
```

---

## Task 3: Establish source layout

**Files:**
- Create directories: `MDPrintView/Rendering/`, `MDPrintView/Editor/`, `MDPrintView/Preview/`, `MDPrintView/Models/`, `MDPrintView/Views/`
- Move: `MDPrintViewDocument.swift` → `MDPrintView/Models/MarkdownDocument.swift`
- Move: `ContentView.swift` → `MDPrintView/Views/DocumentView.swift`

**Step 1: Create empty directory placeholders** (Xcode groups follow folder structure; SwiftUI Document template ships a flat layout we want to organize before code grows).

```bash
cd /Users/cmagsisi/Dev/MDPrintView/MDPrintView
mkdir -p Rendering Editor Preview Models Views
```

**Step 2: Move and rename files in Xcode**
- Right-click `MDPrintViewDocument.swift` in Project navigator → New Group from Selection? No — manually drag into `Models` group, rename to `MarkdownDocument.swift`. Update the type name and any `@main` references.
- Drag `ContentView.swift` into `Views`, rename to `DocumentView.swift`. Update references in `MDPrintViewApp.swift`.

**Step 3: Build and run** — `Cmd+R`. Window still opens blank. No regressions.

**Step 4: Commit**

```bash
git add .
git commit -m "refactor: organize source into Models/Views/Editor/Preview/Rendering"
```

---

## Task 4: Add `swift-markdown` package dependency

**Step 1: Xcode → File → Add Package Dependencies**

URL: `https://github.com/apple/swift-markdown.git`
Dependency Rule: **Up to Next Major** from `0.6.0` (or latest stable as of build day).
Add to target: `MDPrintView`.

**Step 2: Verify it resolves**

Run:
```bash
xcodebuild -project /Users/cmagsisi/Dev/MDPrintView/MDPrintView.xcodeproj -list 2>&1 | head -20
```

Expected: lists target `MDPrintView` and scheme `MDPrintView`. No package resolution errors.

**Step 3: Commit**

```bash
git add .
git commit -m "deps: add apple/swift-markdown for parsing + HTML emission"
```

---

## Task 5 (RED): Write failing test for `MarkdownRenderer`

**Files:**
- Create: `MDPrintViewTests/MarkdownRendererTests.swift`

**Step 1: Write the failing test**

```swift
import Testing
@testable import MDPrintView

@Suite("MarkdownRenderer")
struct MarkdownRendererTests {

    @Test("renders a single h1 heading")
    func rendersH1() {
        let renderer = MarkdownRenderer()
        let html = renderer.renderHTML(from: "# Hello")
        #expect(html.contains("<h1"))
        #expect(html.contains(">Hello</h1>"))
    }
}
```

**Step 2: Run tests — expect failure**

Run:
```bash
xcodebuild test -project /Users/cmagsisi/Dev/MDPrintView/MDPrintView.xcodeproj -scheme MDPrintView -destination 'platform=macOS' -only-testing:MDPrintViewTests/MarkdownRendererTests 2>&1 | tail -30
```

Expected: compile error — `MarkdownRenderer` does not exist.

**Step 3: Commit RED**

```bash
git add MDPrintViewTests/MarkdownRendererTests.swift
git commit -m "test(red): MarkdownRenderer renders h1"
```

---

## Task 6 (GREEN): Minimal `MarkdownRenderer` implementation

**Files:**
- Create: `MDPrintView/Rendering/MarkdownRenderer.swift`

**Step 1: Implement just enough to pass**

```swift
import Foundation
import Markdown

struct MarkdownRenderer {
    func renderHTML(from source: String) -> String {
        let document = Document(parsing: source)
        var walker = HTMLEmitter()
        walker.visit(document)
        return walker.output
    }
}

private struct HTMLEmitter: MarkupWalker {
    var output: String = ""

    mutating func visitHeading(_ heading: Heading) {
        output += "<h\(heading.level)>"
        descendInto(heading)
        output += "</h\(heading.level)>"
    }

    mutating func visitText(_ text: Text) {
        output += text.string
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        output += "<p>"
        descendInto(paragraph)
        output += "</p>"
    }
}
```

**Step 2: Run tests — expect pass**

Run:
```bash
xcodebuild test -project /Users/cmagsisi/Dev/MDPrintView/MDPrintView.xcodeproj -scheme MDPrintView -destination 'platform=macOS' -only-testing:MDPrintViewTests/MarkdownRendererTests 2>&1 | tail -10
```

Expected: `Test Suite 'MarkdownRendererTests' passed`.

**Step 3: Commit GREEN**

```bash
git add MDPrintView/Rendering/MarkdownRenderer.swift
git commit -m "feat(green): MarkdownRenderer h1 via swift-markdown"
```

---

## Task 7: Expand renderer test coverage (RED → GREEN, then commit)

**Files:**
- Modify: `MDPrintViewTests/MarkdownRendererTests.swift`
- Modify: `MDPrintView/Rendering/MarkdownRenderer.swift`

**Step 1: Add failing tests for paragraphs, lists, emphasis, code, links**

```swift
@Test("renders a paragraph")
func rendersParagraph() {
    #expect(MarkdownRenderer().renderHTML(from: "hello").contains("<p>hello</p>"))
}

@Test("renders bullet list")
func rendersBulletList() {
    let html = MarkdownRenderer().renderHTML(from: "- a\n- b")
    #expect(html.contains("<ul>"))
    #expect(html.contains("<li>a</li>"))
    #expect(html.contains("<li>b</li>"))
}

@Test("renders inline emphasis and strong")
func rendersEmphasis() {
    let html = MarkdownRenderer().renderHTML(from: "*em* **strong**")
    #expect(html.contains("<em>em</em>"))
    #expect(html.contains("<strong>strong</strong>"))
}

@Test("renders inline code and code block")
func rendersCode() {
    #expect(MarkdownRenderer().renderHTML(from: "`x`").contains("<code>x</code>"))
    #expect(MarkdownRenderer().renderHTML(from: "```\nx\n```").contains("<pre><code>"))
}

@Test("renders link")
func rendersLink() {
    let html = MarkdownRenderer().renderHTML(from: "[a](https://b)")
    #expect(html.contains("<a href=\"https://b\">a</a>"))
}
```

**Step 2: Run — expect failures.** Verify each fails with a meaningful diff.

**Step 3: Extend `HTMLEmitter` to handle each node type.** Add `visitUnorderedList`, `visitListItem`, `visitEmphasis`, `visitStrong`, `visitInlineCode`, `visitCodeBlock`, `visitLink`.

**Step 4: Run — expect pass.**

**Step 5: Commit.**

```bash
git add .
git commit -m "feat: renderer covers paragraphs, lists, emphasis, code, links"
```

---

## Task 8: Register markdown UTIs

**Files:**
- Modify: `MDPrintView/Info.plist` (or "Custom macOS Application Target Properties" in Xcode target Info pane)
- Modify: `MDPrintView/Models/MarkdownDocument.swift`

**Step 1: Declare Imported Type Identifier in target's Info pane**

| Field | Value |
|---|---|
| Identifier | `net.daringfireball.markdown` |
| Conforms To | `public.plain-text` |
| Extensions | `md, markdown, mdown` |
| MIME Type | `text/markdown` |

**Step 2: Declare a Document Type entry**

| Field | Value |
|---|---|
| Name | `Markdown Document` |
| Identifier | `net.daringfireball.markdown` |
| Role | `Editor` |

**Step 3: Update `MarkdownDocument`**

```swift
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let markdown = UTType(importedAs: "net.daringfireball.markdown")
}

@Observable
final class MarkdownDocument: ReferenceFileDocument {
    typealias Snapshot = String
    static var readableContentTypes: [UTType] { [.markdown, .plainText] }
    static var writableContentTypes: [UTType] { [.markdown, .plainText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = string
    }

    func snapshot(contentType: UTType) throws -> String { text }

    func fileWrapper(snapshot: String, configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(snapshot.utf8))
    }
}
```

**Step 4: Update `MDPrintViewApp.swift`** to use `DocumentGroup(newDocument: { MarkdownDocument() }) { file in DocumentView(document: file.document) }`.

**Step 5: Build, run, drag a `.md` file onto the dock icon** — expect a window to open containing the file's text in whatever placeholder UI exists.

**Step 6: Commit.**

```bash
git add .
git commit -m "feat: register .md/.markdown UTI and ReferenceFileDocument"
```

---

## Task 9: Minimal `MarkdownTextView` (NSTextView wrapper)

**Files:**
- Create: `MDPrintView/Editor/MarkdownTextView.swift`
- Modify: `MDPrintView/Views/DocumentView.swift`

**Step 1: Implement bare-bones representable** (no syntax highlighting yet)

```swift
import SwiftUI
import AppKit

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let tv = scroll.documentView as! NSTextView
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.allowsUndo = true
        tv.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        tv.string = text
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let tv = scroll.documentView as! NSTextView
        if tv.string != text { tv.string = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            text.wrappedValue = tv.string
        }
    }
}
```

**Step 2: Wire into `DocumentView`**

```swift
struct DocumentView: View {
    @Bindable var document: MarkdownDocument
    var body: some View {
        MarkdownTextView(text: $document.text)
            .frame(minWidth: 480, minHeight: 320)
    }
}
```

**Step 3: Build, run, open a `.md` file** — type, save (`Cmd+S`), close, reopen. Content persists.

**Step 4: Commit.**

```bash
git add .
git commit -m "feat: MarkdownTextView wraps NSTextView with two-way text binding"
```

---

## Task 10: `PreviewWebView` with bundled CSS

**Files:**
- Create: `MDPrintView/Preview/PreviewWebView.swift`
- Create: `MDPrintView/Preview/Resources/preview.html`
- Create: `MDPrintView/Preview/Resources/preview.css` (start with MDPrintViewer's CSS as a base — adapt)
- Add `preview.html` and `preview.css` to target as bundled resources.

**Step 1: Create `preview.html`** (loaded once; JS replaces `<main>` body)

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'self' 'unsafe-inline'; script-src 'self';">
  <link rel="stylesheet" href="preview.css">
</head>
<body class="screen">
  <main id="content"></main>
  <script>
    function setBody(html) {
      document.getElementById('content').innerHTML = html;
    }
  </script>
</body>
</html>
```

**Step 2: Create initial `preview.css`** — minimal serif body, headings, code, lists. Borrow structure from MDPrintViewer's CSS (MIT licensed, attribute in README).

**Step 3: Implement `PreviewWebView`**

```swift
import SwiftUI
import WebKit

struct PreviewWebView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        loadTemplate(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let escaped = html
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        let js = "setBody(`\(escaped)`);"
        webView.evaluateJavaScript(js)
    }

    private func loadTemplate(in webView: WKWebView) {
        guard let url = Bundle.main.url(forResource: "preview", withExtension: "html") else { return }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
}
```

**Step 4: Update `DocumentView`** to compute HTML and render preview alongside editor:

```swift
struct DocumentView: View {
    @Bindable var document: MarkdownDocument
    private let renderer = MarkdownRenderer()

    var body: some View {
        HSplitView {
            MarkdownTextView(text: $document.text)
                .frame(minWidth: 320)
            PreviewWebView(html: renderer.renderHTML(from: document.text))
                .frame(minWidth: 320)
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}
```

**Step 5: Build, run, open a `.md` file** — left pane editor, right pane rendered preview that updates as you type.

**Step 6: Commit.**

```bash
git add .
git commit -m "feat: PreviewWebView with bundled CSS, side-by-side editor+preview"
```

---

## Task 11: Debounce + scroll-preserving updates

**Files:**
- Modify: `MDPrintView/Views/DocumentView.swift`

**Step 1: Wrap the HTML computation in an 80ms debounce.**

The simplest approach: introduce a small `@Observable` `RenderState` that holds `currentHTML`, and a `Task` triggered by text changes that sleeps 80ms then publishes. Cancel the prior task on each keystroke.

Sketch:

```swift
@Observable
final class RenderState {
    var html: String = ""
    private var task: Task<Void, Never>?
    private let renderer = MarkdownRenderer()

    func schedule(_ source: String) {
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            self.html = renderer.renderHTML(from: source)
        }
    }
}
```

Wire into `DocumentView`:

```swift
@State private var render = RenderState()
// .onChange(of: document.text) { _, new in render.schedule(new) }
// PreviewWebView(html: render.html)
```

**Step 2: Verify** — rapid typing doesn't lag the editor. Preview catches up after ~80ms idle.

**Step 3: Commit.**

```bash
git add .
git commit -m "perf: 80ms debounce on preview render to keep editor responsive"
```

---

## Week 1 milestone

After Tasks 1–11:
- ✅ Project skeleton in git
- ✅ Xcode project building and launching on macOS 26
- ✅ `swift-markdown`-based Swift HTML renderer, unit-tested for h1/p/list/emphasis/code/link
- ✅ Markdown UTI registered, double-clicking a `.md` opens the app
- ✅ NSTextView editor with two-way binding
- ✅ WKWebView preview with bundled CSS and CSP
- ✅ Side-by-side layout via `HSplitView`
- ✅ 80ms debounce keeps editor smooth

This is enough to use the app as a basic markdown viewer-editor right away.

---

# Week 2 — Outline (detail later)

1. Syntax highlighting on the source editor (apply `NSAttributedString` attributes from a swift-markdown token walk).
2. Formatting toolbar above the editor: Bold / Italic / Strike / H1-3 / lists / code / link.
3. Outline sidebar (`List` + `OutlineGroup` from headings).
4. Liquid Glass styling on toolbar + sidebar (`axiom-liquid-glass`).
5. Print-mode CSS (page breaks, `@page` rules, paper-size class on `<body>`).
6. WebView `print(_:)` integration, PDF export via `Cmd+Shift+E`.
7. Tests: toolbar action → markdown text mutation (`EditorViewModelTests`).
8. UI test: open sample → toggle screen/print → print to PDF → verify PDF text content.

---

# Week 3 — Hybrid mode spike (gate)

Goal: prove cursor-aware syntax-folding is feasible in TextKit 2 on real docs.

1. `LiveFormatStyler` type — input doc + cursor → attribute ranges.
2. `NSTextLayoutManager` delegate that hides/reveals syntax marks based on selection.
3. Unit tests on `LiveFormatStyler` with diverse fixtures (nested emphasis, headings, list items, mixed inline).
4. Manual test on 5 real markdown docs (varying lengths up to 10KB).
5. **Decision point at end of week:** ship in v1, or defer to v1.1?

---

# Week 4 — Mermaid + KaTeX + settings + a11y

1. Bundle `mermaid.min.js` and `katex.min.js` + KaTeX CSS as resources.
2. Preview-side: after `setBody`, scan and render mermaid blocks and `$...$`/`$$...$$` spans.
3. Editor mermaid UX: detect cursor inside ` ```mermaid ` fence → show in-margin live preview overlay. Click overlay or `Cmd+Shift+M` → modal mermaid editor sheet (split: NSTextView source + WKWebView render).
4. `Settings` scene with `AppSettings` (`@AppStorage`): default font size, default theme (light/dark/auto), default page size (Letter/A4).
5. Accessibility pass: VoiceOver labels on every toolbar button, outline navigation, dynamic-type-style font scaling. (`axiom-ios-accessibility` patterns.)

---

# Week 5 — MAS submission readiness

1. `PrivacyInfo.xcprivacy` with no tracking, no data collection, declared Required Reasons.
2. Sandbox entitlements: `app-sandbox`, `files.user-selected.read-write`, `files.bookmarks.app-scope`.
3. **No network entitlement** — verify build runs offline.
4. App Icon + marketing screenshots (5 required for MAS).
5. Sign with Apple Developer ID, notarize, validate via `xcrun stapler validate`.
6. App Store Connect listing: name, description, keywords, support URL, privacy policy URL.
7. Submit for review.

---

## Execution handoff

Per the writing-plans skill: two ways to execute.

**1. Subagent-Driven (this session)** — dispatch fresh subagent per task, review between tasks, fast iteration.

**2. Parallel Session (separate)** — open new session with `superpowers:executing-plans`, batch execution with checkpoints.

Recommend **option 1** for this project since several Week 1 tasks (Task 2 = Xcode wizard, Task 8 = Info.plist Target panel) require interactive Xcode UI that's easier to coordinate in one session.
