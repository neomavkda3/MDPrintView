# mdview Manual Test Checklist (Pre-Submission)

Walk this list before running `scripts/archive.sh` and submitting. ~30–45 minutes if you go top-to-bottom.

## Prep (2 min)

```sh
cd ~/Dev/mdview
pkill -x mdview 2>/dev/null
xcodebuild -project mdview.xcodeproj -scheme mdview -configuration Debug build 2>&1 | tail -3
APP="$(find ~/Library/Developer/Xcode/DerivedData -name 'mdview.app' -path '*Debug*' -type d -print -quit)"
# Launch attached to terminal so any errors print:
"$APP/Contents/MacOS/mdview"
```

Optional — concatenate all repo docs into one ~150KB stress doc:

```sh
cat docs/plans/2026-06-0*-*.md > /tmp/mdview-stress.md
```

Use that or any large markdown file for the "Performance" section below.

---

## 1. Document open + save (3 min)

- [ ] Cmd+O → open a `.md` file
- [ ] Cmd+O → open a `.txt` file
- [ ] Double-click a `.md` from Finder — should open in mdview (not TextEdit)
- [ ] Type a few chars + Cmd+S — saves, title bar loses "Edited" badge
- [ ] File → Revert to → Browse All Versions… opens the macOS Versions browser
- [ ] Cmd+N opens a blank Untitled doc
- [ ] Open 2 files at once → 2 windows (or tabs depending on macOS prefs)
- [ ] Cmd+W closes the front window; if dirty, prompts to save

## 2. Editor — Source mode (3 min)

- [ ] Default mode is Source (left toolbar picker)
- [ ] Monospaced font visible
- [ ] H1/H2/H3 lines appear larger + bold than body
- [ ] Inline `` `code` `` tinted secondary
- [ ] Code blocks tinted secondary
- [ ] Links (`[label](url)`) tinted link-blue
- [ ] Marks `#`, `**`, `_`, backticks visible in source
- [ ] Type fast — no perceptible stickiness

## 3. Editor — Hybrid mode (3 min)

- [ ] Toggle Source → Hybrid via toolbar
- [ ] Headings get noticeably bigger (28/22/18 pt vs base)
- [ ] `**bold**` renders with real bold font trait
- [ ] `*italic*` renders italic
- [ ] `` `code` `` and code blocks monospaced
- [ ] Mark delimiters faded (tertiary grey), NOT invisible
- [ ] Toggle back to Source — same content, original sizing

## 4. Formatting toolbar + shortcuts (4 min)

- [ ] Cmd+B wraps selection in `**…**`
- [ ] Cmd+I wraps in `*…*`
- [ ] Strikethrough button wraps in `~~…~~`
- [ ] Heading menu → Heading 1/2/3 prefixes line with `# / ## / ###`
- [ ] Cmd+1 / Cmd+2 / Cmd+3 same as menu items
- [ ] Cmd+K inserts `[link text](https://)`
- [ ] Lists menu → Bullet inserts `- `; Numbered `1. `; Task `- [ ] `
- [ ] Code menu → Inline code wraps in backticks
- [ ] Code menu → Code block wraps in ```` ``` ````

## 5. Mermaid editor (3 min)

- [ ] With cursor NOT in a mermaid block, press Cmd+Shift+M
  → inserts a ` ```mermaid ` skeleton AND opens the editor sheet
- [ ] Edit the source in the left pane of the sheet — right pane diagram updates within ~250ms
- [ ] Apply commits the new source into the main document
- [ ] Place cursor INSIDE an existing mermaid block, press Cmd+Shift+M
  → opens sheet with existing block's source
- [ ] Cancel discards changes; main doc unchanged
- [ ] Escape key closes sheet (cancel)

## 6. Preview pane renders correctly (5 min)

Open or create a doc with these features and verify each:

- [ ] H1, H2, H3 — distinct sizes, h1 has underline rule
- [ ] Paragraph with `**bold**` `*italic*` `` `code` `` `[link](url)`
- [ ] Bullet list, numbered list
- [ ] Task list (`- [ ]` `- [x]`) renders as checkboxes
- [ ] Blockquote (`> text`) — indented with left border
- [ ] Horizontal rule (`---`) — thin line across
- [ ] Table (`| a | b |\n|---|---|\n| 1 | 2 |`) — renders as styled table
- [ ] Image (`![alt](https://placehold.co/100)`) — image displayed
- [ ] Mermaid diagram block — renders as SVG (e.g., `graph TD\n  A --> B`)
- [ ] Inline math `$E = mc^2$` — renders with italic E, superscript 2
- [ ] Block math `$$\int_0^1 x\, dx$$` — centered, proper notation
- [ ] HTML entities — type literal `<script>alert(1)</script>` in source; preview should show **text**, not execute

## 7. Reading themes (2 min)

Click the palette icon above the preview pane:

- [ ] Original — system light/dark default
- [ ] Sepia — cream background (#f4ecd8), warm brown text
- [ ] Quiet — off-white background, soft grey text
- [ ] Focus — near-black background, light text; Mermaid diagrams adopt dark theme

## 8. Layout modes (2 min)

- [ ] Toolbar's leftmost segmented picker has 3 icons (left half / split / right half)
- [ ] Cmd+Opt+1 — editor only (preview pane hidden)
- [ ] Cmd+Opt+2 — split (both panes)
- [ ] Cmd+Opt+3 — preview only (editor hidden)
- [ ] In Preview-only mode, Source/Hybrid picker greyed out
- [ ] HSplitView divider draggable between panes in Split mode
- [ ] View menu in menu bar has the three items with shortcuts shown
- [ ] Pick a layout, Cmd+Q, relaunch — same layout (persisted)

## 9. Screen vs Print preview (2 min)

In the bar above the preview pane:

- [ ] "Screen" toggle — flowing, viewport-width layout
- [ ] "Print" toggle — paper-card layout with margins, shadow on the page
- [ ] Toggle between them — preview content stays, only chrome changes

## 10. Print + PDF export (3 min)

On a multi-page doc (use the stress doc from prep):

- [ ] Cmd+P opens system print dialog
- [ ] Print preview in the dialog matches the screen preview
- [ ] **Look at page breaks** — headings should NOT split mid-line; code blocks should NOT split mid-block
- [ ] Cancel the print dialog
- [ ] Cmd+Shift+E opens NSSavePanel pre-filled with `<doc>.pdf`
- [ ] Save to Desktop
- [ ] Open the PDF — content matches preview, page breaks look right, no missing content at page boundaries

## 11. Settings (2 min)

- [ ] Cmd+, opens Settings window
- [ ] Editor Font Size slider 10-24 — moving it updates the editor live
- [ ] Editor Font Family picker — Mono / New York Serif / SF Pro
- [ ] Print Page Size picker — US Letter / A4
- [ ] Close Settings + Cmd+Q + relaunch — values still set
- [ ] Open Settings again — values reflect what you saved

## 12. Outline sidebar (2 min)

- [ ] Sidebar visible on the left (NavigationSplitView)
- [ ] Top-level headings shown
- [ ] Click disclosure triangle next to an H1 — H2/H3 children appear nested
- [ ] Type a new `## Heading` in the editor — outline updates within ~80ms
- [ ] Open an empty doc — "No headings yet" empty state
- [ ] Toggle sidebar via the standard macOS sidebar toggle (top-left button)

## 13. Document UTI behavior (2 min)

In Finder:

- [ ] Right-click a `.md` file → Get Info → Open with → **mdview should be default**
- [ ] Right-click a `.txt` file → Get Info → Open with → TextEdit should still be default (`.txt` is Alternate, not Owner)
- [ ] `.markdown` and `.mdown` extensions also open in mdview

## 14. Performance feel (3 min)

Use the stress doc:

- [ ] Open the stress doc — appears within ~1s
- [ ] Cursor in middle of doc, hold a key for 5 seconds — characters appear without lag
- [ ] Arrow-key down from top to bottom — smooth
- [ ] Toggle Source ↔ Hybrid — completes within ~500ms even on stress doc
- [ ] Select All (Cmd+A) → Delete → preview goes empty cleanly
- [ ] Paste content back (Cmd+V) → preview rebuilds

## 15. Edge cases (3 min)

- [ ] Open a totally empty new doc — no crash, preview pane empty
- [ ] Open a doc that's just one long paragraph — wraps correctly
- [ ] Undo (Cmd+Z) → Redo (Cmd+Shift+Z) — content + cursor restore
- [ ] Type text containing `&`, `<`, `>`, `"` — render escaped in preview, not as HTML
- [ ] Switch reading themes mid-edit — preview content preserved

## 16. Accessibility (2 min, optional)

- [ ] Cmd+F5 toggles VoiceOver (if you have it set up)
- [ ] Tab through toolbar — each button announces its label ("Bold", "Italic", etc.)
- [ ] Sidebar headings announce as "Heading: <title>, Level <n>"

## 17. Multi-window (1 min)

- [ ] Open two `.md` files at once → 2 windows OR 2 tabs (macOS default depends on prefs)
- [ ] Settings changes in one window propagate to all (font, layout)
- [ ] Each window has its own preview state (screen/print, theme, mode)
  Note: layout mode is **global** — changing in one window changes others. That's intentional per Polish.E.

## Known v1.1 deferred — DON'T mark as failures

The following are intentionally absent in v1.0. If you notice them, that's expected:

- ❌ Cursor-aware fold/reveal in Hybrid (marks stay faded, never go fully invisible)
- ❌ In-margin Mermaid overlay (modal Cmd+Shift+M sheet is the v1 pattern)
- ❌ Math rendering in the editor pane (preview only — source shows raw `$…$`)
- ❌ Click-to-scroll from outline (outline is display-only)
- ❌ Per-document layout preference (it's global, not per-file)

---

## Final gate before submission

When everything above is checked OR you've explicitly documented a bug:

- [ ] Replace placeholder app icon with real artwork
- [ ] Run `scripts/archive.sh` with your `DEVELOPMENT_TEAM` env var → produces `build/Export-MAS/mdview.pkg`
- [ ] Walk `docs/plans/2026-06-06-pre-submission-checklist.md` engineering section
- [ ] Paste copy from `docs/plans/2026-06-06-app-store-listing.md` into ASC
- [ ] Host privacy policy (from `docs/plans/2026-06-06-privacy-policy.md`) at a public URL
- [ ] Capture 5 screenshots at 2880×1800 or 1440×900 (same dimensions across all 5)
- [ ] Upload `mdview.pkg` via Transporter
- [ ] Submit for Review

---

## Issues found during testing

Use this section to record any bugs as you go. Format:

```
- [ ] BUG: <one-line description>
  Reproduce: <steps>
  Expected: <what should happen>
  Actual: <what happened>
```

(Then come back to me with the list and we'll triage.)
