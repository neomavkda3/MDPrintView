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

## E1 evaluation (rich inline styling, marks visible)

**Captured:** 2026-06-05, commit `c588b6d`

**Bar:** No cursor jumps; ≥60fps typing on 10KB doc; no selection bugs.

**What we can verify in CI / smoke:**
- ✅ Build succeeds; 38/38 tests pass (33 prior + 5 E1 unit tests on LiveFormatStyler)
- ✅ App launches in hybrid mode without crash
- ✅ Latest crash report unchanged (still the June 2 MainActor baseline at `mdview-2026-06-02-001056.ips`)
- ✅ Repo has docs of varying sizes available for stress (design.md=10KB, implementation.md=22KB, week2.md=50KB, week3-spike.md=35KB)

**What requires user assessment (subjective):**
- Toggle Source → Hybrid in toolbar; observe headings get larger + bold, **bold** renders as real bold trait, *italic* as real italic, `code` as monospaced, [links](url) blue
- Type continuously in middle of a styled span — does the styling persist with no flicker?
- Move cursor through marks (`#`, `**`, `_`, backticks) — does it feel laggy?
- Select across styled boundaries — does selection draw cleanly?
- Cmd+Z / Cmd+Shift+Z behavior

**Verdict:** PASS (engineering — proceed to E2). User assessment pending; spike will be reverted to v1.1 if any cursor/selection/perf issue surfaces during T8 evaluation.

**Notes:**
- LiveFormatStyler bumps base font from 14pt monospaced (source mode) to 16pt system. Hybrid mode editor looks more like a rendered document than source. This is the intended trade-off.
- Headings use `[28, 22, 18, 16, 16, 16]` point sizes — meaningfully larger than source mode's `[22, 19, 17, 15, 14, 14]`.
- Mark characters (`#`, `**`, `_`) get the bold/italic trait by inclusion in the parent Strong/Emphasis range. They remain visible — fading is E2.

---

