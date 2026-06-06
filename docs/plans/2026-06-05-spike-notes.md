# mdview Week 3 Spike — Notes

Append findings after each experiment. Each entry is timestamped.

---

## Baseline — Source mode (W2 SyntaxHighlighter)

**Captured:** 2026-06-05, commit `2df6a73`

**Editor appearance (source mode):**
- Base font: monospaced system, 14pt regular
- Default foreground: `NSColor.textColor`
- Headings: monospaced, bold, sized by level via `SyntaxHighlighter.headingSizes` = `[22, 19, 17, 15, 14, 14]`
- Heading mark `#` (or `##`, `###`) is fully visible, same color as heading body
- Inline code (`` `x` ``): styled with `secondaryLabelColor` — backticks and content both share this tint
- Code block (``` ``` ```): same secondary tint applied to the entire fenced range including fence delimiters
- Links (`[label](url)`): `linkColor` applied to the entire link source range (brackets, label, parens, URL)
- Emphasis (`*x*`) and strong (`**x**`): NO trait change in source mode — they remain plain text
- Strikethrough, blockquote, list markers: not styled in editor source view

**Cursor + selection behavior:**
- Cursor moves through every character one column at a time (including `#`, `**`, `_`, backticks, brackets, parens, URLs)
- No folding; nothing is invisible
- Selection draws cleanly across all character types
- Typing inside an emphasis/strong span behaves like normal text editing — the `SyntaxHighlighter.apply` re-runs in the `Coordinator.textDidChange` after every keystroke, but since attribute changes don't fire `textDidChange`, there's no re-entry

**What we want to add in hybrid mode:**
1. Real font size scaling for headings (28/22/18 vs source-mode's 22/19/17 — slightly larger to feel "rendered")
2. Real bold trait on `**bold**`, real italic trait on `*italic*` (not just color)
3. Monospaced font on inline code AND code block (we have color, not font, in source mode)
4. Faded marks (E2): make `#`, `**`, `_`, `` ` ``, ` ``` ` visually de-emphasized but visible
5. Optional cursor-aware folding (E3): make marks invisible when cursor outside their span

---
