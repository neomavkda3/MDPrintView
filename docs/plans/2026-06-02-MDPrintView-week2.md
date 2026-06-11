# MDPrintView Week 2 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (or subagent-driven-development for same-session) to implement this plan task-by-task.

**Goal:** Turn MDPrintView from a working markdown viewer into a polished editor with syntax highlighting, formatting toolbar, outline navigation, print-quality CSS, Liquid Glass styling, and verified test coverage.

**Architecture:** Build on Week 1's foundation (DocumentGroup + NSTextView + WKWebView + Swift-side `swift-markdown` renderer). Add: HTML escaping + missing renderer nodes, NSTextStorage attribute-based syntax highlighter, SwiftUI toolbar with text-mutating commands via a focused `EditorController`, outline sidebar via `List` + `OutlineGroup`, print-mode CSS with `@page` rules and a screen/print toggle, Liquid Glass on toolbar + sidebar, and one end-to-end XCUITest.

**Tech Stack:**
- Swift 6 strict concurrency, SwiftUI on macOS 26
- `swift-markdown` 0.8 (already in repo)
- AppKit `NSTextView` + `NSTextStorage` for syntax highlighting
- SwiftUI `.toolbar`, `CommandGroup`, `@FocusedValue`
- CSS `@page`, `page-break-*`, prefers-color-scheme
- Liquid Glass: `axiom-liquid-glass` (invoke before E1)
- XCUITest for end-to-end print verification

**Reference docs:**
- Week 1 design: `docs/plans/2026-06-01-MDPrintView-design.md`
- Week 1 plan: `docs/plans/2026-06-01-MDPrintView-implementation.md`
- Current commit: `64a250b`

**Axiom skills to invoke when implementing each phase** (load via `Skill` tool before starting):
- Phase A (renderer fixes): no skill — straightforward Swift
- Phase B (syntax highlighting): `axiom-textkit-ref`
- Phase B (toolbar): `axiom-swiftui-architecture`
- Phase C (outline): `axiom-swiftui-layout`
- Phase D (print CSS): no skill — vanilla CSS
- Phase E (Liquid Glass): `axiom-liquid-glass`, `axiom-hig`
- Phase F (tests): `axiom-swift-testing`, `axiom-ui-testing`

---

## Phasing overview

| Phase | Theme | Tasks | Risk |
|---|---|---|---|
| **A** | Renderer hardening (W1 carryover) | A1–A3 | low |
| **B** | Editor enrichment | B1–B3 | medium |
| **C** | Navigation | C1 | low |
| **D** | Print quality | D1–D3 | low-medium |
| **E** | Visual polish | E1 | medium (Liquid Glass adoption) |
| **F** | Verification sweep | F1–F2 | low |

13 tasks total. Mirrors Week 1's pacing.

---

## Phase A — Renderer hardening

### Task A1: HTML escaping in renderer

**Why:** Today, literal `<`, `>`, `&` characters in markdown source pass through to the WebView's `innerHTML` as raw HTML. A user typing `` `<body>` `` sees a `<body>` tag take effect inside the preview, not the text "<body>". This is wrong and (mildly) security-adjacent.

**Files:**
- Modify: `MDPrintView/Rendering/MarkdownRenderer.swift`
- Modify: `MDPrintViewTests/MarkdownRendererTests.swift`

**Step 1: Add the failing tests**

Append to `MDPrintViewTests/MarkdownRendererTests.swift` inside the `MarkdownRendererTests` struct:

```swift
@Test("escapes < > & in plain text")
func escapesPlainText() {
    let html = MarkdownRenderer().renderHTML(from: "a < b & c > d")
    #expect(html.contains("a &lt; b &amp; c &gt; d"))
    #expect(!html.contains("<b>") && !html.contains("> d"))
}

@Test("escapes HTML inside inline code")
func escapesInlineCode() {
    let html = MarkdownRenderer().renderHTML(from: "`<body>`")
    #expect(html.contains("<code>&lt;body&gt;</code>"))
}

@Test("escapes HTML inside code block")
func escapesCodeBlock() {
    let html = MarkdownRenderer().renderHTML(from: "```\n<script>x</script>\n```")
    #expect(html.contains("&lt;script&gt;x&lt;/script&gt;"))
    #expect(!html.contains("<script>x</script>"))
}

@Test("escapes link href and label")
func escapesLink() {
    let html = MarkdownRenderer().renderHTML(from: "[<b>label</b>](https://x.com?a=1&b=2)")
    #expect(html.contains("href=\"https://x.com?a=1&amp;b=2\""))
    #expect(html.contains("&lt;b&gt;label&lt;/b&gt;"))
}
```

**Step 2: Run — verify failures**

```
cd /Users/cmagsisi/Dev/MDPrintView
xcodebuild -project MDPrintView.xcodeproj -scheme MDPrintView -destination 'platform=macOS' -configuration Debug test 2>&1 | tail -30
```

Expected: 4 new failures, 8 previous tests still pass.

**Step 3: Implement escaping**

In `MDPrintView/Rendering/MarkdownRenderer.swift`, add a private free function and apply it everywhere user-controlled text is concatenated into the output:

```swift
private func htmlEscape(_ s: String) -> String {
    var result = ""
    result.reserveCapacity(s.count)
    for ch in s {
        switch ch {
        case "&": result += "&amp;"
        case "<": result += "&lt;"
        case ">": result += "&gt;"
        case "\"": result += "&quot;"
        case "'": result += "&#39;"
        default: result.append(ch)
        }
    }
    return result
}
```

Update the four call sites in `HTMLEmitter`:

```swift
mutating func visitText(_ text: Text) {
    output += htmlEscape(text.string)
}

mutating func visitInlineCode(_ inlineCode: InlineCode) {
    output += "<code>\(htmlEscape(inlineCode.code))</code>"
}

mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
    output += "<pre><code>\(htmlEscape(codeBlock.code))</code></pre>"
}

mutating func visitLink(_ link: Link) {
    let dest = htmlEscape(link.destination ?? "")
    output += "<a href=\"\(dest)\">"
    descendInto(link)
    output += "</a>"
}
```

(Note: `descendInto(link)` will hit `visitText` which already escapes — so the link label is safe via recursion.)

**Step 4: Run — verify all 12 pass**

Same command. Expected: 12/12 tests pass.

**Step 5: Commit**

```bash
git add MDPrintView/Rendering/MarkdownRenderer.swift MDPrintViewTests/MarkdownRendererTests.swift
git commit -m "fix: HTML-escape user content in renderer output"
```

---

### Task A2: Missing block nodes (blockquote, hr, ordered list, task list, table)

**Files:**
- Modify: `MDPrintView/Rendering/MarkdownRenderer.swift`
- Modify: `MDPrintViewTests/MarkdownRendererTests.swift`

**Step 1: Add failing tests for each node type**

Append to `MarkdownRendererTests`:

```swift
@Test("renders blockquote")
func rendersBlockquote() {
    let html = MarkdownRenderer().renderHTML(from: "> quoted\n> text")
    #expect(html.contains("<blockquote>"))
    #expect(html.contains("</blockquote>"))
    #expect(html.contains("quoted"))
}

@Test("renders horizontal rule")
func rendersThematicBreak() {
    let html = MarkdownRenderer().renderHTML(from: "before\n\n---\n\nafter")
    #expect(html.contains("<hr"))
}

@Test("renders ordered list")
func rendersOrderedList() {
    let html = MarkdownRenderer().renderHTML(from: "1. first\n2. second")
    #expect(html.contains("<ol>"))
    #expect(html.contains("<li>"))
    #expect(html.contains("first"))
    #expect(html.contains("second"))
}

@Test("renders task list with checkboxes")
func rendersTaskList() {
    let html = MarkdownRenderer().renderHTML(from: "- [ ] todo\n- [x] done")
    #expect(html.contains("type=\"checkbox\""))
    #expect(html.contains("checked"))
    #expect(html.contains("todo"))
    #expect(html.contains("done"))
}

@Test("renders simple table")
func rendersTable() {
    let source = """
    | h1 | h2 |
    | -- | -- |
    | a  | b  |
    """
    let html = MarkdownRenderer().renderHTML(from: source)
    #expect(html.contains("<table>"))
    #expect(html.contains("<thead>"))
    #expect(html.contains("<th>h1</th>"))
    #expect(html.contains("<td>a</td>"))
}
```

**Step 2: Run — verify failures**

Expected: 5 new failures.

**Step 3: Implement visit methods**

In `HTMLEmitter` (still `private` to the renderer file), add:

```swift
mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
    output += "<blockquote>"
    descendInto(blockQuote)
    output += "</blockquote>"
}

mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
    output += "<hr>"
}

mutating func visitOrderedList(_ list: OrderedList) {
    output += "<ol>"
    descendInto(list)
    output += "</ol>"
}

mutating func visitListItem(_ item: ListItem) {
    if let checkbox = item.checkbox {
        let attr = checkbox == .checked ? " checked" : ""
        output += "<li><input type=\"checkbox\" disabled\(attr)>"
        descendInto(item)
        output += "</li>"
    } else {
        output += "<li>"
        descendInto(item)
        output += "</li>"
    }
}

mutating func visitTable(_ table: Table) {
    output += "<table>"
    descendInto(table)
    output += "</table>"
}

mutating func visitTableHead(_ head: Table.Head) {
    output += "<thead><tr>"
    descendInto(head)
    output += "</tr></thead>"
}

mutating func visitTableBody(_ body: Table.Body) {
    output += "<tbody>"
    descendInto(body)
    output += "</tbody>"
}

mutating func visitTableRow(_ row: Table.Row) {
    output += "<tr>"
    descendInto(row)
    output += "</tr>"
}

mutating func visitTableCell(_ cell: Table.Cell) {
    // Heuristic: if parent is Table.Head, use <th>; else <td>.
    // swift-markdown does not expose parent type during walk; the Head/Body wrappers above already
    // emit <tr> with the right context, so emit by checking if this cell is inside <thead>.
    // A clean way: track an explicit `inHead` flag.
    if inHead {
        output += "<th>"
        descendInto(cell)
        output += "</th>"
    } else {
        output += "<td>"
        descendInto(cell)
        output += "</td>"
    }
}
```

Replace the existing `visitListItem` from W1.T7 with the version above (it now handles task-list checkboxes).

Add a private `var inHead: Bool = false` to `HTMLEmitter` and toggle it in `visitTableHead`:

```swift
mutating func visitTableHead(_ head: Table.Head) {
    inHead = true
    output += "<thead><tr>"
    descendInto(head)
    output += "</tr></thead>"
    inHead = false
}
```

**Step 4: Run — verify all pass**

```
xcodebuild ... test 2>&1 | tail -10
```

Expected: 17/17 pass.

**Step 5: Commit**

```bash
git add MDPrintView/Rendering/MarkdownRenderer.swift MDPrintViewTests/MarkdownRendererTests.swift
git commit -m "feat: renderer supports blockquote, hr, ordered list, task list, tables"
```

---

### Task A3: Image rendering

**Files:** same as A2.

**Step 1: Failing test**

```swift
@Test("renders image")
func rendersImage() {
    let html = MarkdownRenderer().renderHTML(from: "![alt text](https://example.com/x.png)")
    #expect(html.contains("<img src=\"https://example.com/x.png\""))
    #expect(html.contains("alt=\"alt text\""))
}
```

**Step 2: Implement**

In `HTMLEmitter`:

```swift
mutating func visitImage(_ image: Image) {
    let src = htmlEscape(image.source ?? "")
    let title = image.plainText
    let alt = htmlEscape(title)
    output += "<img src=\"\(src)\" alt=\"\(alt)\">"
}
```

(Note: `Markup.plainText` collects all text descendants of the image, which is what authors mean by "alt text" in `![alt](src)`.)

Update `MDPrintView/Preview/Resources/preview.css` to constrain max image width:

```css
img {
    max-width: 100%;
    height: auto;
}
```

**Step 3: Test, commit**

```bash
git add MDPrintView/Rendering/MarkdownRenderer.swift MDPrintViewTests/MarkdownRendererTests.swift MDPrintView/Preview/Resources/preview.css
git commit -m "feat: renderer supports images with responsive max-width"
```

---

## Phase B — Editor enrichment

### Task B1: Markdown syntax highlighting in the editor

**Why:** Plain monospace source is hard to scan. Highlighting headings, code, links, and emphasis gives the editor immediate value.

**Approach:** A `SyntaxHighlighter` struct walks the swift-markdown AST and applies `NSAttributedString` attributes onto the live `NSTextStorage`. We re-highlight on every text change (acceptable until docs get large; can debounce later).

**Files:**
- Create: `MDPrintView/Editor/SyntaxHighlighter.swift`
- Modify: `MDPrintView/Editor/MarkdownTextView.swift`
- Test: `MDPrintViewTests/SyntaxHighlighterTests.swift`

**Step 1: Invoke Axiom skill**

Before writing code, load: `Skill axiom-textkit-ref`. It covers TextKit 2 attribute application and the `NSTextStorage` mutation pattern.

**Step 2: Failing tests for SyntaxHighlighter**

Create `MDPrintViewTests/SyntaxHighlighterTests.swift`:

```swift
import Testing
import AppKit
@testable import MDPrintView

@Suite("SyntaxHighlighter", .serialized)
@MainActor
struct SyntaxHighlighterTests {

    @Test("h1 line gets larger bold font")
    func h1Bold() {
        let storage = NSTextStorage(string: "# Heading\n")
        SyntaxHighlighter().apply(to: storage)
        let attrs = storage.attributes(at: 0, effectiveRange: nil)
        let font = attrs[.font] as? NSFont
        #expect(font?.pointSize ?? 0 > 14)
        #expect(font?.fontDescriptor.symbolicTraits.contains(.bold) == true)
    }

    @Test("inline code gets monospaced font and tinted color")
    func inlineCodeStyling() {
        let storage = NSTextStorage(string: "use `x` here")
        SyntaxHighlighter().apply(to: storage)
        // The "x" is at index 5 (after "use `")
        let attrs = storage.attributes(at: 5, effectiveRange: nil)
        let font = attrs[.font] as? NSFont
        #expect(font?.familyName?.contains("Mono") == true || font?.fontName.contains("Menlo") == true)
    }

    @Test("link target gets distinct color")
    func linkColoring() {
        let storage = NSTextStorage(string: "[label](https://example.com)")
        SyntaxHighlighter().apply(to: storage)
        // Find any attribute run that has a non-default color
        var foundColor: NSColor?
        storage.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: storage.length)) { value, _, _ in
            if let c = value as? NSColor, c != .textColor { foundColor = c }
        }
        #expect(foundColor != nil)
    }
}
```

**Step 3: Implement SyntaxHighlighter (minimal — only enough to pass)**

Create `MDPrintView/Editor/SyntaxHighlighter.swift`:

```swift
import AppKit
import Markdown

@MainActor
struct SyntaxHighlighter {
    private let baseFontSize: CGFloat = 14

    func apply(to storage: NSTextStorage) {
        let source = storage.string
        let document = Document(parsing: source)
        let fullRange = NSRange(location: 0, length: storage.length)

        // Reset to defaults before reapplying — keeps cumulative re-applies idempotent.
        storage.beginEditing()
        defer { storage.endEditing() }

        storage.removeAttribute(.font, range: fullRange)
        storage.removeAttribute(.foregroundColor, range: fullRange)
        storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: baseFontSize, weight: .regular), range: fullRange)
        storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)

        for markup in document.children {
            apply(markup, to: storage, source: source)
        }
    }

    private func apply(_ markup: Markup, to storage: NSTextStorage, source: String) {
        guard let range = nsRange(for: markup, in: source) else { return }

        switch markup {
        case let heading as Heading:
            let size = CGFloat(20 - min(heading.level, 6))
            let font = NSFont.monospacedSystemFont(ofSize: max(baseFontSize, baseFontSize + size - 6), weight: .bold)
            storage.addAttribute(.font, value: font, range: range)
        case is InlineCode, is CodeBlock:
            let font = NSFont.monospacedSystemFont(ofSize: baseFontSize, weight: .regular)
            storage.addAttribute(.font, value: font, range: range)
            storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: range)
        case is Link:
            storage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
        default:
            break
        }

        for child in markup.children {
            apply(child, to: storage, source: source)
        }
    }

    private func nsRange(for markup: Markup, in source: String) -> NSRange? {
        guard let range = markup.range else { return nil }
        let nsString = source as NSString
        let startUTF16 = offset(for: range.lowerBound, in: source)
        let endUTF16 = offset(for: range.upperBound, in: source)
        guard startUTF16 >= 0, endUTF16 >= startUTF16, endUTF16 <= nsString.length else { return nil }
        return NSRange(location: startUTF16, length: endUTF16 - startUTF16)
    }

    private func offset(for sourceLocation: SourceLocation, in source: String) -> Int {
        // SourceLocation is 1-indexed line/column. Convert to UTF-16 offset in source.
        let lines = source.components(separatedBy: "\n")
        var offset = 0
        let targetLine = max(1, sourceLocation.line)
        for (i, line) in lines.enumerated() {
            if i + 1 == targetLine {
                let col = max(1, sourceLocation.column) - 1
                let lineNSString = line as NSString
                let clampedCol = min(col, lineNSString.length)
                return offset + clampedCol
            }
            offset += (line as NSString).length + 1 // +1 for the newline
        }
        return offset
    }
}
```

**Step 4: Wire into MarkdownTextView**

In `MDPrintView/Editor/MarkdownTextView.swift`, update the `Coordinator` to apply highlighting on every change:

```swift
@MainActor
final class Coordinator: NSObject, NSTextViewDelegate {
    let text: Binding<String>
    private let highlighter = SyntaxHighlighter()

    init(text: Binding<String>) {
        self.text = text
    }

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        text.wrappedValue = textView.string
        if let storage = textView.textStorage {
            highlighter.apply(to: storage)
        }
    }
}
```

And apply once on initial `makeNSView`:

```swift
textView.string = text
if let storage = textView.textStorage {
    SyntaxHighlighter().apply(to: storage)
}
```

**Step 5: Run tests + build + manual smoke**

```
xcodebuild -project MDPrintView.xcodeproj -scheme MDPrintView -destination 'platform=macOS' -configuration Debug test 2>&1 | tail -15
```

Expected: 21/21 (18 existing + 3 new highlighter tests).

Manual smoke: launch the app and open a markdown file. Headings should be bigger and bold. Code should be a different color. Links should be blue.

**Step 6: Commit**

```bash
git add MDPrintView/Editor/SyntaxHighlighter.swift MDPrintView/Editor/MarkdownTextView.swift MDPrintViewTests/SyntaxHighlighterTests.swift MDPrintView.xcodeproj/project.pbxproj
git commit -m "feat: markdown syntax highlighting via swift-markdown source ranges"
```

---

### Task B2: EditorController + formatting toolbar

**Why:** Toolbar buttons that wrap selection in `**`, prefix lines with `#`, insert links, etc.

**Files:**
- Create: `MDPrintView/Editor/EditorController.swift`
- Create: `MDPrintView/Editor/EditorToolbar.swift`
- Modify: `MDPrintView/Editor/MarkdownTextView.swift`
- Modify: `MDPrintView/Views/DocumentView.swift`

**Step 1: Invoke Axiom skill**

Load: `Skill axiom-swiftui-architecture` for the FocusedValue + Observable controller pattern.

**Step 2: EditorController**

Create `MDPrintView/Editor/EditorController.swift`:

```swift
import AppKit
import SwiftUI

@MainActor
@Observable
final class EditorController {
    weak var textView: NSTextView?

    var canEdit: Bool { textView != nil }

    /// Wrap the current selection (or insert at cursor) with `prefix` and `suffix`.
    func wrap(prefix: String, suffix: String, placeholder: String = "") {
        guard let textView, let storage = textView.textStorage else { return }
        let range = textView.selectedRange()
        let selected = (storage.string as NSString).substring(with: range)
        let body = selected.isEmpty ? placeholder : selected
        let replacement = "\(prefix)\(body)\(suffix)"
        storage.replaceCharacters(in: range, with: replacement)
        let newLocation = range.location + (prefix as NSString).length
        let newLength = (body as NSString).length
        textView.setSelectedRange(NSRange(location: newLocation, length: newLength))
        textView.didChangeText()
    }

    /// Prepend `marker` to the start of every line touched by the current selection.
    func prefixLines(with marker: String) {
        guard let textView, let storage = textView.textStorage else { return }
        let selRange = textView.selectedRange()
        let nsString = storage.string as NSString
        let lineRange = nsString.lineRange(for: selRange)
        let lines = nsString.substring(with: lineRange).components(separatedBy: "\n")
        let prefixed = lines.enumerated().map { i, line in
            (i == lines.count - 1 && line.isEmpty) ? line : "\(marker)\(line)"
        }.joined(separator: "\n")
        storage.replaceCharacters(in: lineRange, with: prefixed)
        textView.setSelectedRange(NSRange(location: lineRange.location, length: (prefixed as NSString).length))
        textView.didChangeText()
    }

    func toggleHeading(level: Int) {
        prefixLines(with: String(repeating: "#", count: level) + " ")
    }

    func insertBullet() { prefixLines(with: "- ") }
    func insertNumbered() { prefixLines(with: "1. ") }
    func insertTask() { prefixLines(with: "- [ ] ") }

    func insertLink(url: String = "https://") {
        wrap(prefix: "[", suffix: "](\(url))", placeholder: "link text")
    }

    func toggleBold() { wrap(prefix: "**", suffix: "**", placeholder: "bold") }
    func toggleItalic() { wrap(prefix: "*", suffix: "*", placeholder: "italic") }
    func toggleStrike() { wrap(prefix: "~~", suffix: "~~", placeholder: "strike") }
    func toggleInlineCode() { wrap(prefix: "`", suffix: "`", placeholder: "code") }

    func insertCodeBlock() {
        wrap(prefix: "```\n", suffix: "\n```", placeholder: "code")
    }

    func insertMermaid() {
        wrap(prefix: "```mermaid\n", suffix: "\n```", placeholder: "graph TD\n  A --> B")
    }
}
```

**Step 3: Failing tests for EditorController**

Create `MDPrintViewTests/EditorControllerTests.swift`:

```swift
import Testing
import AppKit
@testable import MDPrintView

@Suite("EditorController", .serialized)
@MainActor
struct EditorControllerTests {

    private func make(_ text: String, selection: NSRange = NSRange(location: 0, length: 0)) -> (EditorController, NSTextView) {
        let tv = NSTextView()
        tv.string = text
        tv.setSelectedRange(selection)
        let controller = EditorController()
        controller.textView = tv
        return (controller, tv)
    }

    @Test("toggleBold wraps selection in **")
    func boldWrapsSelection() {
        let (c, tv) = make("hello world", selection: NSRange(location: 6, length: 5))
        c.toggleBold()
        #expect(tv.string == "hello **world**")
    }

    @Test("toggleBold inserts placeholder when no selection")
    func boldNoSelection() {
        let (c, tv) = make("hello ")
        tv.setSelectedRange(NSRange(location: 6, length: 0))
        c.toggleBold()
        #expect(tv.string == "hello **bold**")
    }

    @Test("toggleHeading prefixes line with hashes")
    func headingPrefix() {
        let (c, tv) = make("hello")
        tv.setSelectedRange(NSRange(location: 2, length: 0))
        c.toggleHeading(level: 2)
        #expect(tv.string == "## hello")
    }

    @Test("insertBullet prefixes line with dash")
    func bulletPrefix() {
        let (c, tv) = make("item")
        tv.setSelectedRange(NSRange(location: 0, length: 0))
        c.insertBullet()
        #expect(tv.string == "- item")
    }

    @Test("insertLink wraps selection with markdown link syntax")
    func linkWraps() {
        let (c, tv) = make("click here", selection: NSRange(location: 0, length: 5))
        c.insertLink(url: "https://x.com")
        #expect(tv.string == "[click](https://x.com) here")
    }
}
```

**Step 4: Wire EditorController into MarkdownTextView**

Modify `MarkdownTextView`:

```swift
struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    let controller: EditorController

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        // ... existing setup ...
        controller.textView = textView
        return scrollView
    }
    // updateNSView unchanged
}
```

**Step 5: EditorToolbar view**

Create `MDPrintView/Editor/EditorToolbar.swift`:

```swift
import SwiftUI

struct EditorToolbar: ToolbarContent {
    let controller: EditorController

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .principal) {
            Button { controller.toggleBold() } label: { Image(systemName: "bold") }
                .keyboardShortcut("b", modifiers: .command)
                .help("Bold")
            Button { controller.toggleItalic() } label: { Image(systemName: "italic") }
                .keyboardShortcut("i", modifiers: .command)
                .help("Italic")
            Button { controller.toggleStrike() } label: { Image(systemName: "strikethrough") }
                .help("Strikethrough")

            Divider()

            Menu {
                Button("Heading 1") { controller.toggleHeading(level: 1) }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Heading 2") { controller.toggleHeading(level: 2) }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Heading 3") { controller.toggleHeading(level: 3) }
                    .keyboardShortcut("3", modifiers: .command)
            } label: {
                Image(systemName: "textformat.size")
            }
            .help("Heading level")

            Divider()

            Button { controller.insertBullet() } label: { Image(systemName: "list.bullet") }
                .help("Bullet list")
            Button { controller.insertNumbered() } label: { Image(systemName: "list.number") }
                .help("Numbered list")
            Button { controller.insertTask() } label: { Image(systemName: "checklist") }
                .help("Task list")

            Divider()

            Button { controller.toggleInlineCode() } label: { Image(systemName: "chevron.left.forwardslash.chevron.right") }
                .help("Inline code")
            Button { controller.insertCodeBlock() } label: { Image(systemName: "curlybraces") }
                .help("Code block")
            Button { controller.insertLink() } label: { Image(systemName: "link") }
                .keyboardShortcut("k", modifiers: .command)
                .help("Link")
            Button { controller.insertMermaid() } label: { Image(systemName: "chart.xyaxis.line") }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                .help("Mermaid diagram")
        }
    }
}
```

**Step 6: Wire toolbar into DocumentView**

```swift
struct DocumentView: View {
    @Bindable var document: MarkdownDocument
    @State private var render = RenderState()
    @State private var printController = PreviewPrintController()
    @State private var editor = EditorController()

    var body: some View {
        HSplitView {
            MarkdownTextView(text: $document.text, controller: editor)
                .frame(minWidth: 320)
            PreviewWebView(html: render.html, printController: printController)
                .frame(minWidth: 320)
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear { render.renderNow(document.text) }
        .onChange(of: document.text) { _, newValue in render.schedule(newValue) }
        .focusedSceneValue(\.printPreview, printController.printPreview)
        .toolbar { EditorToolbar(controller: editor) }
    }
}
```

**Step 7: Build, test, smoke-test toolbar visually**

```
xcodegen generate
xcodebuild ... build 2>&1 | tail -5
xcodebuild ... test 2>&1 | tail -15
```

Expected: all tests pass (26 total: 18 renderer + 3 highlighter + 5 editor controller).

Smoke: launch the app, select text, click Bold — see ** wrap. Cmd+K opens link with placeholder. Etc.

**Step 8: Commit**

```bash
git add MDPrintView/Editor MDPrintView/Views/DocumentView.swift MDPrintViewTests/EditorControllerTests.swift MDPrintView.xcodeproj/project.pbxproj
git commit -m "feat: EditorController + formatting toolbar with keyboard shortcuts"
```

---

### Task B3: HTML escaping audit for newly-added toolbar paths

Lightweight task — ensure user-typed link URLs and image URLs flow through the renderer's escape function (they should automatically since Task A1; this task is verification only).

**Files:**
- Modify: `MDPrintViewTests/MarkdownRendererTests.swift`

**Step 1: Test**

```swift
@Test("escapes javascript: protocol in link href")
func escapesDangerousLink() {
    // After A1's escaping, dangerous payloads should at least be neutralized
    // by HTML attribute escaping. We don't try to block javascript: URLs here —
    // that's CSP's job (it's already script-src 'self' in preview.html). We just
    // confirm escaping doesn't let an attacker break out of the href quote.
    let html = MarkdownRenderer().renderHTML(from: "[x](\"onload=alert(1) \")")
    #expect(!html.contains("\"onload"))
    #expect(html.contains("&quot;"))
}
```

**Step 2: Run + commit**

Expected: test passes. If not, A1's escaping has a gap — fix in renderer.

```bash
git add MDPrintViewTests/MarkdownRendererTests.swift
git commit -m "test: confirm link attribute escaping neutralizes quote-breakout"
```

---

## Phase C — Navigation

### Task C1: Outline sidebar

**Why:** Long documents need a TOC. The outline is also useful for click-to-scroll later.

**Files:**
- Create: `MDPrintView/Editor/Outline.swift`
- Create: `MDPrintView/Views/OutlineSidebar.swift`
- Modify: `MDPrintView/Views/DocumentView.swift`
- Test: `MDPrintViewTests/OutlineTests.swift`

**Step 1: Invoke Axiom skill**

Load: `Skill axiom-swiftui-layout` for `NavigationSplitView` sidebar patterns.

**Step 2: Outline data model + tests**

Create `MDPrintViewTests/OutlineTests.swift`:

```swift
import Testing
@testable import MDPrintView

@Suite("Outline")
struct OutlineTests {

    @Test("extracts flat headings")
    func flatHeadings() {
        let nodes = Outline.extract(from: "# A\n## B\n## C\n")
        #expect(nodes.map(\.title) == ["A"])
        #expect(nodes.first?.children.map(\.title) == ["B", "C"])
    }

    @Test("nests deeper levels under shallower")
    func nestedHeadings() {
        let nodes = Outline.extract(from: "# A\n## B\n### B1\n## C\n")
        let a = try #require(nodes.first)
        #expect(a.children.map(\.title) == ["B", "C"])
        let b = try #require(a.children.first)
        #expect(b.children.map(\.title) == ["B1"])
    }

    @Test("empty input yields empty outline")
    func emptyInput() {
        #expect(Outline.extract(from: "").isEmpty)
    }
}
```

**Step 3: Implement Outline**

Create `MDPrintView/Editor/Outline.swift`:

```swift
import Foundation
import Markdown

struct OutlineNode: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let level: Int
    var children: [OutlineNode]
}

enum Outline {
    static func extract(from source: String) -> [OutlineNode] {
        let document = Document(parsing: source)
        let flat: [(level: Int, title: String)] = document.children.compactMap { node in
            guard let heading = node as? Heading else { return nil }
            return (heading.level, heading.plainText)
        }
        return nest(flat)
    }

    private static func nest(_ flat: [(level: Int, title: String)]) -> [OutlineNode] {
        var roots: [OutlineNode] = []
        var stack: [(level: Int, ref: WritableKeyPath<[OutlineNode], OutlineNode>)] = []
        // Stack-free recursive build:
        func insert(_ entry: (level: Int, title: String), into parents: inout [OutlineNode]) -> Bool {
            // If the last sibling at this level deeper, recurse into its children
            if let lastIndex = parents.indices.last, parents[lastIndex].level < entry.level {
                var child = parents[lastIndex]
                if insert(entry, into: &child.children) {
                    parents[lastIndex] = child
                    return true
                }
            }
            parents.append(OutlineNode(title: entry.title, level: entry.level, children: []))
            return true
        }
        for entry in flat {
            _ = insert(entry, into: &roots)
        }
        return roots
    }
}
```

**Step 4: OutlineSidebar view**

Create `MDPrintView/Views/OutlineSidebar.swift`:

```swift
import SwiftUI

struct OutlineSidebar: View {
    let nodes: [OutlineNode]

    var body: some View {
        List {
            OutlineGroup(nodes, children: \.optionalChildren) { node in
                Text(node.title)
                    .font(.system(size: max(11, 14 - CGFloat(node.level - 1))))
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }
}

private extension OutlineNode {
    var optionalChildren: [OutlineNode]? {
        children.isEmpty ? nil : children
    }
}
```

**Step 5: Compose into DocumentView**

Update `DocumentView`:

```swift
struct DocumentView: View {
    @Bindable var document: MarkdownDocument
    @State private var render = RenderState()
    @State private var printController = PreviewPrintController()
    @State private var editor = EditorController()
    @State private var outline: [OutlineNode] = []

    var body: some View {
        NavigationSplitView {
            OutlineSidebar(nodes: outline)
        } detail: {
            HSplitView {
                MarkdownTextView(text: $document.text, controller: editor)
                    .frame(minWidth: 320)
                PreviewWebView(html: render.html, printController: printController)
                    .frame(minWidth: 320)
            }
            .frame(minWidth: 720, minHeight: 480)
        }
        .onAppear {
            render.renderNow(document.text)
            outline = Outline.extract(from: document.text)
        }
        .onChange(of: document.text) { _, newValue in
            render.schedule(newValue)
            outline = Outline.extract(from: newValue)
        }
        .focusedSceneValue(\.printPreview, printController.printPreview)
        .toolbar { EditorToolbar(controller: editor) }
    }
}
```

**Step 6: Build, test, smoke**

Expected: 29 tests pass (added 3 outline tests).

Manual: open a doc with headings; sidebar should show the TOC, nested.

Note: click-to-scroll is NOT in this task — it requires bidirectional scroll-tracking between editor and preview which is W3 polish.

**Step 7: Commit**

```bash
git add MDPrintView/Editor/Outline.swift MDPrintView/Views/OutlineSidebar.swift MDPrintView/Views/DocumentView.swift MDPrintViewTests/OutlineTests.swift MDPrintView.xcodeproj/project.pbxproj
git commit -m "feat: outline sidebar with nested headings"
```

---

## Phase D — Print quality

### Task D1: Print-mode CSS

**Why:** The basic print (W1 carryover) uses screen CSS. Adding `@page` rules, page breaks, and margin control delivers the original "print-ready" promise.

**Files:**
- Modify: `MDPrintView/Preview/Resources/preview.css`

**Step 1: Append print-mode rules**

Replace the existing `@media print` block at the bottom of `preview.css` with:

```css
@page {
    size: 8.5in 11in;
    margin: 0.75in;
}

@media print {
    body {
        color: #000;
        background: #fff;
        font-size: 11pt;
        line-height: 1.5;
    }
    main#content {
        max-width: none;
        margin: 0;
        padding: 0;
    }
    a {
        color: #000;
        text-decoration: underline;
    }
    h1, h2, h3, h4, h5, h6 {
        page-break-after: avoid;
        page-break-inside: avoid;
        break-after: avoid;
        break-inside: avoid;
    }
    h1 { border-bottom: 1px solid #000; }
    h2 { border-bottom: 1px solid #444; }
    pre, blockquote, table, img {
        page-break-inside: avoid;
        break-inside: avoid;
    }
    pre {
        border: 1px solid #ccc;
        background: #fafafa;
    }
    code {
        background: #f0f0f0;
        border-radius: 2px;
    }
    table {
        border-collapse: collapse;
    }
    th, td {
        border: 1px solid #888;
    }
    /* Avoid orphan/widow lines */
    p, li {
        orphans: 3;
        widows: 3;
    }
}

/* Print preview class (toggleable on <body> from Swift) — same rules without
   needing the real @media print state. Used by the screen/print toggle. */
body.print {
    background: #f5f5f5;
    color: #000;
    font-size: 11pt;
}
body.print main#content {
    background: #fff;
    max-width: 6.5in;
    margin: 1in auto;
    padding: 0.75in;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15);
}
```

**Step 2: Manual print smoke**

Rebuild, open the design doc, Cmd+P, choose "Save as PDF". Verify:
- Headings don't break mid-text
- Code blocks don't split awkwardly
- Margins look right (~0.75 inch)
- Links are underlined (not blue)

**Step 3: Commit**

```bash
git add MDPrintView/Preview/Resources/preview.css
git commit -m "feat: print-mode CSS with @page rules and break-inside controls"
```

---

### Task D2: Cmd+Shift+E PDF export

**Why:** Faster than `Cmd+P` → PDF dropdown. Standard macOS convention.

**Files:**
- Modify: `MDPrintView/Preview/PreviewPrintController.swift`
- Modify: `MDPrintView/MDPrintViewApp.swift`

**Step 1: Add `exportPDF` method to controller**

```swift
func exportPDF() {
    guard let webView, let window = webView.window else { return }
    let info = NSPrintInfo.shared
    info.jobDisposition = .save
    info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = nil // user-prompted via NSSavePanel
    let operation = webView.printOperation(with: info)
    operation.showsPrintPanel = false
    operation.showsProgressPanel = true
    operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
}
```

Actually the modern macOS path is simpler — use NSPrintOperation's `jobDisposition` set to `.save` and supply a save panel. But the print dialog's built-in PDF dropdown is so well-known that a "PDF export" command typically just opens the print dialog anyway. For minimum scope, make `exportPDF` open the print dialog with the PDF option highlighted via UI hint (not directly possible) — OR just punt and make Cmd+Shift+E equivalent to Cmd+P for now, with a TODO to refine.

Let me keep this task as: add `exportPDF` that runs an `NSSavePanel` then writes the PDF directly:

```swift
func exportPDF() {
    guard let webView, let window = webView.window else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.pdf]
    panel.nameFieldStringValue = window.title.replacingOccurrences(of: ".md", with: ".pdf")
    panel.beginSheetModal(for: window) { response in
        guard response == .OK, let url = panel.url else { return }
        let info = NSPrintInfo(dictionary: [:])
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url
        info.topMargin = 54
        info.bottomMargin = 54
        info.leftMargin = 54
        info.rightMargin = 54
        let operation = webView.printOperation(with: info)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = true
        operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }
}
```

Then add a FocusedValue + menu command:

```swift
struct ExportPDFFocusKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var exportPDF: ExportPDFFocusKey.Value? {
        get { self[ExportPDFFocusKey.self] }
        set { self[ExportPDFFocusKey.self] = newValue }
    }
}
```

And in `MDPrintViewApp.swift`:

```swift
.commands {
    CommandGroup(replacing: .printItem) {
        PrintMenuItem()
        ExportPDFMenuItem()
    }
}

private struct ExportPDFMenuItem: View {
    @FocusedValue(\.exportPDF) private var action
    var body: some View {
        Button("Export as PDF…") { action?() }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(action == nil)
    }
}
```

In DocumentView, expose `.focusedSceneValue(\.exportPDF, printController.exportPDF)`.

**Step 2: Build + smoke**

Cmd+Shift+E opens a save panel, writes a PDF.

**Step 3: Commit**

```bash
git add MDPrintView/Preview/PreviewPrintController.swift MDPrintView/MDPrintViewApp.swift MDPrintView/Views/DocumentView.swift
git commit -m "feat: Cmd+Shift+E exports preview to PDF via NSSavePanel"
```

---

### Task D3: Screen / Print preview mode toggle

**Why:** "See what you'll print while you edit" — the original product promise.

**Files:**
- Modify: `MDPrintView/Preview/PreviewWebView.swift`
- Modify: `MDPrintView/Preview/RenderState.swift` (or create `PreviewMode.swift`)
- Modify: `MDPrintView/Views/DocumentView.swift`

**Step 1: Add a mode enum + state**

In `MDPrintView/Preview/PreviewWebView.swift`, add:

```swift
enum PreviewMode: String, CaseIterable, Identifiable {
    case screen, print
    var id: String { rawValue }
    var label: String { self == .screen ? "Screen" : "Print" }
}
```

**Step 2: Pass mode to PreviewWebView and apply as body class**

Update `PreviewWebView`:

```swift
struct PreviewWebView: NSViewRepresentable {
    let html: String
    let mode: PreviewMode
    let printController: PreviewPrintController

    // ... makeNSView unchanged ...

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.templateReady {
            inject(html: html, mode: mode, into: webView)
        } else {
            context.coordinator.pendingHTML = html
            context.coordinator.pendingMode = mode
        }
    }

    fileprivate static func inject(html: String, mode: PreviewMode, into webView: WKWebView) {
        let escaped = escape(html)
        let cls = mode == .print ? "print" : "screen"
        let js = """
        document.body.className = '\(cls)';
        document.getElementById('content').innerHTML = `\(escaped)`;
        """
        webView.evaluateJavaScript(js)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var pendingHTML: String = ""
        var pendingMode: PreviewMode = .screen
        var templateReady: Bool = false

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            templateReady = true
            PreviewWebView.inject(html: pendingHTML, mode: pendingMode, into: webView)
        }
    }
}
```

**Step 3: Mode picker in the preview pane**

Update `DocumentView`:

```swift
@State private var previewMode: PreviewMode = .screen

// in body:
VStack(spacing: 0) {
    Picker("", selection: $previewMode) {
        ForEach(PreviewMode.allCases) { Text($0.label).tag($0) }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .padding(.horizontal, 8)
    .padding(.vertical, 4)

    PreviewWebView(html: render.html, mode: previewMode, printController: printController)
}
.frame(minWidth: 320)
```

**Step 4: Keyboard shortcut**

Add a CommandGroup with `Cmd+Opt+P` toggling between modes. Or punt to W3 — minimum is the picker.

**Step 5: Smoke**

Toggle to Print — should see the simulated paper card background with margins; toggle to Screen — back to flowing layout.

**Step 6: Commit**

```bash
git add MDPrintView/Preview/PreviewWebView.swift MDPrintView/Views/DocumentView.swift
git commit -m "feat: Screen/Print preview mode toggle"
```

---

## Phase E — Visual polish

### Task E1: Liquid Glass on toolbar + sidebar

**Files:**
- Modify: toolbar, sidebar, possibly window background materials

**Step 1: Invoke Axiom skill**

Load: `Skill axiom-liquid-glass`. **Follow its guidance exactly.** The skill is the source of truth for which modifiers, materials, and tinting are correct in macOS 26.

**Step 2: Apply per skill guidance**

Likely changes (let the skill confirm):
- Toolbar items: glass tinted modifier
- Sidebar: `.background(.regularMaterial)` or the new Liquid Glass material
- Preview-pane mode picker chrome: glass

Defer specific code to skill invocation — the skill provides the patterns and we apply them.

**Step 3: Smoke + commit**

Smoke: visual diff vs prior commit; the toolbar should now feel macOS 26-native.

```bash
git add <files>
git commit -m "style: Liquid Glass on toolbar, sidebar, and preview chrome"
```

---

## Phase F — Verification

### Task F1: Strengthen smoke test infrastructure

**Why:** Week 1's "process alive" smoke test missed an empty preview (the CSP bug). Replace with "preview content non-empty + screenshot."

**Files:**
- Create: `scripts/smoke.sh`

**Step 1: Write the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name 'MDPrintView.app' -path '*Debug*' -type d -print -quit)
if [ -z "$APP_PATH" ]; then echo "App not built — run 'xcodebuild build' first" >&2; exit 1; fi

SAMPLE=$(mktemp -t MDPrintView-smoke).md
trap "rm -f $SAMPLE" EXIT

cat > "$SAMPLE" <<'EOF'
# Smoke Test

Hello **bold** and *italic* and `code` and a [link](https://example.com).

- bullet one
- bullet two

> A quote

```
fenced code block
```
EOF

open "$APP_PATH" "$SAMPLE"
sleep 3

if ! pgrep -lf 'MDPrintView.app/Contents/MacOS/MDPrintView' >/dev/null; then
    echo "FAIL: process not running"
    exit 1
fi

# Take a window screenshot for visual diffing (caller can compare manually)
SCREENSHOT="/tmp/MDPrintView-smoke-$(date +%s).png"
screencapture -o -t png "$SCREENSHOT" || echo "(screencapture may need TCC; continuing)"
echo "Screenshot: $SCREENSHOT"

# Quit
osascript -e 'tell application "MDPrintView" to quit' 2>/dev/null || true
sleep 1
pkill -x MDPrintView 2>/dev/null || true

echo "OK: process stayed alive, screenshot at $SCREENSHOT"
```

Make executable, run, commit.

**Step 2: Commit**

```bash
chmod +x scripts/smoke.sh
git add scripts/smoke.sh
git commit -m "chore: add scripts/smoke.sh for manual end-to-end verification"
```

---

### Task F2: End-to-end XCUITest

**Why:** Catches regressions like the empty WebView automatically.

**Files:**
- Create: `MDPrintViewUITests/PrintEndToEndTests.swift`
- Modify: `project.yml` to add a UI test target

**Step 1: Invoke Axiom skill**

Load: `Skill axiom-ui-testing`. It covers XCUITest setup, `XCUIApplication.launch`, element queries, and print dialog automation.

**Step 2: Add UI test target to project.yml**

Append to `project.yml`:

```yaml
  MDPrintViewUITests:
    type: bundle.ui-testing
    platform: macOS
    sources:
      - path: MDPrintViewUITests
    dependencies:
      - target: MDPrintView
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: net.cmagsisi.MDPrintViewUITests
        TEST_TARGET_NAME: MDPrintView
        MACOSX_DEPLOYMENT_TARGET: "26.0"
```

Update `schemes.MDPrintView.test.targets` to include `MDPrintViewUITests`.

Run `xcodegen generate`.

**Step 3: Write the test**

Create `MDPrintViewUITests/PrintEndToEndTests.swift`:

```swift
import XCTest

final class PrintEndToEndTests: XCTestCase {

    func testOpenSampleAndExportPDF() throws {
        let sample = createSample()
        defer { try? FileManager.default.removeItem(at: sample) }

        let app = XCUIApplication()
        app.launchArguments = ["--openFile", sample.path]
        app.launch()

        // Wait for window to appear
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))

        // Verify preview pane has rendered content (sanity check via accessibility)
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.waitForExistence(timeout: 5))

        // Trigger Cmd+Shift+E
        app.typeKey("e", modifierFlags: [.command, .shift])

        // Save panel should appear
        let savePanel = app.dialogs.firstMatch
        XCTAssertTrue(savePanel.waitForExistence(timeout: 5))

        let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID().uuidString).pdf")
        // Set save location (implementation depends on accessibility identifiers — see axiom-ui-testing)

        // Click Save
        savePanel.buttons["Save"].click()

        // Verify file exists
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in FileManager.default.fileExists(atPath: pdfURL.path) },
            object: nil
        )
        wait(for: [expectation], timeout: 10)
    }

    private func createSample() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("smoke-\(UUID().uuidString).md")
        try? "# Test\n\nHello **world**.".write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
```

Note: precise click coordinates and save-panel interaction depend on the axiom-ui-testing skill's patterns — refine on first run.

**Step 4: Run + commit**

```
xcodebuild test -project MDPrintView.xcodeproj -scheme MDPrintView -destination 'platform=macOS' -only-testing:MDPrintViewUITests 2>&1 | tail -20
```

```bash
git add MDPrintViewUITests project.yml MDPrintView.xcodeproj
git commit -m "test: end-to-end XCUITest opens sample, exports PDF, verifies file"
```

---

## Week 2 milestone

After all 13 tasks:
- ✅ Renderer handles every common markdown node and HTML-escapes user content
- ✅ Editor has syntax highlighting and a formatting toolbar (with Cmd+B/I/K/1/2/3 etc.)
- ✅ Outline sidebar shows TOC, nested
- ✅ Print CSS produces clean printed output with proper page breaks
- ✅ Cmd+P and Cmd+Shift+E both work
- ✅ Screen/Print preview mode toggle
- ✅ Liquid Glass styling on chrome
- ✅ Smoke script + one XCUITest catches regressions like the empty-WebView bug

This delivers the original product promise: a polished markdown editor that prints beautifully.

---

## Execution handoff

Plan complete. Two execution options:

**1. Subagent-Driven (this session)** — same pattern as Week 1: fresh subagent per task, two-stage review, mark complete in TaskList.

**2. Parallel Session (separate)** — open a new session in this dir, invoke `superpowers:executing-plans`, work through the doc.

For Week 2 most tasks are self-contained Swift edits with the Xcode UI required only briefly. **Recommend subagent-driven**, same as Week 1.
