# Typography Controls Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add user-controllable text color to the editor and preview panes, plus a preview-pane "Aa" popover consolidating theme + font size + text color into one live-applying control.

**Architecture:** Four new persisted fields on `AppSettings` (`@AppStorage`-backed hex strings and enums). Editor color reaches `SyntaxHighlighter` via a new `baseTextColor` init param that overrides only prose runs (code/heading/link colors stay). Preview color + size reach `PreviewWebView`'s `WKWebView` as an inline `style=` attribute on `#content`, which beats theme selectors without needing `!important`. Reusable `SwatchStrip` SwiftUI component drives the picker UI in both places.

**Tech Stack:** SwiftUI (`@Observable`, `@AppStorage`), AppKit (`NSColor`, `NSColorPanel`), TextKit 2 via `NSTextStorage`, WebKit `evaluateJavaScript`. Test framework: swift-testing.

**Design doc:** `docs/plans/2026-07-16-typography-controls-design.md` (already committed on `main` at `52b92b9`).

**Branch:** `feature/typography-controls` in `.worktrees/typography-controls`.

**Baseline before start:** 122 tests, all green. Every task ends with tests green.

---

## Task 1: `HexColor` helper

Round-trip between `String` (hex `"#RRGGBB"`) and `NSColor`. Isolates the parsing/formatting so no callsite has to think about it.

**Files:**
- Create: `MDPrintView/Models/HexColor.swift`
- Test: `MDPrintViewTests/HexColorTests.swift`

**Step 1: Write the failing tests**

Create `MDPrintViewTests/HexColorTests.swift`:

```swift
import Testing
import AppKit
@testable import MDPrintView

@Suite("HexColor")
struct HexColorTests {

    @Test("round-trip preserves the color")
    func roundTrip() {
        let original = "#5B4636"
        let color = HexColor.nsColor(from: original)
        #expect(color != nil)
        #expect(HexColor.hex(from: color!) == original)
    }

    @Test("nil hex → nil color")
    func nilInput() {
        #expect(HexColor.nsColor(from: nil) == nil)
    }

    @Test("empty string → nil")
    func emptyInput() {
        #expect(HexColor.nsColor(from: "") == nil)
    }

    @Test("missing # is accepted")
    func noHashPrefix() {
        let color = HexColor.nsColor(from: "5B4636")
        #expect(color != nil)
    }

    @Test("wrong length rejected")
    func wrongLength() {
        #expect(HexColor.nsColor(from: "#ABC") == nil)
        #expect(HexColor.nsColor(from: "#ABCDEFG") == nil)
    }

    @Test("non-hex characters rejected")
    func invalidChars() {
        #expect(HexColor.nsColor(from: "#XYZXYZ") == nil)
    }

    @Test("hex output is always uppercase 7 chars starting with #")
    func hexFormatting() {
        let hex = HexColor.hex(from: .black)
        #expect(hex.hasPrefix("#"))
        #expect(hex.count == 7)
        #expect(hex == hex.uppercased())
    }
}
```

**Step 2: Run tests, verify they fail**

```sh
cd /Users/cmagsisi/Dev/mdview/.worktrees/typography-controls
xcodegen && xcodebuild -project MDPrintView.xcodeproj -scheme MDPrintView \
    -destination 'platform=macOS' -configuration Debug test \
    -only-testing:MDPrintViewTests/HexColorTests 2>&1 | tail -5
```

Expected: compile error — `HexColor` doesn't exist.

**Step 3: Implement `HexColor`**

Create `MDPrintView/Models/HexColor.swift`:

```swift
import AppKit

/// Hex-string persistence for user-picked colors. `nil` means "no override,
/// use the dynamic system default." Round-trips through `@AppStorage` as a
/// `String?`, so it works with the codebase's existing settings pattern.
enum HexColor {

    /// Parse a `#RRGGBB` (or `RRGGBB`) hex string into a sRGB `NSColor`.
    /// Returns nil for nil / empty / malformed input.
    static func nsColor(from hex: String?) -> NSColor? {
        guard var s = hex, !s.isEmpty else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >>  8) & 0xFF) / 255.0
        let b = CGFloat( value        & 0xFF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }

    /// Emit `#RRGGBB` from any `NSColor`. Converts to sRGB first so device-
    /// dependent colors (like `NSColor.textColor`) still produce a usable
    /// hex value.
    static func hex(from color: NSColor) -> String {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let r = Int(round(rgb.redComponent   * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent  * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
```

**Step 4: Regenerate project, run tests, verify pass**

```sh
xcodegen && xcodebuild ... -only-testing:MDPrintViewTests/HexColorTests
```

Expected: 7 tests pass.

**Step 5: Commit**

```sh
git add MDPrintView/Models/HexColor.swift MDPrintViewTests/HexColorTests.swift \
        MDPrintView.xcodeproj/project.pbxproj
git commit -m "feat: HexColor helper for round-tripping user-picked colors

Isolates hex parsing/formatting so callsites downstream (AppSettings,
SwatchStrip) never touch NSColor's channel APIs directly. String? in,
NSColor? out; NSColor in, hex String out via sRGB. nil input means
\"no override — use the system default,\" matching AppStorage's storage
model for optional strings.

7 tests: round-trip, nil/empty rejection, missing-#, wrong-length,
non-hex chars, output format."
```

---

## Task 2: `AppSettings` — four new persisted fields

Add `previewTheme`, `previewFontSize`, `previewTextColor`, `editorTextColor` following the existing `@ObservationIgnored @AppStorage` + computed property pattern (see `AppSettings.swift:114-208` for how the existing fields do it).

**Files:**
- Modify: `MDPrintView/Models/AppSettings.swift`
- Test: (no dedicated test — AppStorage-backed properties are exercised end-to-end via later tasks; a unit test that pokes UserDefaults would be brittle)

**Step 1: Add the four fields**

Append to `AppSettings` class (after `editorCustomFontFamily`, before `applyAppearanceToApp()`):

```swift
    @ObservationIgnored
    @AppStorage("previewTheme") private var storedPreviewTheme: String = PreviewTheme.original.rawValue

    /// App-level preview theme. Promoted from per-window `@State` to a
    /// persisted setting when the Aa popover consolidated all preview
    /// appearance controls.
    var previewTheme: PreviewTheme {
        get {
            access(keyPath: \.previewTheme)
            return PreviewTheme(rawValue: storedPreviewTheme) ?? .original
        }
        set {
            withMutation(keyPath: \.previewTheme) { storedPreviewTheme = newValue.rawValue }
        }
    }

    @ObservationIgnored
    @AppStorage("previewFontSize") private var storedPreviewFontSize: Double = 16

    /// 12–24 pt slider on the preview Aa popover.
    var previewFontSize: Double {
        get { access(keyPath: \.previewFontSize); return storedPreviewFontSize }
        set { withMutation(keyPath: \.previewFontSize) { storedPreviewFontSize = newValue } }
    }

    @ObservationIgnored
    @AppStorage("previewTextColor") private var storedPreviewTextColor: String = ""

    /// Empty string means "System default — theme CSS wins." Non-empty
    /// value is a `#RRGGBB` hex. `@AppStorage` doesn't support `String?`
    /// directly so we use `""` as the sentinel and expose `String?` publicly.
    var previewTextColor: String? {
        get {
            access(keyPath: \.previewTextColor)
            return storedPreviewTextColor.isEmpty ? nil : storedPreviewTextColor
        }
        set {
            withMutation(keyPath: \.previewTextColor) {
                storedPreviewTextColor = newValue ?? ""
            }
        }
    }

    @ObservationIgnored
    @AppStorage("editorTextColor") private var storedEditorTextColor: String = ""

    /// Same "" ↔ nil sentinel as `previewTextColor`. Non-nil value overrides
    /// the base prose color in `SyntaxHighlighter`; syntax colors (headings,
    /// code, links) stay untouched.
    var editorTextColor: String? {
        get {
            access(keyPath: \.editorTextColor)
            return storedEditorTextColor.isEmpty ? nil : storedEditorTextColor
        }
        set {
            withMutation(keyPath: \.editorTextColor) {
                storedEditorTextColor = newValue ?? ""
            }
        }
    }
```

**Step 2: Verify existing tests still pass**

```sh
xcodegen && xcodebuild ... test 2>&1 | grep 'Test run'
```

Expected: `122 tests ... passed`. This task adds no new tests — behavior is unchanged until later tasks read the fields.

**Step 3: Commit**

```sh
git add MDPrintView/Models/AppSettings.swift MDPrintView.xcodeproj/project.pbxproj
git commit -m "feat: AppSettings storage for typography controls

Four new @AppStorage-backed fields: previewTheme (was per-window @State),
previewFontSize (default 16), previewTextColor (hex or nil), editorTextColor
(hex or nil). Optional-hex fields use \"\" as the sentinel because
@AppStorage doesn't support String? directly.

No behavior change yet — these are read by later tasks."
```

---

## Task 3: Promote `previewTheme` from per-window `@State` to `AppSettings`

`DocumentView.swift` currently declares `@State private var previewTheme: PreviewTheme = .original` (line 15). Each window can be in a different theme. Design decision: consolidate into `AppSettings` so all windows and future launches share the theme (called out in the design doc as an accidental capability we're removing).

**Files:**
- Modify: `MDPrintView/Views/DocumentView.swift`

**Step 1: Replace `@State` with environment-derived binding**

In `DocumentView`, delete:
```swift
@State private var previewTheme: PreviewTheme = .original
```

The existing `Menu {...}` block that uses `$previewTheme` needs to bind to `$settings.previewTheme`. Convert `settings` to `@Bindable` (it's already used that way for other bindings in the same file — see the `@Bindable var settings = settings` inside `body`). Change the picker binding:

```swift
Picker("Theme", selection: $settings.previewTheme) {
    ForEach(PreviewTheme.allCases) { Text($0.label).tag($0) }
}
```

And the `PreviewWebView` construction — change `theme: previewTheme` to `theme: settings.previewTheme`.

**Step 2: Build + test**

```sh
xcodebuild ... test 2>&1 | grep -E 'Test run|error:'
```

Expected: 122 tests still pass. No new tests — this is a behavior-preserving move (theme still defaults to `.original`; the picker still works; the preview still re-renders on change).

**Step 3: Commit**

```sh
git add MDPrintView/Views/DocumentView.swift
git commit -m "refactor: move previewTheme from per-window @State to AppSettings

Preps the Aa popover in a later task: theme belongs in the same store as
the size + color knobs it lives alongside. Behavior change is small —
opening a second window used to inherit whichever theme was chosen there
last time; now every window shares the same theme and it persists across
launches."
```

---

## Task 4: `SyntaxHighlighter` accepts `baseTextColor` override

`SyntaxHighlighter.swift:31` currently sets prose color to `NSColor.textColor` unconditionally. Add an init param that overrides just that line — code/heading/link colors keep their own semantic colors (`.secondaryLabelColor`, bold font, `.linkColor`) so the highlighting stays readable regardless of override.

**Files:**
- Modify: `MDPrintView/Editor/SyntaxHighlighter.swift`
- Test: `MDPrintViewTests/SyntaxHighlighterTests.swift`

**Step 1: Write the failing tests**

Append two tests to `MDPrintViewTests/SyntaxHighlighterTests.swift`:

```swift
    @Test("baseTextColor override applies to plain prose runs")
    func baseTextColorAppliesToProse() {
        let storage = NSTextStorage(string: "hello world")
        SyntaxHighlighter(baseTextColor: .red).apply(to: storage)
        var range = NSRange()
        let color = storage.attribute(.foregroundColor, at: 0, effectiveRange: &range) as? NSColor
        #expect(color == .red)
    }

    @Test("baseTextColor override does NOT recolor code runs")
    func baseTextColorSkipsCode() {
        // "hello `code`" — the code span keeps NSColor.secondaryLabelColor,
        // NOT the override.
        let storage = NSTextStorage(string: "hello `code`")
        SyntaxHighlighter(baseTextColor: .red).apply(to: storage)
        // Position 7 is inside the code span.
        let color = storage.attribute(.foregroundColor, at: 7, effectiveRange: nil) as? NSColor
        #expect(color == .secondaryLabelColor)
    }
```

Run them:
```sh
xcodebuild ... -only-testing:MDPrintViewTests/SyntaxHighlighterTests 2>&1 | tail -5
```

Expected: compile error — `baseTextColor:` isn't a valid parameter yet.

**Step 2: Add the parameter and use it**

In `SyntaxHighlighter.swift`, change:

```swift
let baseFontSize: CGFloat
let fontFamily: EditorFontFamily

init(baseFontSize: CGFloat = 14, fontFamily: EditorFontFamily = .systemMono) {
    self.baseFontSize = baseFontSize
    self.fontFamily = fontFamily
}
```

To:

```swift
let baseFontSize: CGFloat
let fontFamily: EditorFontFamily
let baseTextColor: NSColor?

init(baseFontSize: CGFloat = 14,
     fontFamily: EditorFontFamily = .systemMono,
     baseTextColor: NSColor? = nil) {
    self.baseFontSize = baseFontSize
    self.fontFamily = fontFamily
    self.baseTextColor = baseTextColor
}
```

And in `apply(to:)`, change line 31 from:

```swift
storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)
```

To:

```swift
storage.addAttribute(.foregroundColor,
                     value: baseTextColor ?? NSColor.textColor,
                     range: fullRange)
```

**Step 3: Run tests, verify pass**

Expected: SyntaxHighlighter suite green including the two new tests.

**Step 4: Commit**

```sh
git add MDPrintView/Editor/SyntaxHighlighter.swift MDPrintViewTests/SyntaxHighlighterTests.swift
git commit -m "feat: SyntaxHighlighter baseTextColor override for prose runs

New optional init param overrides the base prose color. Syntax-colored
runs (headings, code, links) are unchanged — overriding those would
defeat the point of highlighting. nil default preserves the existing
NSColor.textColor behavior (dynamic Light/Dark).

2 new tests: override reaches prose, override does NOT touch code spans."
```

---

## Task 5: Wire `editorTextColor` into `MarkdownTextView`

`MarkdownTextView.Coordinator` currently constructs `SyntaxHighlighter(baseFontSize:fontFamily:)` in `applyStyling`. We need to also pass the color from `AppSettings` and trigger a restyle when the color changes.

**Files:**
- Modify: `MDPrintView/Editor/MarkdownTextView.swift`

**Step 1: Thread the color through `MarkdownTextView`**

Add a new stored property:

```swift
let editorTextColor: String?    // hex or nil
```

At the top of `MarkdownTextView` (alongside `editorFontSize`, `editorFontFamily`).

**Step 2: Store it on the Coordinator**

Add on `Coordinator`:

```swift
var textColor: NSColor?
```

Wire in `init` (accept as a param), and update the `Coordinator` init call in `makeCoordinator` to pass `HexColor.nsColor(from: editorTextColor)`.

**Step 3: Pass to the highlighter**

In `Coordinator.applyStyling` (or wherever `SyntaxHighlighter(...)` is constructed — there are TWO places, one for the debounced schedule and one for the immediate path). Both need `baseTextColor: textColor`.

**Step 4: Restyle on change**

In `MarkdownTextView.updateNSView`, add a `textColorChanged` check alongside the existing `modeChanged` / `fontSizeChanged` / `fontFamilyChanged` checks; when true, call `applyStylingImmediately`.

**Step 5: Wire the caller**

In `DocumentView.swift` where `MarkdownTextView(text:controller:mode:editorFontSize:editorFontFamily:)` is constructed, add `editorTextColor: settings.editorTextColor`.

**Step 6: Build + test**

```sh
xcodebuild ... test 2>&1 | grep 'Test run'
```

Expected: 124 tests pass (122 existing + 2 from Task 4). No new tests here — behavior is already covered by SyntaxHighlighter tests plus visual verification comes at the end.

**Step 7: Commit**

```sh
git add MDPrintView/Editor/MarkdownTextView.swift MDPrintView/Views/DocumentView.swift
git commit -m "feat: pipe editorTextColor from AppSettings into the highlighter

MarkdownTextView takes an editorTextColor String? parameter, converts it
via HexColor, threads through Coordinator, and passes to
SyntaxHighlighter.baseTextColor on both the debounced and immediate
styling paths. Change detection in updateNSView triggers a restyle when
the color changes."
```

---

## Task 6: `SwatchStrip` reusable SwiftUI component

Row of circular color swatches with a "Custom…" chip. Reused in Settings (Editor row) and the Aa popover (twice — theme and text-color rows aren't identical but share the "selected has a ring" logic; keep this task scoped to the text-color variant, do theme as a separate small view in Task 9).

**Files:**
- Create: `MDPrintView/Views/SwatchStrip.swift`
- Test: `MDPrintViewTests/SwatchStripTests.swift`

**Step 1: Sketch the swatches enum**

Define in `SwatchStrip.swift`:

```swift
import SwiftUI
import AppKit

/// One preset swatch. `hex == nil` means "System default — no override."
struct TextColorSwatch: Hashable, Identifiable {
    let id: String
    let label: String
    let hex: String?

    static let system:       Self = .init(id: "system",       label: "System",        hex: nil)
    static let warmInk:      Self = .init(id: "warm-ink",     label: "Warm ink",      hex: "#5B4636")
    static let highContrast: Self = .init(id: "high-contrast", label: "High contrast", hex: "#111111")

    static let presets: [Self] = [.system, .warmInk, .highContrast]
}
```

**Step 2: Write failing tests for selection logic**

Create `MDPrintViewTests/SwatchStripTests.swift`:

```swift
import Testing
@testable import MDPrintView

@Suite("TextColorSwatch")
struct SwatchStripTests {

    @Test("nil hex matches System preset")
    func nilMatchesSystem() {
        let selection: String? = nil
        #expect(TextColorSwatch.matching(hex: selection) == .system)
    }

    @Test("warm ink hex matches warmInk preset")
    func warmInkMatches() {
        #expect(TextColorSwatch.matching(hex: "#5B4636") == .warmInk)
    }

    @Test("case-insensitive hex still matches")
    func caseInsensitive() {
        #expect(TextColorSwatch.matching(hex: "#5b4636") == .warmInk)
    }

    @Test("unknown hex matches nothing (→ Custom is selected)")
    func customCase() {
        #expect(TextColorSwatch.matching(hex: "#123456") == nil)
    }
}
```

Run — expect fail: `matching(hex:)` doesn't exist yet.

**Step 3: Implement `matching(hex:)`**

Extend `TextColorSwatch`:

```swift
extension TextColorSwatch {
    /// The preset that a stored hex value corresponds to, or nil if the
    /// value is a user-picked custom color.
    static func matching(hex: String?) -> Self? {
        let target = hex?.uppercased()
        return presets.first { $0.hex?.uppercased() == target }
    }
}
```

Run — expect pass.

**Step 4: Build the view**

Append to `SwatchStrip.swift`:

```swift
struct SwatchStrip: View {
    @Binding var selection: String?          // hex or nil
    let onCustomPicked: (NSColor) -> Void    // called when Custom… returns a color

    @State private var showColorPicker: Bool = false
    @State private var customColor: Color = .black

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TextColorSwatch.presets) { swatch in
                SwatchCircle(
                    color: swatch.color(inEnvironment: .automatic),
                    isSelected: TextColorSwatch.matching(hex: selection) == swatch,
                    isSystemDefault: swatch == .system
                )
                .onTapGesture { selection = swatch.hex }
                .help(swatch.label)
                .accessibilityLabel(swatch.label)
            }
            // Custom… — a SwiftUI ColorPicker styled as a chip. It opens
            // NSColorPanel under the hood; the label is hidden so we control
            // the chrome ourselves.
            ColorPicker(selection: $customColor, supportsOpacity: false) {
                Text("Custom…")
                    .font(.caption)
            }
            .labelsHidden()
            .onChange(of: customColor) { _, new in
                let ns = NSColor(new)
                selection = HexColor.hex(from: ns)
                onCustomPicked(ns)
            }
        }
    }
}

private struct SwatchCircle: View {
    let color: Color
    let isSelected: Bool
    let isSystemDefault: Bool

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 22, height: 22)
            .overlay(
                Circle().strokeBorder(
                    isSelected ? Color.accentColor : Color.secondary.opacity(0.3),
                    lineWidth: isSelected ? 2 : 1
                )
            )
            .overlay(
                // System swatch shows a split-color hint so users know
                // it isn't a specific color.
                Group {
                    if isSystemDefault {
                        Circle()
                            .trim(from: 0, to: 0.5)
                            .fill(Color.black.opacity(0.15))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 22, height: 22)
                    }
                }
            )
    }
}

private extension TextColorSwatch {
    /// The color displayed for this swatch. System uses labelColor so it
    /// tracks Light/Dark; other presets use their fixed hex.
    func color(inEnvironment scheme: ColorScheme?) -> Color {
        if let hex, let ns = HexColor.nsColor(from: hex) {
            return Color(nsColor: ns)
        }
        return Color(nsColor: .labelColor)
    }
}
```

**Step 5: Regenerate + test**

```sh
xcodegen && xcodebuild ... test 2>&1 | grep 'Test run'
```

Expected: 128 tests pass.

**Step 6: Commit**

```sh
git add MDPrintView/Views/SwatchStrip.swift MDPrintViewTests/SwatchStripTests.swift \
        MDPrintView.xcodeproj/project.pbxproj
git commit -m "feat: SwatchStrip component for preset text colors + Custom…

Reusable HStack of TextColorSwatch presets (System / Warm ink / High
contrast) plus a Custom… ColorPicker chip. Selection state binds to
String? (hex or nil); Custom hex is auto-derived from NSColor via
HexColor. System swatch shows a split-tone hint so users can tell it
isn't a specific color.

4 tests on TextColorSwatch.matching(hex:) — the selection-detection
logic that decides which swatch draws the ring."
```

---

## Task 7: Add "Text color" row to Settings Editor section

Slot the `SwatchStrip` into `SettingsView` under the existing font-family row.

**Files:**
- Modify: `MDPrintView/MDPrintViewApp.swift` (the private `SettingsView` at the bottom)

**Step 1: Add the row**

In `SettingsView.body`, inside `Section("Editor") { … }`, append after the font-family HStack:

```swift
HStack {
    Text("Text color")
    Spacer()
    SwatchStrip(selection: $settings.editorTextColor, onCustomPicked: { _ in })
}
```

**Step 2: Bump the sheet height slightly**

Change the frame at the bottom of the view from `height: 460` to `height: 490`.

**Step 3: Build + smoke-test the Settings sheet manually**

```sh
xcodebuild ... build 2>&1 | grep -E 'BUILD|error:' | tail -3
```

Expected: `BUILD SUCCEEDED`. No new automated tests — visual verification comes at the end.

**Step 4: Commit**

```sh
git add MDPrintView/MDPrintViewApp.swift
git commit -m "feat: Text color row in Settings → Editor

Slots the SwatchStrip in under the existing font-family picker. Bumps
the settings sheet height 460 → 490 to accommodate."
```

---

## Task 8: `PreviewWebView` inline-style injection

Add font-size + color to the setBody step in `PreviewWebView.inject`. Applied as an inline `style=` attribute on `#content` — beats theme selector specificity without `!important`.

**Files:**
- Modify: `MDPrintView/Preview/PreviewWebView.swift`

**Step 1: Thread the two new values through**

Add to `PreviewWebView`:

```swift
let fontSize: Double
let textColor: String?    // hex or nil
```

Update the `Coordinator` to track `pendingFontSize` and `pendingTextColor`; update `makeNSView` and `updateNSView` to write them in.

**Step 2: Extend `inject` to write the inline style**

In `PreviewWebView.inject`, after the existing `document.getElementById('content').innerHTML = ...` line, add:

```swift
let styleParts: [String] = [
    "font-size:\(Int(fontSize))pt",
    textColor.map { "color:\($0)" }
].compactMap { $0 }
let contentStyle = styleParts.joined(separator: ";")
let setStyleJS = """
try {
    document.getElementById('content').setAttribute('style', '\(contentStyle)');
} catch(e) { console.error('style attribute set failed:', e); }
"""
webView.evaluateJavaScript(setStyleJS) { _, error in
    if let error { print("[MDPrintView] setStyle error:", error) }
}
```

Note the `inject` function currently takes `(html:, mode:, theme:, into:)` — update its signature to `(html:, mode:, theme:, fontSize:, textColor:, into:)` and update the two callers (`updateNSView` and the didFinish callback).

**Step 3: Build**

```sh
xcodebuild ... build 2>&1 | grep -E 'BUILD|error:' | tail -3
```

Expected: `BUILD SUCCEEDED`.

**Step 4: Commit**

```sh
git add MDPrintView/Preview/PreviewWebView.swift
git commit -m "feat: preview font-size + text-color injection via inline #content style

Both values render into the style= attribute on #content on every setBody
pass. Inline attributes beat body.theme-* selectors without needing
!important, which would cascade poorly if we add more layers later.
Empty color → attribute omits the color clause → theme's CSS wins.
That IS the \"System default\" behavior — no branch needed."
```

---

## Task 9: Aa toolbar button + `PreviewAppearancePopover`

Replace the existing paintpalette `Menu` in `DocumentView.swift` with an `Aa` button that opens a popover containing theme + size + color rows. Wire `PreviewWebView` to receive the new values from `settings`.

**Files:**
- Create: `MDPrintView/Views/PreviewAppearancePopover.swift`
- Modify: `MDPrintView/Views/DocumentView.swift`

**Step 1: Create the popover**

```swift
import SwiftUI

struct PreviewAppearancePopover: View {
    @Environment(AppSettings.self) private var settings
    @State private var showsPicker: Bool = false

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 14) {
            row("Theme") {
                HStack(spacing: 8) {
                    ForEach(PreviewTheme.allCases) { theme in
                        ThemeSwatch(theme: theme,
                                    isSelected: settings.previewTheme == theme)
                            .onTapGesture { settings.previewTheme = theme }
                            .help(theme.label)
                    }
                }
            }
            row("Font size") {
                HStack(spacing: 6) {
                    Image(systemName: "textformat.size.smaller")
                        .foregroundStyle(.secondary)
                    Slider(value: $settings.previewFontSize, in: 12...24, step: 1)
                    Image(systemName: "textformat.size.larger")
                        .foregroundStyle(.secondary)
                    Text("\(Int(settings.previewFontSize)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
            row("Text color") {
                SwatchStrip(selection: $settings.previewTextColor, onCustomPicked: { _ in })
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ThemeSwatch: View {
    let theme: PreviewTheme
    let isSelected: Bool

    var body: some View {
        // Split-color circle: top half = theme background, bottom half = theme text.
        Circle()
            .fill(bg)
            .frame(width: 22, height: 22)
            .overlay(
                Circle()
                    .trim(from: 0, to: 0.5)
                    .fill(fg)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 22, height: 22)
            )
            .overlay(
                Circle().strokeBorder(
                    isSelected ? Color.accentColor : Color.secondary.opacity(0.3),
                    lineWidth: isSelected ? 2 : 1
                )
            )
            .accessibilityLabel(theme.label)
    }

    private var bg: Color {
        switch theme {
        case .original: return Color(nsColor: .textBackgroundColor)
        case .sepia:    return Color(red: 0.957, green: 0.925, blue: 0.847)
        case .quiet:    return Color(red: 0.961, green: 0.961, blue: 0.941)
        case .focus:    return Color(red: 0.102, green: 0.102, blue: 0.110)
        }
    }
    private var fg: Color {
        switch theme {
        case .original: return Color(nsColor: .labelColor)
        case .sepia:    return Color(red: 0.357, green: 0.275, blue: 0.212)
        case .quiet:    return Color(red: 0.180, green: 0.180, blue: 0.180)
        case .focus:    return Color(red: 0.902, green: 0.902, blue: 0.902)
        }
    }
}
```

**Step 2: Replace the paintpalette in `DocumentView`**

Find the block in `DocumentView.swift` that contains:

```swift
Menu {
    Picker("Theme", selection: $settings.previewTheme) { ... }
} label: {
    Image(systemName: "paintpalette")
}
```

Replace with:

```swift
@State private var isAaOpen: Bool = false
...
Button {
    isAaOpen.toggle()
} label: {
    Image(systemName: "textformat.size")
}
.buttonStyle(.borderless)
.frame(width: 36)
.help("Preview appearance")
.accessibilityLabel("Preview appearance")
.accessibilityIdentifier("preview.aa")
.popover(isPresented: $isAaOpen, arrowEdge: .top) {
    PreviewAppearancePopover()
        .environment(settings)
}
```

Note: `isAaOpen` needs to be a `@State` at the top of `DocumentView`.

**Step 3: Pass font-size + text-color into `PreviewWebView`**

Update the `PreviewWebView(...)` call site in `DocumentView.swift`:

```swift
PreviewWebView(
    html: render.html,
    mode: previewMode,
    theme: settings.previewTheme,
    fontSize: settings.previewFontSize,
    textColor: settings.previewTextColor,
    printController: printController,
    onPageBreakAction: { ... }
)
```

**Step 4: Regenerate + build + smoke test**

```sh
xcodegen && xcodebuild ... test 2>&1 | grep 'Test run'
```

Expected: 128 tests still pass.

**Step 5: Commit**

```sh
git add MDPrintView/Views/PreviewAppearancePopover.swift \
        MDPrintView/Views/DocumentView.swift \
        MDPrintView.xcodeproj/project.pbxproj
git commit -m "feat: Aa popover consolidates preview theme + size + text color

Replaces the paintpalette Menu with an Aa (textformat.size) button that
opens a popover with three rows: theme swatches, font-size slider,
text-color swatches. Live-applies through AppSettings — no explicit save.
Matches the near-universal reading-app pattern (Apple Books, Bear,
Reeder) surfaced in the Mobbin audit."
```

---

## Task 10: CHANGELOG entry, launch, smoke test, commit

End-to-end verification: the golden path plus a few edge cases. This is where visual regressions surface.

**Files:**
- Modify: `CHANGELOG.md`

**Step 1: Add unreleased entry**

Under the top `## [Unreleased]` section, add:

```markdown
### Added
- **Text color and preview typography controls.** A new **Aa** button in
  the preview toolbar opens a popover with theme, font size (12–24 pt),
  and text color swatches — all live-apply. Settings → Editor gains a
  matching text-color row. Colors default to `System`, which tracks
  Light/Dark automatically; the presets are Warm ink and High contrast,
  plus a Custom… picker for arbitrary values.
```

**Step 2: Launch the app and verify manually**

Golden path:
```sh
cd /Users/cmagsisi/Dev/mdview/.worktrees/typography-controls
xcodebuild -project MDPrintView.xcodeproj -scheme MDPrintView -configuration Debug build 2>&1 | grep BUILD
open ~/Library/Developer/Xcode/DerivedData/MDPrintView-*/Build/Products/Debug/MDPrintView.app
```

Verify:
- **Preview Aa popover** opens on Aa click; theme/size/color rows visible and correctly labeled.
- Picking a theme swatch → preview reflows immediately.
- Dragging the size slider → text scales smoothly.
- Picking a text color swatch → preview text recolors, background stays theme-controlled.
- Picking "Custom…" opens the macOS color panel; picking a color updates the preview live.
- Picking "System" clears the override — text goes back to the theme's default.
- Reopen the app → settings persist.
- Settings → Editor text color row: same behavior for the editor pane. Code, headings, and links keep their syntax colors.
- Toggle macOS Light↔Dark (System Settings → Appearance): "System" swatch tracks correctly; a custom color stays fixed.

Report any regressions or visual issues; fix before committing.

**Step 3: Commit CHANGELOG**

```sh
git add CHANGELOG.md
git commit -m "docs: CHANGELOG entry for typography controls"
```

**Step 4: Push branch, open PR**

```sh
git push -u origin feature/typography-controls
gh pr create --title "feat: text color + preview Aa popover (typography controls)" \
             --body "Implements docs/plans/2026-07-16-typography-controls-design.md.

Adds user-controllable text color in both editor and preview, plus a
new Aa toolbar button in the preview that opens a live-applying popover
with theme + font size + text color. previewTheme was per-window @State;
now app-level via AppSettings.

Follows the swatches-not-color-well pattern from the Mobbin audit. 128
tests, all green. Manual smoke test covers Light/Dark switch, custom
color persistence, and all four theme swatches."
```

---

## Not doing in this plan (deferred / YAGNI)

- **Print-mode override.** Print CSS keeps its own black-on-white 11 pt rules; inline `#content { color: ... }` shouldn't fight `@media print`, but if it does we can address in a follow-up.
- **Background color override.** Design doc explicitly rules this out.
- **Per-document (not per-app) overrides.** Also ruled out; markdown has no place to store it.
- **Migration for existing users.** Not needed — nil defaults + `.original` theme match today's behavior.

## Remember

- **DRY, YAGNI, TDD, frequent commits.**
- Reference the design doc (`docs/plans/2026-07-16-typography-controls-design.md`) when in doubt about intent.
- Every task ends with all tests green.
- No `Co-Authored-By: Claude` trailers on commits — repo convention (see `.claude/memory/feedback_no_claude_coauthor_trailer.md`).
