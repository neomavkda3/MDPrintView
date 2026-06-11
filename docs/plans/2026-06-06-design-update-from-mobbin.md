# MDPrintView — Design Update from Mobbin Research

**Date:** 2026-06-06
**Source:** Mobbin (iOS + web platforms — Mobbin does not index macOS apps directly, so references are cross-platform analogues that translate cleanly to macOS 26's design language).

## What we looked at

24 screens across these searches:

**1. Markdown editors with live preview**
- [Mintlify — read-me](https://mobbin.com/screens/38566aba-9084-4c3f-a719-4fad70ca4da6)
- [Mintlify — read-me alt](https://mobbin.com/screens/7a2174a8-6921-41ca-89e6-63804e5c8f8f)
- [Codecademy editor](https://mobbin.com/screens/1fbac36e-7018-4a7a-994d-23dd5106a2d7)
- [Manus editor + diff](https://mobbin.com/screens/4bf81f06-fb31-4ec2-97f6-37f587b50340)
- [ChatGPT canvas](https://mobbin.com/screens/1b6cfd4b-a047-4af3-8361-ad4d2dbd9116)
- [Manus + style inspector](https://mobbin.com/screens/2a082ee0-9ec0-4efb-beb2-37edbd9001d6)

**2. Document editors with outline sidebar**
- [Frame doc + outline](https://mobbin.com/screens/1d845fd9-50f7-4342-bb06-534e4aa4b9b7)
- [Canva docs outline panel](https://mobbin.com/screens/5110baa9-c2e1-440f-90e1-6e247c06ec5b)
- [Craft TOC + Format inspector](https://mobbin.com/screens/f19df619-ca6e-4757-8866-fabe606c16a3)
- [Plane outline right-pane](https://mobbin.com/screens/24dab136-771e-4e27-ad11-3f0734136986)
- [Canva docs full layout](https://mobbin.com/screens/27836f7f-1f05-4d0c-ad6f-c720fb8089dc)
- [Craft Insert panel](https://mobbin.com/screens/1d7f6e75-4446-4ad8-a328-345fedccf68a)

**3. Reading-mode typography (Apple Books, Fable, Blinkist, Medium)**
- [Fable themes panel](https://mobbin.com/screens/8ed9301b-98de-4652-8715-c364cd8d8cab)
- [Apple Books — Themes & Settings](https://mobbin.com/screens/cc838afb-2032-48bf-abec-4ae15e284f0c)
- [Blinkist read pane](https://mobbin.com/screens/176225e9-07c4-4344-ad1e-f82a4da49ec5)
- [Fable font + size](https://mobbin.com/screens/25dbaf4d-5a50-47f7-a506-05eb12a2a681)
- [Medium reader chrome](https://mobbin.com/screens/80bbeeda-5b2d-43b3-896d-e6f009fd2564)
- [Blinkist text rendering](https://mobbin.com/screens/93e6cd0e-69f7-4f2c-ab34-32d9db33c752)

**4. Formatting toolbars (Wikipedia, Craft iOS, Freeform, Medium, LinkedIn)**
- [Wikipedia text-formatting sheet](https://mobbin.com/screens/063c0598-ff61-481e-9b6d-35c84b51b0f9)
- [Craft style chip bar](https://mobbin.com/screens/443b7d21-d5eb-487a-8aa7-5a79186222cd)
- [Freeform inline formatting](https://mobbin.com/screens/626ba5dc-48ac-42b7-8409-ebba4129ac0b)
- [Medium minimal toolbar](https://mobbin.com/screens/f258706f-650c-4a2d-b9d5-2bd3c9a79d8f)
- [LinkedIn shape chip bar](https://mobbin.com/screens/bfff0996-e78c-4b01-a2d0-e222da8b0936)
- [Craft drawing chip bar](https://mobbin.com/screens/d538c846-25d2-4ca6-b801-fe62b00f10fe)

---

## Patterns we should adopt

### A. Reading themes (Apple Books / Fable / Blinkist)

**What they do:** A small palette of named themes (Original, Sepia, Paper, Quiet, Bold, Calm, Focus) where each preset bundles:
- Background color (white / cream / dark blue / black)
- Text color
- Font family
- Font size baseline

**Why this matters for MDPrintView:** The preview pane currently uses one color scheme that adapts to system light/dark. That's the bare minimum. Users reading a long printed-style document for 20+ minutes benefit hugely from sepia / cream backgrounds and a serif font with the right metrics.

**Proposed change:** Add a `PreviewTheme` enum + presets, exposed via a small palette button above the preview pane (next to the Screen / Print picker):

```swift
enum PreviewTheme: String, CaseIterable, Identifiable {
    case original   // current — system light/dark
    case sepia      // cream background, dark brown text
    case quiet      // off-white, soft grey
    case focus      // pure black, off-white text — minimal contrast bloom
    var id: String { rawValue }
}
```

Implementation: theme is a `body` class swap on the preview WebView (`body.theme-sepia`), CSS handles the rest. No Swift heavy lifting. ~150 lines of CSS + 30 lines of Swift.

**Scope:** v1.0 — small effort, high polish.

---

### B. Editor font family picker in Settings

**What they do:** Apple Books offers Andada / Lato / Lora / Raleway (and an "Original" override). Fable does the same. The picker is one row; results apply instantly.

**Why this matters for MDPrintView:** Today, Settings has only font *size*. The user can't choose between monospaced (default) and a proportional editing font. Some Markdown writers want New York / Charter for prose; others want SF Mono for code-heavy docs.

**Proposed change:** Add `editorFontFamily` to `AppSettings`:

```swift
enum EditorFontFamily: String, CaseIterable, Identifiable {
    case systemMono       // SF Mono (current default)
    case systemSerif      // New York
    case systemSans       // SF Pro Text
    var id: String { rawValue }
    var nsFont: (CGFloat) -> NSFont {
        switch self {
        case .systemMono:   return { NSFont.monospacedSystemFont(ofSize: $0, weight: .regular) }
        case .systemSerif:  return { NSFont(name: "New York", size: $0) ?? NSFont.systemFont(ofSize: $0) }
        case .systemSans:   return { NSFont.systemFont(ofSize: $0) }
        }
    }
}
```

`SyntaxHighlighter` already takes `baseFontSize`; extend it to take the family. Settings View adds a `Picker`. ~50 lines.

**Scope:** v1.0 — small effort.

---

### C. Toolbar consolidation (Medium / Wikipedia / Craft style)

**What they do:** Medium's iOS toolbar shows ~6 icons; Apple Books has 4. Wikipedia consolidates into 2 rows in a bottom sheet. The bar is restrained.

**Our current toolbar** has 13 items in `principal` (B I S | H | • 1. ☐ | </> {} link mermaid) plus mode picker in `navigation`. That's busy by macOS HIG standards.

**Proposed change:** Consolidate three triples into menu buttons:
- Lists → one `Menu { Bullet, Numbered, Task }` triggered by `list.bullet.indent` icon
- Code → one `Menu { Inline code, Code block, Mermaid }` triggered by `chevron.left.forwardslash.chevron.right`

Keeps Bold / Italic / Strike + Heading + Link as the always-visible chips. Cuts toolbar from 13 → 7 visible. Menu submenus keep all functionality + keyboard shortcuts.

**Scope:** v1.0 — easy win, ~40 lines refactor.

---

### D. Outline sidebar — TOC chrome (Craft / Plane / Canva)

**What they do:**
- [Craft](https://mobbin.com/screens/f19df619-ca6e-4757-8866-fabe606c16a3) shows the outline + a separate right-side **inspector** with Outline / Info / Assets tabs.
- [Plane](https://mobbin.com/screens/24dab136-771e-4e27-ad11-3f0734136986) puts outline as right-side rail (not left), with Outline / Info / Assets tabs.
- [Canva](https://mobbin.com/screens/5110baa9-c2e1-440f-90e1-6e247c06ec5b) makes the outline a *toggleable overlay panel*, not a permanent sidebar — bottom-bar toggle when needed.

**Our current outline:** Always-on NavigationSplitView left sidebar at 180–320pt width.

**Proposed change:** Two compatible refinements:
1. Outline rows should show a **muted dot** colored by heading level (h1 saturated, h6 muted) — visual hierarchy at a glance, copied from Craft.
2. Selecting an outline row should *visually highlight which heading section the cursor is in* via a current-section dot indicator. (Selection feedback is missing today.)

Both are pure CSS/SwiftUI; no architectural change. Sidebar stays on the left to match macOS norms.

**Scope:** v1.1 (the click-to-scroll behavior was already deferred; this layers on top).

---

### E. Diff / version compare (Mintlify, Manus)

**What they do:** Mintlify shows the *before / after* side by side when reviewing a PR; Manus shows a "Diff / Original / Modified" tab triplet inside a doc preview.

**Why this matters for MDPrintView:** macOS's NSDocument architecture already gives us **Versions** (Time Machine for documents) via `File → Revert to → Browse All Versions…`. The default Apple chrome for this is fine. We get this for free — no implementation.

**Proposed change:** Add a brief note in our README + product description that MDPrintView supports macOS Versions out of the box. Don't build a custom diff UI.

**Scope:** v1.0 — documentation only.

---

## What we should NOT adopt

- **Bottom-sheet formatting toolbars** ([Wikipedia](https://mobbin.com/screens/063c0598-ff61-481e-9b6d-35c84b51b0f9)) — iPad idiom, awkward on macOS where a top toolbar is the convention.
- **AI-action chips** (Manus, ChatGPT, Canva's "Magic Write") — out of scope for v1, and a sandboxed app with no network entitlement can't host an AI feature anyway.
- **Right-pane inspector replacing the top toolbar** ([Craft](https://mobbin.com/screens/f19df619-ca6e-4757-8866-fabe606c16a3)) — interesting but a major rework; v1.2+ if ever.
- **Full-screen focus mode hiding all chrome** (Medium reader) — defer to v1.1 as a "Distraction-free mode" command.

---

## Concrete change list

| Change | Phase | Effort | Risk |
|---|---|---|---|
| A. Preview themes (Original / Sepia / Quiet / Focus) | **v1.0 — pre-submission** | small | low |
| B. Editor font family picker in Settings | **v1.0 — pre-submission** | small | low |
| C. Toolbar consolidation (Lists menu + Code menu) | **v1.0 — pre-submission** | small | low |
| D. Outline level dot + current-section indicator | v1.1 | medium | low |
| E. Mention macOS Versions in marketing copy | v1.0 — pre-submission | trivial | none |

Net v1.0 work: A + B + C + E. Roughly 1 day of focused effort, well before release. They genuinely level up the product perceived-quality before screenshots are captured for the store listing.

---

## Recommendation

Do **A + B + C + E** before Week 5 submission. They:
1. Show meaningfully on marketing screenshots (sepia theme, font picker, cleaner toolbar)
2. Don't require new test infrastructure
3. Don't touch the renderer or sandbox model — low risk
4. Take roughly a day combined

D (outline polish) and the deferred fold/reveal hybrid mode go on the v1.1 list.

If you sign off, I'll write a focused implementation plan for A/B/C/E next.
