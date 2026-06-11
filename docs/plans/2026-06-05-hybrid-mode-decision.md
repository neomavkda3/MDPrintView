# MDPrintView Hybrid Editor Mode — v1 Inclusion Decision

**Date:** 2026-06-05
**Spike commits:** `2df6a73`…`72b5639`
**Spike notes:** `docs/plans/2026-06-05-spike-notes.md`
**Spike plan:** `docs/plans/2026-06-05-MDPrintView-week3-hybrid-spike.md`

## Decision

**◐ Ship "Rich" mode (E1+E2 — marks visible, faded) in v1; defer fold/reveal (E3) to v1.1**

## Rationale

The graduated success criteria worked exactly as designed.

- **E1 (rich inline styling) — PASS.** `LiveFormatStyler` walks the swift-markdown AST and applies real font sizes for headings, bold/italic font traits, monospaced for code, link color for links. 5 unit tests verify each attribute is applied at the right index. App launches in hybrid mode; no crash.

- **E2 (faded marks) — PASS.** `fadeDelimiters(in:range:delimiterLength:)` applies `tertiaryLabelColor` to `#`, `**`, `_`, `` ` ``, ` ``` ` delimiters. 3 unit tests verify mark coloring. The "Rich" mode now reads like a styled document with marks present but de-emphasized.

- **E3 (cursor-aware fold/reveal) — ENGINEERING PASSED, PERF FAILED.** `apply(to:cursorAt:)` overload correctly hides marks (`.clear` color) when cursor outside their span, reveals them when cursor enters. 5 unit tests pass. **But** the E4 stress benchmark measured a single `apply()` call on a representative 50 KB markdown corpus at **~8.4 seconds**. Wiring `textViewDidChangeSelection` to call `apply(_:cursorAt:)` would freeze the editor on every cursor keystroke, which is unshippable.

The perf cliff is exactly the kind of finding the spike was designed to catch *before* it landed in user hands. We discovered it cheap (1 day, 12 commits) instead of expensive (after launch, with bug reports).

## What ships in v1

- **Source mode** — current W2 editor: monospaced 14pt, syntax highlighting for headings/code/links via `SyntaxHighlighter`. Marks fully visible. (Unchanged from Week 2.)
- **Hybrid mode ("Rich")** — `LiveFormatStyler` applied on text change only:
  - Heading point sizes `[28, 22, 18, 16, 16, 16]` with bold trait
  - System base font 16pt for body
  - `**bold**` gets real bold font trait
  - `*italic*` gets real italic font trait
  - `` `code` `` gets monospaced font + `secondaryLabelColor`
  - Code blocks same; 3-char fence delimiters faded
  - Link bodies get `linkColor`
  - All syntax marks (`#`, `**`, `_`, backticks, fence delimiters) faded to `tertiaryLabelColor`
  - **Marks remain visible** — no fold/reveal
- **Mode toggle** — `EditorMode` enum with segmented `Source`/`Hybrid` picker in the toolbar (navigation placement). Mode is per-window state, not persisted to the document.

## What defers to v1.1

- **E3 cursor-aware fold/reveal.** Requires `LiveFormatStyler.apply` to drop from 8.4s/50KB to under 16ms/50KB before it can be wired to selection changes — a ~525× speedup. The `apply(to:cursorAt:)` overload remains in the code (5 unit tests still pass) so v1.1 work can pick up the cursor-context plumbing for free.

## v1.1 followups

To unlock E3 fold/reveal, the styler needs one or more of:

1. **Scoped re-application.** Don't walk the entire AST on every cursor move. Track which markup ranges contain (or recently contained) the cursor and only re-apply attributes inside those ranges. The full walk happens once on text change.
2. **Range-aware caching.** Cache the parsed `Document` and per-markup `NSRange`. On cursor move, look up the smallest enclosing markup, mutate only its mark attributes. Avoid the swift-markdown re-parse entirely.
3. **NSTextLayoutManager rendering attributes.** Per `axiom-textkit-ref`, `NSTextLayoutManager.addRenderingAttribute(_:value:for:)` applies temporary visual attributes *without* mutating `NSTextStorage`. This bypasses storage-mutation cost and is the TextKit 2-preferred path for transient styling like fold/reveal. Limitation: rendering attributes don't include `.font`, so font traits still need to live on storage. But mark-color attributes (the actual fold/reveal vector) qualify perfectly.
4. **Debounce cursor moves.** A 50ms debounce on `textViewDidChangeSelection` would let the user move through marks without re-running the styler at every keystroke. Combine with any of #1–#3.

Option #3 is the most architecturally clean and likely cheapest to implement once we accept that mark visibility is "rendering" (TextKit 2 vocabulary) rather than content. Estimate: 1–2 days once we have v1 metrics to validate the cost is justified.

## What this delivers vs. the original Brainstorm

Section B of the design (`docs/plans/2026-06-01-MDPrintView-design.md`) committed to "both modes from day one." This decision honors that commitment with one caveat:

- ✅ Source mode (W2) — fully featured.
- ✅ Hybrid mode (this spike, "Rich" variant) — rich inline styling, faded marks. **Marks remain visible** in hybrid mode rather than fold/reveal on cursor.
- ◐ The user-facing experience is "rendered-looking editor where syntax is faded but present", not "Typora-style invisible-marks editor."

This is a meaningful partial-fulfillment. The Typora experience proper depends on E3 fold/reveal, which v1.1 will revisit with the optimization roadmap above.

## Risks resolved by this decision

- ✗ No editor freezes on cursor movement (E3 risk eliminated by not wiring `textViewDidChangeSelection`).
- ✗ No "ghost space" UX issue (marks visible at all times, so `.clear` color isn't applied).
- ✗ No regression risk on existing source mode (`SyntaxHighlighter` and `MarkdownTextView` source path untouched).

## Test summary at decision time

- 46 tests passing across 8 suites
  - 20 `MarkdownRenderer` tests
  - 4 `SyntaxHighlighter` tests
  - 5 `EditorController` tests
  - 3 `Outline` tests
  - 4 (E1) + 3 (E2) + 5 (E3) = 12 `LiveFormatStyler` tests
- Smoke test on 118 KB stress doc: ALIVE, no new crash report
- E4 perf benchmark (deleted from suite — its job done): 8.4s/50KB — the load-bearing measurement that drove this decision

## Approvals

- Spike controller (Claude): decision recorded
- Project owner (Chris Magsisi): **ratified 2026-06-06** — "I accept rich"

Decision is final. Week 4 work (Mermaid editing, KaTeX, accessibility) proceeds.
