# Vendored Assets

Third-party assets bundled into the app for offline / sandbox-safe operation. The app's CSP (`default-src 'none'; script-src 'self' 'unsafe-inline'`) forbids remote script loads, and the v1 sandbox has no network entitlement — both reasons we vendor.

Each entry records source, version, hash, and license.

---

## mermaid.min.js

- **Source:** https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js
- **Version:** 11.x (vendored 2026-06-06)
- **SHA-256:** `70137e77bb273bb2ef972b86e8b0400cca8be53cb25bfc45911a186dc98665de`
- **Size:** 3.2 MB
- **License:** MIT — https://github.com/mermaid-js/mermaid/blob/develop/LICENSE
- **Bundled at:** `MDPrintView/Preview/Resources/mermaid.min.js`
- **Why bundled:** CSP `script-src 'self'` prohibits remote scripts. App is sandboxed (no network entitlement in v1).
- **Update procedure:**
  1. `curl -fSL "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js" -o MDPrintView/Preview/Resources/mermaid.min.js`
  2. `shasum -a 256 MDPrintView/Preview/Resources/mermaid.min.js`
  3. Update SHA in this file.
  4. Run smoke test from `scripts/smoke.sh` plus open a doc with a mermaid diagram and visually confirm it renders.

---

## katex.min.js

- **Source:** https://cdn.jsdelivr.net/npm/katex@0.16/dist/katex.min.js
- **Version:** 0.16.x (vendored 2026-06-06)
- **SHA-256:** `a29d2961d3146de5949d78ac7c1a9d93ae54955bad22a6db4fbe836e88e8bf48`
- **Size:** 266 KB
- **License:** MIT — https://github.com/KaTeX/KaTeX/blob/main/LICENSE
- **Bundled at:** `MDPrintView/Preview/Resources/katex.min.js`

## katex.min.css

- **Source:** https://cdn.jsdelivr.net/npm/katex@0.16/dist/katex.min.css
- **Version:** 0.16.x (vendored 2026-06-06)
- **SHA-256:** `0289a02cf451a44dd73add683a09644252363871ac11713a647b732cee8b1ee3`
- **Size:** 23 KB
- **License:** MIT (KaTeX project)
- **Bundled at:** `MDPrintView/Preview/Resources/katex.min.css`
- **Known limitation:** This CSS references `fonts/KaTeX_Main-Regular.woff2` and siblings via relative URLs. We do NOT bundle the woff2 files in v1 — math renders with system-fallback font metrics (slightly degraded but functional). Bundling fonts is a v1.1 polish.

## auto-render.min.js

- **Source:** https://cdn.jsdelivr.net/npm/katex@0.16/dist/contrib/auto-render.min.js
- **Version:** 0.16.x (vendored 2026-06-06)
- **SHA-256:** `e5372d199bcdae8b4de71d0f7ceba72a4ba12774a27c60a6f1f77d03b3228ee4`
- **Size:** 3.4 KB
- **License:** MIT (KaTeX contrib)
- **Bundled at:** `MDPrintView/Preview/Resources/auto-render.min.js`
- **Why:** Scans the rendered DOM for `$...$` / `$$...$$` delimiters and replaces them with KaTeX output. Avoids having to pre-process the markdown source.

---

## CSP implications

Bundling Mermaid required relaxing CSP to allow inline script/style and data: image URLs because Mermaid injects those at render time. The relaxation is contained to `MDPrintView/Preview/Resources/preview.html`. KaTeX (W4.B1) will add `font-src 'self' data:`.

The trust boundary is: WebView only loads from `Bundle.main`, never from network. Sandboxed file access prevents arbitrary file reads. CSP `default-src 'none'` denies XHR/fetch/WebSocket. So even with inline-script allowed, an attacker would need to inject content into our bundled assets — not a runtime XSS surface.
