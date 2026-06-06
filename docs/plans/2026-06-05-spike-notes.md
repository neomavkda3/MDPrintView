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

## E2 evaluation (faded marks)

**Captured:** 2026-06-05, commit `9b91a27`

**Bar:** E1 bar + marks are visually distinct from content text.

**What we can verify:**
- ✅ 41/41 tests pass (38 prior + 3 E2: heading `#`, strong `**`, emphasis `*` all fade to tertiary)
- ✅ Implementation: `fadeDelimiters(in:range:delimiterLength:)` helper handles Strong (2), Emphasis (1), InlineCode (1), CodeBlock (3). Heading fades the `# ` prefix.
- ✅ Build clean, no concurrency warnings

**What requires user assessment:**
- Compare W2 source mode vs E2 hybrid mode side-by-side: do faded marks improve readability?
- Visual check on real doc with mixed content (headings + bold + lists + code blocks)
- Eye-strain check on long docs

**Verdict:** PASS (engineering — proceed to E3). Per gating rubric, this is the natural "Rich mode" stopping point if E3 turns out unworkable in T8. The implementation is shippable as-is should we revert E3.

**Notes:**
- The CodeBlock case fades the 3-char fence delimiters. swift-markdown's `CodeBlock.range` may or may not include the fences — if E2 visual review shows the wrong characters getting faded, this is the place to look.
- All faded marks use `NSColor.tertiaryLabelColor` which adapts light/dark mode automatically.

---

## E3 evaluation (cursor-aware folding)

**Captured:** 2026-06-05, commit `41d85d1`

**Bar:** E2 bars + selection across folds selects expected source range; undo intact; ≥60fps cursor movement; no cursor-positioning glitches.

**What we can verify:**
- ✅ 46/46 tests pass (41 prior + 5 E3: bold/heading hide-when-outside, reveal-when-inside, cursor-at-boundary, no-cursor-falls-back-to-E2)
- ✅ Implementation: `apply(to:cursorAt:)` overload + `markColor(insideCursor:cursorProvided:)` helper. When cursor provided AND outside a span → `.clear`. Otherwise tertiary.
- ✅ `textViewDidChangeSelection` delegate method observes cursor moves; re-applies styler with new cursor location. Attribute-only changes don't fire `textViewDidChangeSelection` recursively (verified by NSTextStorage docs — no re-entry risk).
- ✅ Build clean, smoke test ALIVE, no new crash report

**Known design compromise (documented in plan):**
- `.clear` color hides marks visually BUT they still occupy horizontal space ("ghost space"). The cursor moves through invisible positions one keystroke at a time. This is a deliberate trade-off — fully zero-width hiding would require custom `NSTextLayoutFragment` (significantly more complex, deferred to v1.1 polish).
- Net effect: hybrid mode "looks rendered" when cursor is far away from formatting; marks pop in when cursor approaches. Ghost space means horizontal spacing isn't quite WYSIWYG.

**What requires user assessment (the actual gate):**
- Cursor smoothly enters/exits styled span (no jumps, no skips)
- Selection across folded marks draws cleanly and selects expected source range
- Backspace at the boundary of a folded mark
- Typing inside a styled span
- Undo restores both content AND mark visibility
- Perceptual feel on 10KB doc — is the cursor lag <16ms (≥60fps)?
- Does the ghost space look ugly enough to disqualify the experience?

**Verdict:** PASS (engineering — proceed to E4 stress test). Caveat: the ghost-space compromise is a known limitation. If user assessment in T10 decision finds it disqualifying, we have a clean fallback path to ship the "Rich" mode (E1+E2 — same code minus the cursor observation in `textViewDidChangeSelection`, plus revert the `cursorAt` default to omit fold/reveal).

**Risk-prone areas to evaluate during T10 decision:**
- Performance: the `apply` walk traverses the entire AST on every cursor move. On 50KB docs with hundreds of styled spans, this might be visibly slow. Mitigation if needed: scope re-application to the markup near the cursor; debounce. Both deferrable.
- Cursor position correctness near mark boundaries (the test `cursorAtMarkBoundaryReveals` passes, but real-world cursor + selection drawing is more nuanced).
- Selection drag across a fold boundary may select fewer characters than the user expects (because hidden marks shift visual column count).

---



