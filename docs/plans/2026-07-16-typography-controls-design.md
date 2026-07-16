# Typography controls — editor text color + preview appearance popover

**Status:** designed 2026-07-16. Not yet implemented.

## What we're building

User-controllable text color in the editor pane, plus a preview-pane **Aa** popover consolidating theme + font size + text color. Live-apply, no explicit save.

Motivation from the user: MDPrintView currently has no way to change preview text size or override text color in either pane. The preview has four reading themes but no size control; the editor has size + family but no color override.

## What the audit changed

Mobbin audit of reading/writing apps (Apple Books, Bear, Reeder 5, Athletic, Matter, Linktree, Alfread) found three patterns that overrode our initial sketch:

- **Preset swatch strips, not bare `ColorPicker` color-wells.** Every reading app in the sample uses 4–5 named swatches with an optional "Custom…" chip. A raw color-well looks like a dev tool.
- **One panel for all typography, in the reader — not spread across toolbar dropdowns and Settings.** The near-universal pattern is an "Aa" toolbar button that opens a popover with theme + size + color together, live-applying.
- **No advisory copy.** Nobody explains "text color overrides your reading theme" in a label — the live preview makes the interaction obvious.

Consequence: the preview theme picker moves out of its current paintpalette dropdown into a unified Aa popover. `previewTheme` promotes from per-window `@State` to a persisted, all-windows-shared `AppSettings` field (small behavior change; called out below).

## Data model

Four new fields on `AppSettings`, all `@AppStorage`-backed:

```swift
var previewTheme: PreviewTheme = .original      // promoted from per-window @State
var previewFontSize: Double = 16                // 12–24, step 1
var previewTextColor: String? = nil             // hex "#RRGGBB", nil = "System"
var editorTextColor: String? = nil              // hex, nil = "System"
```

**Why `String?` (hex) instead of `Color`:** `Color`/`NSColor` isn't `Codable` without an archiver wrapper. Hex round-trips through `@AppStorage` cleanly and is trivially readable in `defaults read`. A ~10-line hex↔`NSColor` helper lives in one place.

**Why `nil = "System"`:** the editor's syntax highlighter and the preview's CSS both track macOS Light/Dark automatically when nothing overrides them. `nil` means "don't override → dynamic system color wins." Users who explicitly want a fixed color get one; everyone else keeps the current dynamic behavior.

**Migration:** existing installs get `nil` for both colors, `16` pt for preview size, and `.original` for theme (matches the current per-window default). No migration script needed.

**Behavior change to call out:** `previewTheme` was per-window; multiple windows could show different themes. Consolidating into `AppSettings` makes it all-windows-shared. This is an accidental capability, not an intended feature.

## UI

### Preview: Aa popover (replaces paintpalette dropdown)

The paintpalette in the preview toolbar strip disappears. An **Aa** button lives in the same slot. Clicking it opens a `.popover(isPresented:)` (~260 × 240 pt) with three stacked rows:

```
Theme         ⦿ Original  ○ Sepia  ○ Quiet  ○ Focus
Font size     A  ◄─────●─────►  Ⓐ    16 pt
Text color    ⦿ System  ○ Warm ink  ○ High contrast  ○ Custom…
```

- Selected swatch has a ring.
- Each theme swatch shows the actual theme's background+text pair; each color swatch shows the actual color.
- Font size slider: small "A" left cap, larger "Ⓐ" right cap, monospaced pt readout on the right.
- **Custom…** opens `NSColorPanel`; the picked hex is stored and shown as selected. Selecting a preset swatch afterward swaps to that preset's hex; "Custom…" auto-selects again if the stored hex doesn't match any preset.
- All rows apply live behind the popover. Outside-click dismisses.

### Editor: one new row in the Settings Editor section

```
Text color:   ⦿ System  ○ Warm ink  ○ High contrast  ○ Custom…
```

Same swatch component, bound to `editorTextColor`. Editor doesn't get an Aa popover — themes don't apply to it, and font size/family are already in Settings.

### Swatch color values

| Swatch | Editor | Preview |
|---|---|---|
| System | `nil` — `NSColor.labelColor` (dynamic Light/Dark) | `nil` — theme CSS wins |
| Warm ink | `#5B4636` (sepia-ink tone) | same |
| High contrast | dynamic — `#000000` in Light, `#FFFFFF` in Dark | same |
| Custom… | user's hex, remembered per-pane | user's hex, remembered per-pane |

## Wiring

### Editor path

`SyntaxHighlighter` gains one init param:

```swift
init(baseFontSize: CGFloat, fontFamily: EditorFontFamily, baseTextColor: NSColor? = nil)
```

The highlighter currently sets prose runs to `NSColor.labelColor`. With a non-nil override it uses that instead. **Syntax-colored runs (headings, code, links) are untouched** — overriding those would break the readability the highlighter exists to provide.

`MarkdownTextView.updateNSView` converts `settings.editorTextColor` (hex) to `NSColor` and passes it to the highlighter on any change. Rides the existing 80 ms debounce.

### Preview path

Two CSS values applied as an **inline `style=` attribute on `#content`**, not new stylesheet rules — inline beats theme selectors (`body.theme-sepia { color: … }`) without needing `!important`.

Added to the setBody step in `PreviewWebView.inject`:

```js
document.getElementById('content').setAttribute(
    'style',
    'font-size:\(size)pt;\(color.map { "color:\($0);" } ?? "")'
);
```

Empty color → attribute omits the `color:` clause → theme wins. **That is the "System" behavior.** No branch needed.

### Dark mode

`nil` in either pane means "no override → dynamic system color wins," because `NSColor.labelColor` in the editor and `color-scheme: light dark` in the preview (already set in `preview.css`) both track Light/Dark automatically.

## Testing

Seven new tests:

1. Hex ↔ `NSColor` round-trip (RGB, RGBA, invalid input clamps to nil).
2. `SyntaxHighlighter` with `baseTextColor: nil` matches current output (regression fence).
3. `SyntaxHighlighter` with `baseTextColor:` applies to prose runs only, not code/heading/link runs.
4. `AppSettings` stores and reads `nil` for both color fields.
5. Preview CSS injection: no overrides → no `style` attribute changes; size only → `font-size` present, `color` absent; both → both present.
6. `previewTheme` first-launch default is `.original` when UserDefaults has no key.
7. `SwatchStrip` view: selecting a preset writes the hex to the binding; selecting "Custom…" opens the color panel and writes its result.

## Not doing (YAGNI)

- **Background color override.** Themes handle that; user-picked backgrounds risk bad-contrast pairings and every reading app in the audit keeps background theme-controlled.
- **Per-document overrides.** All settings are app-level. If we ever need per-doc, that's a separate feature; markdown has no place to store it anyway (page-break precedent).
- **Print-mode override.** Print already has its own CSS in `preview.css` (black-on-white, 11 pt). Preserving that regardless of Screen overrides.
- **More swatches.** Three presets + Custom covers the audit's pattern. Adding a fourth preset is design creep.

## Rough scope

- **New files:** `SwatchStrip.swift`, `HexColor.swift` (color helper), `PreviewAppearancePopover.swift` (or inline in `DocumentView` if <100 LOC).
- **Modified:** `AppSettings.swift`, `SyntaxHighlighter.swift`, `MarkdownTextView.swift`, `PreviewWebView.swift`, `DocumentView.swift` (Aa button replaces paintpalette; `previewTheme` read from environment instead of `@State`).
- **Deleted:** the current paintpalette Menu block in `DocumentView.swift`.

Ballpark: ~350 LOC added, ~30 removed. One PR, ship as v0.4.0 (feature-scale change, worth the minor bump; also opens room for the deferred word-count/reading-time work in the same version).
