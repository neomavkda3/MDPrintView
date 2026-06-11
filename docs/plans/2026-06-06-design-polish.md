# MDPrintView Design Polish (Pre-Submission) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (or subagent-driven-development for same-session) to execute this plan task-by-task.

**Goal:** Land three small design improvements informed by Mobbin research — preview themes, editor font picker, and toolbar consolidation.

**Architecture:** No new architecture. Themes are body-class CSS swaps on the WebView. Font family extends the existing `AppSettings` + `SyntaxHighlighter` pattern. Toolbar consolidation collapses three-button groups into menu buttons (same pattern we already use for headings).

**Tech Stack:**
- SwiftUI Picker + Form (Settings)
- CSS body-class theming (preview pane)
- AppKit NSFont (editor font family)
- Swift Testing for the additions

**Reference docs:**
- Source proposal: `docs/plans/2026-06-06-design-update-from-mobbin.md`

**Axiom skills to invoke:** None required — these are SwiftUI/CSS edits within established patterns.

---

## Phasing overview

| Task | Theme | Effort |
|---|---|---|
| **A** | Preview themes (Original / Sepia / Quiet / Focus) | ~2 hours |
| **B** | Editor font family picker | ~1 hour |
| **C** | Toolbar consolidation (Lists + Code menus) | ~30 min |

Total: ~3.5 hours of focused work.

---

## Task A: Preview themes

**Files:**
- Modify: `MDPrintView/Preview/PreviewWebView.swift`
- Modify: `MDPrintView/Preview/Resources/preview.css`
- Modify: `MDPrintView/Views/DocumentView.swift`

**Step 1: Define `PreviewTheme` enum**

Add to `MDPrintView/Preview/PreviewWebView.swift`, near the existing `PreviewMode` enum:

```swift
enum PreviewTheme: String, CaseIterable, Identifiable {
    case original
    case sepia
    case quiet
    case focus

    var id: String { rawValue }

    var label: String {
        switch self {
        case .original: return "Original"
        case .sepia: return "Sepia"
        case .quiet: return "Quiet"
        case .focus: return "Focus"
        }
    }
}
```

**Step 2: Append theme parameter to PreviewWebView + carry through inject()**

Modify the `PreviewWebView` struct:

```swift
struct PreviewWebView: NSViewRepresentable {
    let html: String
    let mode: PreviewMode
    let theme: PreviewTheme
    let printController: PreviewPrintController
    // ...rest unchanged
```

Update `inject` to write theme as a second body class alongside mode:

```swift
fileprivate static func inject(html: String, mode: PreviewMode, theme: PreviewTheme, into webView: WKWebView) {
    let escaped = escape(html)
    let cls = "\(mode.rawValue) theme-\(theme.rawValue)"
    let js = """
    document.body.className = '\(cls)';
    document.getElementById('content').innerHTML = `\(escaped)`;
    if (window.renderMathInElement) { /* ...existing... */ }
    if (window.mermaid) {
        try {
            window.mermaid.initialize({
                startOnLoad: false,
                securityLevel: 'strict',
                theme: document.body.classList.contains('theme-focus') ? 'dark' : 'default'
            });
            window.mermaid.run({ querySelector: 'code.language-mermaid' });
        } catch(e) { console.error('Mermaid render failed:', e); }
    }
    """
    webView.evaluateJavaScript(js)
}
```

Update both call sites (`updateNSView` and Coordinator's `didFinish`) to pass the new param.

Update Coordinator to track `pendingTheme`:

```swift
@MainActor
final class Coordinator: NSObject, WKNavigationDelegate {
    var pendingHTML: String = ""
    var pendingMode: PreviewMode = .screen
    var pendingTheme: PreviewTheme = .original
    var templateReady: Bool = false

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        templateReady = true
        PreviewWebView.inject(html: pendingHTML, mode: pendingMode, theme: pendingTheme, into: webView)
    }
}
```

Update `makeNSView` to set `pendingTheme = theme`.

**Step 3: Add theme CSS to `preview.css`**

Append at the bottom of `MDPrintView/Preview/Resources/preview.css`:

```css
/* Reading themes — applied via body class swap in PreviewWebView.inject. */

body.theme-sepia {
    color: #5b4636;
    background: #f4ecd8;
}
body.theme-sepia code,
body.theme-sepia pre {
    background: rgba(91, 70, 54, 0.08);
    color: #5b4636;
}
body.theme-sepia a {
    color: #826144;
}

body.theme-quiet {
    color: #2e2e2e;
    background: #f5f5f0;
}
body.theme-quiet code,
body.theme-quiet pre {
    background: rgba(0, 0, 0, 0.04);
}

body.theme-focus {
    color: #e6e6e6;
    background: #1a1a1c;
}
body.theme-focus code,
body.theme-focus pre {
    background: rgba(255, 255, 255, 0.06);
    color: #d7d7d7;
}
body.theme-focus a {
    color: #6cb8ff;
}
body.theme-focus h1,
body.theme-focus h2 {
    border-bottom-color: rgba(255, 255, 255, 0.18);
}

/* theme-original has no overrides — it inherits the existing system color-scheme rules */
```

**Step 4: Add Picker in DocumentView**

Add state and Picker in `MDPrintView/Views/DocumentView.swift`:

```swift
@State private var previewTheme: PreviewTheme = .original
```

Inside the VStack above the preview pane, expand the existing mode-picker HStack:

```swift
HStack {
    Spacer(minLength: 0)
    Picker("", selection: $previewMode) {
        ForEach(PreviewMode.allCases) { Text($0.label).tag($0) }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .frame(maxWidth: 200)

    Menu {
        Picker("Theme", selection: $previewTheme) {
            ForEach(PreviewTheme.allCases) { Text($0.label).tag($0) }
        }
    } label: {
        Image(systemName: "paintpalette")
    }
    .menuStyle(.borderlessButton)
    .frame(width: 32)
    .help("Reading theme")
    .accessibilityLabel("Reading theme")
    .accessibilityIdentifier("preview.theme")

    Spacer(minLength: 0)
}
```

And pass `theme: previewTheme` into the `PreviewWebView(...)` constructor.

**Step 5: Build, test, smoke**

```bash
cd ~/MDPrintView
xcodegen generate 2>&1 | tail -1
xcodebuild -project MDPrintView.xcodeproj -scheme MDPrintView -destination 'platform=macOS' -configuration Debug build 2>&1 | tail -3
xcodebuild -project MDPrintView.xcodeproj -scheme MDPrintView -destination 'platform=macOS' -configuration Debug test 2>&1 | tail -3
./scripts/smoke.sh
```

Expected: BUILD SUCCEEDED, TEST SUCCEEDED (existing test count unchanged — no new tests because this is CSS/SwiftUI presentation), smoke PASS.

Manual smoke (visual, USER): open a doc, click the palette icon, cycle Original → Sepia → Quiet → Focus. Each should visibly change background + text + code-block colors in the preview pane.

**Step 6: Commit**

```bash
git add MDPrintView/Preview/PreviewWebView.swift MDPrintView/Preview/Resources/preview.css MDPrintView/Views/DocumentView.swift MDPrintView.xcodeproj/project.pbxproj
git commit -m "feat: preview themes (Original / Sepia / Quiet / Focus) via body-class CSS"
```

---

## Task B: Editor font family picker

**Files:**
- Modify: `MDPrintView/Models/AppSettings.swift`
- Modify: `MDPrintView/MDPrintViewApp.swift` (Settings view)
- Modify: `MDPrintView/Editor/SyntaxHighlighter.swift`
- Modify: `MDPrintView/Editor/MarkdownTextView.swift`
- Modify: `MDPrintView/Views/DocumentView.swift`
- Test: `MDPrintViewTests/SyntaxHighlighterTests.swift`

**Step 1: Add EditorFontFamily enum to AppSettings**

In `MDPrintView/Models/AppSettings.swift`, alongside `PageSize`:

```swift
enum EditorFontFamily: String, CaseIterable, Identifiable {
    case systemMono
    case systemSerif
    case systemSans

    var id: String { rawValue }

    var label: String {
        switch self {
        case .systemMono: return "System Mono"
        case .systemSerif: return "New York (Serif)"
        case .systemSans: return "SF Pro (Sans)"
        }
    }

    func nsFont(size: CGFloat) -> NSFont {
        switch self {
        case .systemMono:
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case .systemSerif:
            return NSFont(name: "NewYork", size: size) ?? NSFont.systemFont(ofSize: size)
        case .systemSans:
            return NSFont.systemFont(ofSize: size)
        }
    }
}
```

Add a stored property in `AppSettings`:

```swift
@ObservationIgnored
@AppStorage("editorFontFamily") private var storedEditorFontFamily: String = EditorFontFamily.systemMono.rawValue

var editorFontFamily: EditorFontFamily {
    get {
        access(keyPath: \.editorFontFamily)
        return EditorFontFamily(rawValue: storedEditorFontFamily) ?? .systemMono
    }
    set {
        withMutation(keyPath: \.editorFontFamily) { storedEditorFontFamily = newValue.rawValue }
    }
}
```

**Step 2: Failing test**

In `MDPrintViewTests/SyntaxHighlighterTests.swift`, append inside the suite:

```swift
@Test("custom font family is applied at the base font")
func customFontFamily() {
    let storage = NSTextStorage(string: "hello\n")
    SyntaxHighlighter(baseFontSize: 14, fontFamily: .systemSans).apply(to: storage)
    let font = storage.attributes(at: 0, effectiveRange: nil)[.font] as? NSFont
    // System sans is not monospaced.
    #expect(font?.fontDescriptor.symbolicTraits.contains(.monoSpace) == false)
}
```

Run:
```bash
xcodebuild ... test 2>&1 | tail -5
```

Expected: compile error `extra argument 'fontFamily' in call`.

Commit RED:
```bash
git add MDPrintViewTests/SyntaxHighlighterTests.swift MDPrintView/Models/AppSettings.swift
git commit -m "test(red): SyntaxHighlighter takes a fontFamily parameter"
```

**Step 3: Extend SyntaxHighlighter**

In `MDPrintView/Editor/SyntaxHighlighter.swift`, change the init:

```swift
@MainActor
struct SyntaxHighlighter {
    let baseFontSize: CGFloat
    let fontFamily: EditorFontFamily

    init(baseFontSize: CGFloat = 14, fontFamily: EditorFontFamily = .systemMono) {
        self.baseFontSize = baseFontSize
        self.fontFamily = fontFamily
    }

    private var headingSizes: [CGFloat] {
        [baseFontSize + 8, baseFontSize + 5, baseFontSize + 3, baseFontSize + 1, baseFontSize, baseFontSize]
    }

    func apply(to storage: NSTextStorage) {
        // ...existing logic, but replace
        //   storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: baseFontSize, weight: .regular), range: fullRange)
        // with:
        storage.addAttribute(.font, value: fontFamily.nsFont(size: baseFontSize), range: fullRange)
        // and in the heading switch case use:
        //   storage.addAttribute(.font, value: bold(fontFamily.nsFont(size: headingSizes[idx])), range: range)
        // (extract `bold(_:)` helper that calls fontDescriptor.withSymbolicTraits(.bold))
        // ...
    }
}
```

Add the bold helper:

```swift
private func bold(_ font: NSFont) -> NSFont {
    var traits = font.fontDescriptor.symbolicTraits
    traits.insert(.bold)
    let desc = font.fontDescriptor.withSymbolicTraits(traits)
    return NSFont(descriptor: desc, size: font.pointSize) ?? font
}
```

Run test, expect PASS + the existing 4 highlighter tests still pass.

**Step 4: Wire through MarkdownTextView and DocumentView**

In `MarkdownTextView`, add `editorFontFamily: EditorFontFamily` parameter; pass into `Coordinator.fontFamily`; use in `applyStyling`.

In `DocumentView`, pass `editorFontFamily: settings.editorFontFamily`.

**Step 5: Add picker to Settings**

In `MDPrintViewApp.swift`'s `SettingsView`:

```swift
Section("Editor") {
    HStack {
        Text("Font size")
        Slider(value: $settings.editorFontSize, in: 10...24, step: 1)
        Text("\(Int(settings.editorFontSize)) pt")
            .monospacedDigit()
            .frame(width: 50, alignment: .trailing)
    }
    Picker("Font family", selection: $settings.editorFontFamily) {
        ForEach(EditorFontFamily.allCases) { Text($0.label).tag($0) }
    }
}
```

**Step 6: Build + test + smoke + commit GREEN**

```bash
xcodebuild ... test 2>&1 | tail -3
./scripts/smoke.sh

git add MDPrintView/Models/AppSettings.swift \
        MDPrintView/Editor/SyntaxHighlighter.swift \
        MDPrintView/Editor/MarkdownTextView.swift \
        MDPrintView/Views/DocumentView.swift \
        MDPrintView/MDPrintViewApp.swift \
        MDPrintViewTests/SyntaxHighlighterTests.swift
git commit -m "feat(green): editor font family picker (Mono / Serif / Sans) via AppSettings"
```

---

## Task C: Toolbar consolidation

**Files:**
- Modify: `MDPrintView/Editor/EditorToolbar.swift`

**Step 1: Collapse list trio into a Menu**

Replace the three separate List buttons:

```swift
Button { controller.insertBullet() } label: { Image(systemName: "list.bullet") }
    ...
Button { controller.insertNumbered() } label: { Image(systemName: "list.number") }
    ...
Button { controller.insertTask() } label: { Image(systemName: "checklist") }
    ...
```

With one Menu:

```swift
Menu {
    Button("Bullet list") { controller.insertBullet() }
    Button("Numbered list") { controller.insertNumbered() }
    Button("Task list") { controller.insertTask() }
} label: {
    Image(systemName: "list.bullet.indent")
}
.help("Lists")
.accessibilityLabel("Lists")
.accessibilityIdentifier("toolbar.lists")
```

**Step 2: Collapse code/mermaid into a Menu**

Replace:

```swift
Button { controller.toggleInlineCode() } label: { Image(systemName: "chevron.left.forwardslash.chevron.right") }
    ...
Button { controller.insertCodeBlock() } label: { Image(systemName: "curlybraces") }
    ...
Button { controller.openMermaidEditor() } label: { Image(systemName: "chart.xyaxis.line") }
    ...
```

With:

```swift
Menu {
    Button("Inline code") { controller.toggleInlineCode() }
    Button("Code block") { controller.insertCodeBlock() }
    Divider()
    Button("Mermaid diagram…") { controller.openMermaidEditor() }
        .keyboardShortcut("m", modifiers: [.command, .shift])
} label: {
    Image(systemName: "chevron.left.forwardslash.chevron.right")
}
.help("Code")
.accessibilityLabel("Code")
.accessibilityIdentifier("toolbar.code")
```

Keep the `Cmd+Shift+M` shortcut directly bound to Mermaid via the Menu item's `.keyboardShortcut`. The link button (Cmd+K) stays as its own button between Heading and Code.

**Step 3: Build, test, smoke**

```bash
xcodebuild ... build 2>&1 | tail -3
xcodebuild ... test 2>&1 | tail -3
./scripts/smoke.sh
```

Manual smoke (USER): toolbar now shows: `[Mode]  [B I S] | [Heading▾] | [Link] | [Lists▾] [Code▾]` — cleaner. Verify Cmd+Shift+M still opens Mermaid editor.

**Step 4: Commit**

```bash
git add MDPrintView/Editor/EditorToolbar.swift
git commit -m "feat: consolidate toolbar — Lists and Code groups become menu buttons"
```

---

## Polish milestone

After all 3 tasks:
- ✅ Preview themes (4 presets — Original / Sepia / Quiet / Focus)
- ✅ Editor font family picker (System Mono / NY Serif / SF Pro Sans)
- ✅ Toolbar reduced from 13 to 9 visible chips (7 buttons + 2 menus, still bold/italic/strike/heading menu/link/lists menu/code menu)
- ✅ Tests still pass (1 new SyntaxHighlighter test)
- ✅ Smoke passes

---

## Execution handoff

Plan complete. Two execution options:

**1. Subagent-Driven (this session)** — same pattern as Weeks 1–4.
**2. Parallel Session (separate)** — open new session, `superpowers:executing-plans`.

Recommend **option 1**.
