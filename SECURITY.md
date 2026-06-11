# Security policy

## Reporting a vulnerability

If you've found a security issue in MDPrintView — anything that could compromise a user's documents, files, or system — please report it privately rather than opening a public issue.

**Email**: `reeseandchris@gmail.com` with `[SECURITY]` in the subject.

What to include:

- A short description of the issue
- Steps to reproduce or proof-of-concept (if applicable)
- The MDPrintView version (visible in **MDPrintView → About**)
- Your macOS version

## What to expect

- **Acknowledgement**: within 48 hours
- **Initial assessment**: within 5 business days
- **Fix timeline**: depends on severity; we'll communicate one once we've reproduced the issue
- **Disclosure**: we'll coordinate public disclosure with you after a fix ships, crediting you if you'd like

## Scope

In scope:

- The MDPrintView binary distributed via GitHub Releases (DMG)
- The build pipeline (`.github/workflows/release.yml`, `scripts/*`)
- The vendored third-party JavaScript / CSS in `MDPrintView/Preview/Resources/`
- The Sparkle auto-update path (signed appcast, EdDSA verification)

Out of scope:

- Vulnerabilities in upstream Apple frameworks (please report those to Apple)
- Vulnerabilities in Sparkle itself (please report those to the [Sparkle project](https://github.com/sparkle-project/Sparkle/security))
- Issues caused by running MDPrintView against tampered or maliciously-crafted Markdown when WKWebView's sandbox correctly contains them
