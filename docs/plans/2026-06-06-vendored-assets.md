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
- **Bundled at:** `mdview/Preview/Resources/mermaid.min.js`
- **Why bundled:** CSP `script-src 'self'` prohibits remote scripts. App is sandboxed (no network entitlement in v1).
- **Update procedure:**
  1. `curl -fSL "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js" -o mdview/Preview/Resources/mermaid.min.js`
  2. `shasum -a 256 mdview/Preview/Resources/mermaid.min.js`
  3. Update SHA in this file.
  4. Run smoke test from `scripts/smoke.sh` plus open a doc with a mermaid diagram and visually confirm it renders.

---

## CSP implications

Bundling Mermaid required relaxing CSP to allow inline script/style and data: image URLs because Mermaid injects those at render time. The relaxation is contained to `mdview/Preview/Resources/preview.html`. KaTeX (W4.B1) will add `font-src 'self' data:`.

The trust boundary is: WebView only loads from `Bundle.main`, never from network. Sandboxed file access prevents arbitrary file reads. CSP `default-src 'none'` denies XHR/fetch/WebSocket. So even with inline-script allowed, an attacker would need to inject content into our bundled assets — not a runtime XSS surface.
