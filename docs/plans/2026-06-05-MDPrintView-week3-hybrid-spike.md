# MDPrintView Week 3 — Hybrid Live-Format Editor Spike

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (or subagent-driven-development for same-session) to execute this plan task-by-task.

**Goal:** Determine whether a Typora-style hybrid live-format editor mode is feasible for v1 of MDPrintView, or whether it should be deferred to v1.1. Deliver the maximum useful subset that meets quality criteria.

**Spike question:** Can we render markdown source as styled text inline (headings larger, bold actually bold, etc.) — and additionally hide/reveal syntax marks based on cursor position — without compromising editing smoothness, selection correctness, or undo?

**Architecture:** Build on the existing `MarkdownTextView` (NSTextView + TextKit 2) and `SyntaxHighlighter`. Add a `LiveFormatStyler` that walks the swift-markdown AST and applies *rich* `NSAttributedString` attributes (font size, font traits, foreground color including invisible-when-folded). Surface as a toggleable editor mode via `EditorMode` enum + toolbar picker. Mode persists per-window (not in document).

**Tech Stack:**
- Swift 6 on macOS 26
- TextKit 2 via `NSTextView.scrollableTextView()` + `textView.textStorage`
- `swift-markdown` 0.8 source-range walking
- `NSTextStorage.addAttribute`/`removeAttribute` for styling (proven safe — `textDidChange` only fires on content changes, not attribute changes)
- Reference: `axiom-textkit-ref` (load before Experiment 3)

**Reference docs:**
- Design: `docs/plans/2026-06-01-MDPrintView-design.md` Section B (editor modes)
- Week 2 plan: `docs/plans/2026-06-02-MDPrintView-week2.md`
- Current commit: `4e8e6d3`

---

## Gating decision rubric

The spike has **graduated success criteria**. We can ship any subset that meets its bar:

| Experiment | Delivers | Bar |
|---|---|---|
| **E1: Inline rich styling** (marks visible) | Headings, bold, italic, code, links render with proper font weight + size; marks still visible but styled | No cursor jumps; ≥60fps typing on 10KB doc; no selection bugs |
| **E2: Faded marks** | Same as E1 but `**`, `_`, `#` etc. tinted to tertiary (de-emphasized but visible) | Same as E1, plus marks are visually distinct from content text |
| **E3: Cursor-aware folding** | Marks become invisible when cursor outside their span, revealed when cursor enters | E2 bars + selection across folds selects expected source range; undo intact; ≥60fps cursor movement; no cursor-positioning glitches |
| **E4: Real-doc stress** | 10–50KB docs, mixed content, rapid typing + cursor movement | E3 bars hold; no measurable lag; no crashes; no `xcuserstate` corruption |

**Outcomes:**
- **E1+E2+E3+E4 all pass:** Ship hybrid mode in v1, fully featured.
- **E1+E2 pass, E3 or E4 fails:** Ship "Rich" mode in v1 (rich styling only, marks visible — no folding). Defer fold/reveal to v1.1.
- **E1 fails:** Defer hybrid entirely. Document why. Move to Week 4 work.

Spike does NOT need to land a polished UI in this week — just the technical answer. Polish (mode picker icon, transitions, settings persistence) lands after the gate decision in a follow-up.

**Time box:** 1 week of focused part-time work. Stop at week-end regardless of progress and make the call.

---

## Phasing overview

| Task | Theme | Expected effort |
|---|---|---|
| T0 | Baseline capture (no code) | 15 min |
| T1 | `EditorMode` enum + mode toggle infrastructure | 30 min |
| T2 | `LiveFormatStyler` skeleton + tests (E1 bar) | 1–2 hr |
| T3 | Apply LiveFormatStyler in hybrid mode | 30 min |
| T4 | E1 evaluation — go/no-go to E2 | 30 min |
| T5 | Fade syntax marks (E2 bar) | 1 hr |
| T6 | E2 evaluation — go/no-go to E3 | 30 min |
| T7 | Cursor-aware fold/reveal (E3 bar) | 3–6 hr |
| T8 | E3 evaluation — go/no-go to E4 | 30 min |
| T9 | Real-doc stress test (E4 bar) | 1–2 hr |
| T10 | Write decision doc | 30 min |

10 tasks. Tasks T4/T6/T8/T9 are **decision checkpoints** — they may end the spike early with an honest "defer" outcome.

---

## Task 0: Baseline capture

**Files:** None (read-only investigation).

**Step 1: Document current editor visual state**

Run:
```
cd /Users/cmagsisi/Dev/MDPrintView
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name 'MDPrintView.app' -path '*Debug*' -type d -print -quit)
open "$APP_PATH" docs/plans/2026-06-01-MDPrintView-design.md
```

Open the design doc. Note in a scratch file what's currently true (so we can compare after each experiment):

- Editor source: monospaced 14pt
- Headings (W2 syntax highlighter): larger + bold via attribute on the whole `# Heading` range
- Inline code: secondary label color
- Links: link color
- Marks `#`, `**`, `_` are NOT hidden — they're visible as part of the source
- Cursor moves through all characters; no folding behavior

**Step 2: Commit the baseline note**

Create `/Users/cmagsisi/Dev/MDPrintView/docs/plans/2026-06-05-spike-notes.md` with these baseline observations. Each subsequent experiment will append a section.

```bash
git add docs/plans/2026-06-05-spike-notes.md
git commit -m "docs: Week 3 spike — baseline capture"
```

---

## Task 1: `EditorMode` enum + mode toggle

**Why:** All subsequent experiments need to be GATED behind a mode toggle so the existing source mode keeps working. If we ship "Rich only" or defer entirely, the toggle either stays or disappears.

**Files:**
- Create: `MDPrintView/Editor/EditorMode.swift`
- Modify: `MDPrintView/Editor/MarkdownTextView.swift`
- Modify: `MDPrintView/Editor/EditorToolbar.swift`
- Modify: `MDPrintView/Views/DocumentView.swift`

**Step 1: `EditorMode` enum**

Create `MDPrintView/Editor/EditorMode.swift`:

```swift
import Foundation

enum EditorMode: String, CaseIterable, Identifiable {
    case source
    case hybrid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .source: return "Source"
        case .hybrid: return "Hybrid"
        }
    }
}
```

**Step 2: Add mode parameter to MarkdownTextView**

In `MDPrintView/Editor/MarkdownTextView.swift`, change the struct signature:

```swift
struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    let controller: EditorController
    let mode: EditorMode
    // ...existing code...
}
```

In `makeNSView`, branch on mode for which styler to apply (placeholder — actual styler comes in T2):

```swift
textView.string = text
controller.textView = textView
if let storage = textView.textStorage {
    switch mode {
    case .source:
        SyntaxHighlighter().apply(to: storage)
    case .hybrid:
        // Will be LiveFormatStyler().apply(to: storage) once T2 lands
        SyntaxHighlighter().apply(to: storage) // fallback for now
    }
}
```

In `updateNSView`, do the same branching. Also pass mode to Coordinator (so textDidChange can re-apply correctly).

**Step 3: Mode picker in DocumentView toolbar**

Add to `EditorToolbar.swift`:

```swift
struct EditorModePicker: View {
    @Binding var mode: EditorMode

    var body: some View {
        Picker("Mode", selection: $mode) {
            ForEach(EditorMode.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 140)
    }
}
```

In `EditorToolbar`, add it as a leading group:

```swift
struct EditorToolbar: ToolbarContent {
    let controller: EditorController
    @Binding var mode: EditorMode

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            EditorModePicker(mode: $mode)
        }
        ToolbarItemGroup(placement: .principal) {
            // ...existing formatting buttons...
        }
    }
}
```

**Step 4: DocumentView holds the mode state**

In `DocumentView.swift`:

```swift
@State private var editorMode: EditorMode = .source
// ...
MarkdownTextView(text: $document.text, controller: editor, mode: editorMode)
// ...
.toolbar { EditorToolbar(controller: editor, mode: $editorMode) }
```

**Step 5: Regenerate, build, test, commit**

```
xcodegen generate
xcodebuild -project MDPrintView.xcodeproj -scheme MDPrintView -destination 'platform=macOS' -configuration Debug build 2>&1 | tail -5
xcodebuild -project MDPrintView.xcodeproj -scheme MDPrintView -destination 'platform=macOS' -configuration Debug test 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED, 33 tests still pass. App launches; toolbar shows Source/Hybrid picker; both modes currently render identically (placeholder — actual hybrid behavior comes in T2-T3).

```bash
git add MDPrintView/Editor MDPrintView/Views/DocumentView.swift MDPrintView.xcodeproj/project.pbxproj
git commit -m "feat: EditorMode enum + Source/Hybrid toggle (hybrid is placeholder)"
```

---

## Task 2: `LiveFormatStyler` skeleton + E1 tests

**Why:** Distinct file from `SyntaxHighlighter` so source mode is unaffected. Same swift-markdown walk pattern, but the *attributes* are richer (real font sizes, real font weights/traits, not just color hints).

**Files:**
- Create: `MDPrintView/Editor/LiveFormatStyler.swift`
- Test: `MDPrintViewTests/LiveFormatStylerTests.swift`

**Step 1: RED tests**

Create `MDPrintViewTests/LiveFormatStylerTests.swift`:

```swift
import Testing
import AppKit
@testable import MDPrintView

@Suite("LiveFormatStyler — E1 (rich inline styling, marks visible)", .serialized)
@MainActor
struct LiveFormatStylerE1Tests {

    @Test("h1 gets a meaningfully larger font than body")
    func h1Larger() {
        let storage = NSTextStorage(string: "# Heading\nbody\n")
        LiveFormatStyler().apply(to: storage)
        let headingFont = storage.attributes(at: 0, effectiveRange: nil)[.font] as? NSFont
        let bodyFont = storage.attributes(at: 10, effectiveRange: nil)[.font] as? NSFont
        let headingSize = headingFont?.pointSize ?? 0
        let bodySize = bodyFont?.pointSize ?? 0
        #expect(headingSize >= bodySize + 4) // At least 4pt difference to feel like a heading
    }

    @Test("bold span gets bold font trait")
    func boldTrait() {
        let storage = NSTextStorage(string: "say **bold** word")
        LiveFormatStyler().apply(to: storage)
        // "bold" is at index 6
        let attrs = storage.attributes(at: 6, effectiveRange: nil)
        let font = attrs[.font] as? NSFont
        #expect(font?.fontDescriptor.symbolicTraits.contains(.bold) == true)
    }

    @Test("italic span gets italic font trait")
    func italicTrait() {
        let storage = NSTextStorage(string: "say *em* word")
        LiveFormatStyler().apply(to: storage)
        // "em" is at index 5
        let attrs = storage.attributes(at: 5, effectiveRange: nil)
        let font = attrs[.font] as? NSFont
        #expect(font?.fontDescriptor.symbolicTraits.contains(.italic) == true)
    }

    @Test("inline code uses monospaced font")
    func inlineCodeMono() {
        let storage = NSTextStorage(string: "see `code` text")
        LiveFormatStyler().apply(to: storage)
        // "code" starts at index 5
        let attrs = storage.attributes(at: 5, effectiveRange: nil)
        let font = attrs[.font] as? NSFont
        #expect(font?.fontName.contains("Menlo") == true || font?.fontName.contains("Mono") == true)
    }

    @Test("link gets distinct color")
    func linkColored() {
        let storage = NSTextStorage(string: "[label](https://example.com)")
        LiveFormatStyler().apply(to: storage)
        var found: NSColor?
        storage.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: storage.length)) { value, _, _ in
            if let c = value as? NSColor, c == .linkColor { found = c }
        }
        #expect(found == .linkColor)
    }
}
```

**Step 2: Run — expect compile-error RED**

```
xcodebuild -project MDPrintView.xcodeproj -scheme MDPrintView -destination 'platform=macOS' -configuration Debug test 2>&1 | tail -10
```

Expected: `cannot find 'LiveFormatStyler' in scope`. Commit:

```
git add MDPrintViewTests/LiveFormatStylerTests.swift
git commit -m "test(red): LiveFormatStyler E1 — rich inline styling"
```

**Step 3: Implement LiveFormatStyler**

Create `MDPrintView/Editor/LiveFormatStyler.swift`:

```swift
import AppKit
import Markdown

@MainActor
struct LiveFormatStyler {
    private let baseFontSize: CGFloat = 16 // larger than source-mode 14pt — feels more like rendered text
    private let headingSizes: [CGFloat] = [28, 22, 18, 16, 16, 16] // h1=28, h2=22, h3=18, others=base

    func apply(to storage: NSTextStorage) {
        let source = storage.string
        let document = Document(parsing: source)
        let fullRange = NSRange(location: 0, length: storage.length)

        storage.beginEditing()
        defer { storage.endEditing() }

        // Reset to base.
        storage.removeAttribute(.font, range: fullRange)
        storage.removeAttribute(.foregroundColor, range: fullRange)
        storage.addAttribute(.font, value: bodyFont(), range: fullRange)
        storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)

        for markup in document.children {
            apply(markup, to: storage, source: source)
        }
    }

    private func bodyFont() -> NSFont {
        NSFont.systemFont(ofSize: baseFontSize, weight: .regular)
    }

    private func headingFont(level: Int) -> NSFont {
        let idx = max(0, min(level - 1, headingSizes.count - 1))
        return NSFont.systemFont(ofSize: headingSizes[idx], weight: .bold)
    }

    private func boldVariant(of font: NSFont) -> NSFont {
        var traits = font.fontDescriptor.symbolicTraits
        traits.insert(.bold)
        let desc = font.fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: desc, size: font.pointSize) ?? font
    }

    private func italicVariant(of font: NSFont) -> NSFont {
        var traits = font.fontDescriptor.symbolicTraits
        traits.insert(.italic)
        let desc = font.fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: desc, size: font.pointSize) ?? font
    }

    private func monoFont() -> NSFont {
        NSFont.monospacedSystemFont(ofSize: baseFontSize - 1, weight: .regular)
    }

    private func apply(_ markup: Markup, to storage: NSTextStorage, source: String) {
        if let range = nsRange(for: markup, in: source) {
            switch markup {
            case let heading as Heading:
                storage.addAttribute(.font, value: headingFont(level: heading.level), range: range)
            case is Strong:
                storage.enumerateAttribute(.font, in: range) { value, subRange, _ in
                    let font = (value as? NSFont) ?? bodyFont()
                    storage.addAttribute(.font, value: boldVariant(of: font), range: subRange)
                }
            case is Emphasis:
                storage.enumerateAttribute(.font, in: range) { value, subRange, _ in
                    let font = (value as? NSFont) ?? bodyFont()
                    storage.addAttribute(.font, value: italicVariant(of: font), range: subRange)
                }
            case is InlineCode, is CodeBlock:
                storage.addAttribute(.font, value: monoFont(), range: range)
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: range)
            case is Link:
                storage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
            default:
                break
            }
        }

        for child in markup.children {
            apply(child, to: storage, source: source)
        }
    }

    private func nsRange(for markup: Markup, in source: String) -> NSRange? {
        guard let range = markup.range else { return nil }
        let nsString = source as NSString
        let start = offset(for: range.lowerBound, in: source)
        let end = offset(for: range.upperBound, in: source)
        guard start >= 0, end >= start, end <= nsString.length else { return nil }
        return NSRange(location: start, length: end - start)
    }

    private func offset(for location: SourceLocation, in source: String) -> Int {
        let lines = source.components(separatedBy: "\n")
        var offset = 0
        let targetLine = max(1, location.line)
        for (i, line) in lines.enumerated() {
            if i + 1 == targetLine {
                let col = max(1, location.column) - 1
                let lineLength = (line as NSString).length
                return offset + min(col, lineLength)
            }
            offset += (line as NSString).length + 1
        }
        return offset
    }
}
```

**Step 4: Run — verify 38 tests pass (33 + 5)**

```
xcodebuild ... test 2>&1 | tail -10
```

If h1 size test fails because heading size doesn't differ enough, the styler is broken — STOP and report.

**Step 5: Commit GREEN**

```bash
git add MDPrintView/Editor/LiveFormatStyler.swift MDPrintView.xcodeproj/project.pbxproj
git commit -m "feat(green): LiveFormatStyler — rich inline styling (E1 baseline)"
```

---

## Task 3: Apply LiveFormatStyler in hybrid mode

**Files:**
- Modify: `MDPrintView/Editor/MarkdownTextView.swift`

Swap the placeholder `SyntaxHighlighter()` call (added in T1) for `LiveFormatStyler()` in the `.hybrid` branch. Both in `makeNSView`, `updateNSView`, and the `Coordinator.textDidChange`.

The Coordinator needs to know which styler to use — pass mode via the Context, or store it as a property on Coordinator (preferred — see how the controller is wired):

```swift
@MainActor
final class Coordinator: NSObject, NSTextViewDelegate {
    let text: Binding<String>
    var mode: EditorMode
    private let sourceHighlighter = SyntaxHighlighter()
    private let liveFormatStyler = LiveFormatStyler()

    init(text: Binding<String>, mode: EditorMode) {
        self.text = text
        self.mode = mode
    }

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        text.wrappedValue = textView.string
        guard let storage = textView.textStorage else { return }
        switch mode {
        case .source: sourceHighlighter.apply(to: storage)
        case .hybrid: liveFormatStyler.apply(to: storage)
        }
    }
}
```

In `updateNSView`, when SwiftUI passes a new mode, update the Coordinator's `mode` AND re-apply:

```swift
func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? NSTextView else { return }
    let modeChanged = context.coordinator.mode != mode
    context.coordinator.mode = mode
    if textView.string != text {
        textView.string = text
    }
    if modeChanged || textView.string == text /* always reapply on update */ {
        if let storage = textView.textStorage {
            switch mode {
            case .source: SyntaxHighlighter().apply(to: storage)
            case .hybrid: LiveFormatStyler().apply(to: storage)
            }
        }
    }
}
```

**Step 1: Build, test**

```
xcodegen generate
xcodebuild ... build 2>&1 | tail -5
xcodebuild ... test 2>&1 | tail -5
```

**Step 2: Manual smoke**

```
pkill -x MDPrintView 2>/dev/null
open "$APP_PATH" docs/plans/2026-06-01-MDPrintView-design.md
```

In the running app: toggle Source → Hybrid in the toolbar. The editor should re-render with bigger headings, real bold for `**bold**`, etc. Marks (`#`, `**`) are STILL VISIBLE.

**Step 3: Commit**

```bash
git add MDPrintView/Editor/MarkdownTextView.swift
git commit -m "feat: hybrid mode applies LiveFormatStyler (E1 — marks visible)"
```

---

## Task 4: E1 evaluation — checkpoint

**Manual test pass (DO NOT skip — this is the gate):**

Open three docs of varying sizes:
1. A small doc (~1KB) — type characters in a heading, type inside bold, type inside code
2. A medium doc (~10KB) — same operations, plus scroll while typing
3. The combined Week 1+2+3 plan docs (~50KB total) — open, type characters in different sections

For each, observe:
- [ ] Does the cursor move smoothly across heading/bold/italic/code boundaries?
- [ ] Does typing in the middle of a styled span maintain the styling continuously?
- [ ] Does the highlight re-apply finish before the next keystroke (no visible lag at normal typing speed)?
- [ ] Selecting a range across styled boundaries — does selection draw cleanly?
- [ ] Cmd+Z / Cmd+Shift+Z work as expected? Each undo is one logical edit?

**Append findings to `docs/plans/2026-06-05-spike-notes.md`** under "## E1 evaluation":

```markdown
## E1 evaluation (rich inline styling, marks visible)

**Bar:** No cursor jumps; ≥60fps typing on 10KB doc; no selection bugs.

**Test results:**
- Small doc (1KB): [PASS / FAIL — describe]
- Medium doc (10KB): [PASS / FAIL — describe]
- Large doc (50KB): [PASS / FAIL — describe]
- Cursor smoothness: [PASS / FAIL]
- Selection drawing: [PASS / FAIL]
- Undo: [PASS / FAIL]

**Verdict:** [PASS — proceed to E2 / FAIL — stop spike, "Rich" mode is not shippable]

**Notes:**
- ...
```

If verdict is FAIL — STOP the spike. Mark the gate task complete with the "deferred to v1.1" outcome. Move on to whatever else the user wants.

If verdict is PASS — proceed to T5.

**Commit:**

```bash
git add docs/plans/2026-06-05-spike-notes.md
git commit -m "docs: Week 3 spike — E1 evaluation [PASS or FAIL]"
```

---

## Task 5: Fade syntax marks (E2)

**Why:** Marks should be visible-but-de-emphasized so the rendered styling reads cleanly.

**Approach:** During the same AST walk, compute the *mark ranges* (the `#` prefix on a heading, the `**` delimiters on Strong, etc.) and apply a tertiary-color foreground to them.

**Files:**
- Modify: `MDPrintView/Editor/LiveFormatStyler.swift`
- Test: `MDPrintViewTests/LiveFormatStylerTests.swift`

**Step 1: Failing tests**

Append to `MDPrintViewTests/LiveFormatStylerTests.swift`:

```swift
@Suite("LiveFormatStyler — E2 (faded marks)", .serialized)
@MainActor
struct LiveFormatStylerE2Tests {

    @Test("heading marker # is faded")
    func headingMarkFaded() {
        let storage = NSTextStorage(string: "# Heading\n")
        LiveFormatStyler().apply(to: storage)
        // "#" is at index 0
        let attrs = storage.attributes(at: 0, effectiveRange: nil)
        let color = attrs[.foregroundColor] as? NSColor
        #expect(color == .tertiaryLabelColor)
    }

    @Test("bold marker ** is faded")
    func boldMarksFaded() {
        let storage = NSTextStorage(string: "**bold**")
        LiveFormatStyler().apply(to: storage)
        // First "*" at index 0
        let leadingMark = storage.attributes(at: 0, effectiveRange: nil)
        #expect((leadingMark[.foregroundColor] as? NSColor) == .tertiaryLabelColor)
        // Last "*" at index 7
        let trailingMark = storage.attributes(at: 7, effectiveRange: nil)
        #expect((trailingMark[.foregroundColor] as? NSColor) == .tertiaryLabelColor)
    }

    @Test("italic marker * is faded")
    func italicMarksFaded() {
        let storage = NSTextStorage(string: "*em*")
        LiveFormatStyler().apply(to: storage)
        let leadingMark = storage.attributes(at: 0, effectiveRange: nil)
        #expect((leadingMark[.foregroundColor] as? NSColor) == .tertiaryLabelColor)
    }
}
```

**Step 2: Implement mark fading**

In `LiveFormatStyler.swift`, extract the source-range trim helper and apply tertiary color to the leading + trailing mark ranges. Pattern for Strong (`**x**`):

```swift
case is Strong:
    // Style children as bold first
    storage.enumerateAttribute(.font, in: range) { value, subRange, _ in
        let font = (value as? NSFont) ?? bodyFont()
        storage.addAttribute(.font, value: boldVariant(of: font), range: subRange)
    }
    // Fade the leading and trailing ** marks
    if range.length >= 4 {
        let leading = NSRange(location: range.location, length: 2)
        let trailing = NSRange(location: range.location + range.length - 2, length: 2)
        storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: leading)
        storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: trailing)
    }
```

Repeat for Emphasis (1 char marks), Heading (`#` prefix — variable length), InlineCode (1 char), CodeBlock (3 + 3 chars + optional fence info).

For headings, the leading marks are `#`*level + space. Compute as:
```swift
case let heading as Heading:
    storage.addAttribute(.font, value: headingFont(level: heading.level), range: range)
    let markLen = heading.level + 1 // # + space
    if range.length >= markLen {
        let markRange = NSRange(location: range.location, length: markLen)
        storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: markRange)
    }
```

**Step 3: Run, test, commit**

```
xcodebuild ... test 2>&1 | tail -10
```

Expected: 41 tests pass (38 + 3 E2).

```bash
git add MDPrintView/Editor/LiveFormatStyler.swift MDPrintViewTests/LiveFormatStylerTests.swift
git commit -m "feat(green): LiveFormatStyler — fade syntax marks (E2)"
```

---

## Task 6: E2 evaluation — checkpoint

Append to `docs/plans/2026-06-05-spike-notes.md`:

```markdown
## E2 evaluation (faded marks)

**Bar:** E1 bar + marks are visually distinct from content text.

**Test results:** [...]

**Verdict:** [PASS — proceed to E3 / FAIL — stop at E1 / E2 partial — ship "Rich" mode in v1, defer E3 to v1.1]

**Notes:** [Subjective read: do faded marks read better than W2 source mode? Worse than Typora? Acceptable?]
```

If E2 result is "ship Rich" — STOP spike, mark hybrid v1 as "Rich (E1+E2) only". Otherwise proceed to T7.

Commit:

```bash
git add docs/plans/2026-06-05-spike-notes.md
git commit -m "docs: Week 3 spike — E2 evaluation"
```

---

## Task 7: Cursor-aware fold/reveal (E3)

> **Before starting:** Load `axiom-textkit-ref` via the Skill tool. This task touches the trickiest TextKit 2 territory we'll encounter.

**Approach:** Observe NSTextView selection changes via the delegate's `textViewDidChangeSelection(_:)`. When selection changes, re-apply the styler with the new cursor position; for marks NOT under the cursor, set foreground color to `.clear` (effectively invisible — the characters still occupy zero glyph width? No — clear color hides them visually but they still take layout width).

**Critical TextKit caveat:** Setting foreground color to `.clear` makes the text invisible BUT it still occupies horizontal space. To truly hide it (zero width), we'd need to either:
1. Custom NSTextLayoutFragment that skips drawing the range (TextKit 2 way, complex)
2. Set the font size to a tiny value (cursor positioning gets weird)
3. Use NSTextContentManager's `shouldEnumerate` to filter out the marks entirely (cleanest, but inserting/typing might break)

**Spike-grade approach for E3:** Use approach #1 if feasible in the time budget, else fall back to `.clear` color and accept the "ghost space" as a known limitation. Document the tradeoff in spike notes.

**Files:**
- Modify: `MDPrintView/Editor/LiveFormatStyler.swift` (add `apply(to:cursorAt:)` variant)
- Modify: `MDPrintView/Editor/MarkdownTextView.swift` (wire `textViewDidChangeSelection`)
- Test: `MDPrintViewTests/LiveFormatStylerTests.swift`

**Step 1: Failing tests**

```swift
@Suite("LiveFormatStyler — E3 (cursor-aware fold)", .serialized)
@MainActor
struct LiveFormatStylerE3Tests {

    @Test("bold marks are hidden when cursor outside span")
    func boldHiddenOutside() {
        let storage = NSTextStorage(string: "before **bold** after")
        LiveFormatStyler().apply(to: storage, cursorAt: 0)
        let leadingMark = storage.attributes(at: 7, effectiveRange: nil)
        #expect((leadingMark[.foregroundColor] as? NSColor) == .clear
            || (leadingMark[.foregroundColor] as? NSColor)?.alphaComponent == 0)
    }

    @Test("bold marks are revealed when cursor inside span")
    func boldRevealedInside() {
        let storage = NSTextStorage(string: "before **bold** after")
        LiveFormatStyler().apply(to: storage, cursorAt: 11) // inside "bold"
        let leadingMark = storage.attributes(at: 7, effectiveRange: nil)
        let color = leadingMark[.foregroundColor] as? NSColor
        // Should be either tertiary (faded, E2 style) or clear-not — definitely not transparent
        #expect(color != .clear)
        if let color { #expect(color.alphaComponent > 0) }
    }

    @Test("cursor at mark boundary reveals the mark")
    func cursorAtMarkBoundaryReveals() {
        let storage = NSTextStorage(string: "**bold**")
        LiveFormatStyler().apply(to: storage, cursorAt: 2) // cursor right after the leading **
        let leadingMark = storage.attributes(at: 0, effectiveRange: nil)
        let color = leadingMark[.foregroundColor] as? NSColor
        if let color { #expect(color.alphaComponent > 0) }
    }
}
```

**Step 2: Implement `apply(to:cursorAt:)`**

Add a new entry point that takes a cursor location:

```swift
func apply(to storage: NSTextStorage, cursorAt cursor: Int? = nil) {
    // Existing apply logic, but pass `cursor` into the per-markup apply.
    // When applying mark fading, check if cursor is inside markup's source range:
    //   - If inside → fade to tertiary (visible)
    //   - If outside → set to clear (hidden)
    //   - If no cursor → fall back to E2 behavior (tertiary always)
}
```

Helper:
```swift
private func isCursor(_ cursor: Int?, in range: NSRange) -> Bool {
    guard let cursor else { return false }
    return cursor >= range.location && cursor <= range.location + range.length
}
```

Apply pattern for Strong:
```swift
case is Strong:
    // ...bold trait...
    let inside = isCursor(cursor, in: range)
    let markColor: NSColor = inside ? .tertiaryLabelColor : .clear
    if range.length >= 4 {
        let leading = NSRange(location: range.location, length: 2)
        let trailing = NSRange(location: range.location + range.length - 2, length: 2)
        storage.addAttribute(.foregroundColor, value: markColor, range: leading)
        storage.addAttribute(.foregroundColor, value: markColor, range: trailing)
    }
```

**Step 3: Wire `textViewDidChangeSelection` in MarkdownTextView**

```swift
func textViewDidChangeSelection(_ notification: Notification) {
    guard mode == .hybrid,
          let textView = notification.object as? NSTextView,
          let storage = textView.textStorage else { return }
    let cursor = textView.selectedRange().location
    liveFormatStyler.apply(to: storage, cursorAt: cursor)
}
```

CRITICAL: this fires on EVERY cursor movement. It must NOT itself trigger another selection-changed event. Test for this; if we see infinite re-fire, throttle via DispatchQueue.main.async or a re-entry guard.

**Step 4: Build, test**

```
xcodebuild ... test 2>&1 | tail -10
```

Expected: 44 tests (41 + 3 E3).

**Step 5: Commit**

```bash
git add MDPrintView/Editor/LiveFormatStyler.swift MDPrintView/Editor/MarkdownTextView.swift MDPrintViewTests/LiveFormatStylerTests.swift
git commit -m "feat(green): LiveFormatStyler — cursor-aware mark fold/reveal (E3)"
```

---

## Task 8: E3 evaluation — checkpoint (the hard one)

Append to `docs/plans/2026-06-05-spike-notes.md`:

```markdown
## E3 evaluation (cursor-aware folding)

**Bar:** E2 bars + selection across folds selects expected source range; undo intact; ≥60fps cursor movement; no cursor-positioning glitches.

**Test results:**
- Cursor smoothly enters/exits styled span: [PASS / FAIL]
- Selection across folded marks selects the source range (not the displayed range): [PASS / FAIL]
- Backspace at the boundary of a folded mark: [describe behavior]
- Typing inside a styled span: [PASS / FAIL]
- Undo restores both content AND mark visibility: [PASS / FAIL]
- Performance feel on 10KB doc: [PASS / FAIL — qualitative]
- Performance feel on 50KB doc: [PASS / FAIL]
- Any "ghost space" issues from .clear color? [describe]

**Verdict:** [PASS proceed to E4 / FAIL — defer E3 to v1.1, ship E1+E2 in v1 as "Rich" mode]

**Notes:**
- ...
```

If E3 FAILS — that's a legitimate outcome. Don't force E4 if E3 didn't work. Stop spike, ship Rich-only.

Commit:

```bash
git add docs/plans/2026-06-05-spike-notes.md
git commit -m "docs: Week 3 spike — E3 evaluation"
```

---

## Task 9: Real-doc stress test (E4)

Only run if E3 verdict was PASS.

**Step 1: Construct a realistic large doc**

```bash
cat docs/plans/2026-06-01-MDPrintView-design.md \
    docs/plans/2026-06-01-MDPrintView-implementation.md \
    docs/plans/2026-06-02-MDPrintView-week2.md \
    docs/plans/2026-06-05-MDPrintView-week3-hybrid-spike.md \
    > /tmp/MDPrintView-stress.md
wc -c /tmp/MDPrintView-stress.md  # ~50KB expected
```

**Step 2: Open in app, hybrid mode, exercise it**

- Open the file
- Switch to Hybrid mode in the toolbar
- Type continuously for 60 seconds in the middle of the file
- Use arrow keys to move through dozens of styled spans
- Select large blocks across styled boundaries
- Cmd+Z / Cmd+Shift+Z to test undo

**Step 3: Record observations**

Append to spike notes:

```markdown
## E4 evaluation (real-doc stress)

**Bar:** E3 bars hold on 10–50KB docs.

**Test results:**
- Open 50KB doc to Hybrid mode: [time elapsed, lag perception]
- 60s of typing: [smooth / janky / hangs]
- Rapid cursor movement: [smooth / janky / glitches]
- Large selection across folds: [PASS / FAIL]
- Undo: [PASS / FAIL]
- Did anything crash? [yes/no, paste crash log path if yes]

**Verdict:** [PASS — hybrid ships in v1 / FAIL — ship E1+E2 only as "Rich" mode]
```

Commit:

```bash
git add docs/plans/2026-06-05-spike-notes.md
git commit -m "docs: Week 3 spike — E4 evaluation"
```

---

## Task 10: Write decision document

Create `docs/plans/2026-06-05-hybrid-mode-decision.md`:

```markdown
# MDPrintView Hybrid Editor Mode — v1 Inclusion Decision

**Date:** 2026-06-XX
**Spike commits:** <git range>
**Spike notes:** docs/plans/2026-06-05-spike-notes.md

## Decision

[ ONE of: ]
- ✅ Ship full hybrid mode (E1+E2+E3) in v1
- ◐ Ship "Rich" mode (E1+E2 — marks visible) in v1; defer fold/reveal to v1.1
- ✗ Defer hybrid mode entirely; ship Source mode only in v1

## Rationale

(2–4 sentences explaining why, with specific reference to which gate(s) passed or failed.)

## What ships in v1

- (List the editor capabilities that are part of v1)

## What defers to v1.1

- (List what didn't make the cut and why)

## Followups for the v1.1 work

- (Specific technical work that needs to happen if E3 or E4 was deferred)
```

Commit:

```bash
git add docs/plans/2026-06-05-hybrid-mode-decision.md
git commit -m "docs: hybrid mode v1 inclusion decision"
```

---

## Week 3 milestone

After all tasks (or after an early stop):
- ✅ EditorMode toggle infrastructure landed (regardless of outcome)
- ✅ Decision documented in `docs/plans/2026-06-05-hybrid-mode-decision.md`
- ✅ Whatever subset of hybrid (Full / Rich / None) is the choice for v1

If the choice is **Full** or **Rich**, the hybrid implementation already exists in code. If **None**, the EditorMode infrastructure stays but defaults to source mode — the toggle can be hidden behind a debug flag until v1.1 work resumes.

---

## Execution handoff

Plan complete. Two execution options:

**1. Subagent-Driven (this session)** — same pattern as Weeks 1–2: fresh subagent per task, evaluate at checkpoints, mark complete in TaskList. Best for this spike because the checkpoint evaluations need human judgment that's most efficient when I'm in the loop.

**2. Parallel Session (separate)** — open new session in dir, invoke `superpowers:executing-plans`, work through the doc. Less suited for spike work since checkpoint evaluations benefit from continuous context.

**Recommend Option 1**, same as Weeks 1–2.
