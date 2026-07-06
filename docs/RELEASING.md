# Releasing MDPrintView

Maintainer-only doc. Covers the standard release process, the secrets the CI relies on, key rotation, and known gotchas.

## TL;DR — shipping a new version

```sh
# 1. Add a section to CHANGELOG.md at the top with the version + date.
#    Move relevant "Planned for vX.Y.Z" bullets into the new section.
#    Update the [Unreleased] and [X.Y.Z] compare links at the bottom.
$EDITOR CHANGELOG.md
git add CHANGELOG.md
git commit -m "docs: CHANGELOG for vX.Y.Z"
git push origin main

# 2. Tag + push. CI does the rest.
git tag -a vX.Y.Z -m "vX.Y.Z — short summary"
git push origin vX.Y.Z
```

Update CHANGELOG.md BEFORE tagging so the "What's New in MDPrintView"
Help-menu item lands on a page that already documents this release.

The push triggers `.github/workflows/release.yml`, which:

1. Imports the Developer ID certificate from secrets
2. Builds `Release` with `MARKETING_VERSION=0.1.1` + `CURRENT_PROJECT_VERSION=<run number>`
3. Re-signs Sparkle's nested binaries (via `scripts/codesign-sparkle.sh`)
4. Builds a `.dmg`, signs it, submits to Apple's notary service, staples the ticket
5. Runs Sparkle's `generate_appcast` with the EdDSA private key to produce a signed appcast entry
6. Publishes a GitHub Release with the `.dmg` attached
7. Commits the updated `appcast.xml` back to `main` so existing installs auto-update

Wall-clock: ~8–15 min, dominated by Apple notarization.

## If the tag push doesn't trigger the workflow

Known quirk on this repo: the very first tag push (v0.1.0) didn't fire the workflow even though the YAML and Actions config were correct. Workaround:

```sh
gh workflow run release.yml -R neomavkda3/MDPrintView -f version=0.1.1
```

Subsequent tag pushes (v0.1.1+) have triggered normally. If you see this regression, file an issue and use the workaround.

## Required GitHub Actions secrets

| Secret | What it is | How to regenerate |
|---|---|---|
| `DEV_ID_APPLICATION_P12_BASE64` | Developer ID Application cert + private key, exported as .p12, base64-encoded | Export via Keychain Access; `base64 -i cert.p12 \| gh secret set DEV_ID_APPLICATION_P12_BASE64` |
| `DEV_ID_APPLICATION_P12_PASSWORD` | Password used when exporting the .p12 | Set when exporting; back up in Apple Passwords |
| `ASC_API_KEY_P8` | App Store Connect API key (raw .p8 contents) | App Store Connect → Users and Access → Integrations → Team Keys → Generate API Key; download the .p8 once |
| `ASC_KEY_ID` | 10-char Key ID matching the .p8 | Shown next to the key in App Store Connect |
| `ASC_ISSUER_ID` | UUID Issuer ID for the team | Shown at the top of the Keys page |
| `SPARKLE_ED_PRIVATE_KEY` | Sparkle EdDSA Ed25519 private key (base64) | `generate_keys -x /tmp/key.txt` (from the Sparkle SPM artifact), then `gh secret set SPARKLE_ED_PRIVATE_KEY < /tmp/key.txt` |

The matching Sparkle **public** key is committed in `MDPrintView/Info.plist` under `SUPublicEDKey`. If you rotate the private key, you must also update the public key in Info.plist and ship a release signed with the *old* private key first (so existing users can install it). After that release, swap to the new key and any further updates will be verified by the new public key.

## Key + cert backup

Each of these has exactly one canonical location + a disaster-recovery backup:

| Item | Canonical | Backup |
|---|---|---|
| Developer ID Application private key | login Keychain on the maintainer's Mac | Apple Passwords (note: "MDPrintView Developer ID .p12") |
| .p12 password | Apple Passwords ("MDPrintView Developer ID .p12 password") | n/a — see note |
| App Store Connect API .p8 | Apple Passwords ("MDPrintView ASC Notarization API Key") | n/a — recoverable by generating a fresh key in App Store Connect |
| Sparkle EdDSA private key | login Keychain (under "Sparkle") | Apple Passwords ("MDPrintView Sparkle Private Key") |

If you lose the Sparkle key **without** a backup, all existing installs of MDPrintView are stuck on whatever version they currently have — you can't ship them any further updates. (You can still distribute new releases on a new key; users would have to download manually.) Keep the Apple Passwords backup current.

## Local release dry-run (no tag push)

`scripts/release.sh` mirrors the CI pipeline for verification. Replace the placeholders below with your own credentials from App Store Connect:

```sh
# Replace XXXXXXXXXX with your 10-char ASC Key ID, and the UUID with your Issuer ID.
export ASC_API_KEY_P8=~/Downloads/AuthKey_XXXXXXXXXX.p8
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export VERSION=0.1.1
./scripts/release.sh
```

This produces a notarized `.dmg` in `build/`. It does **not** push to GitHub Releases or update the appcast — use this purely to test that the signing pipeline still works after changes.

## Known gotchas

- **Sparkle's nested binaries need explicit re-signing.** Sparkle ships its SPM framework with the inner XPC services and Updater.app pre-signed by the Sparkle team. Xcode's automatic codesign uses `--preserve-metadata` for nested binaries, leaving those Sparkle-team signatures intact. Notarization rejects them. `scripts/codesign-sparkle.sh` re-signs each one explicitly with our Developer ID + secure timestamp. CI runs this script automatically; if you ever build Release locally and notarize manually, run it too.
- **`get-task-allow=true` is auto-injected when the entitlements file is empty.** Notary rejects any binary where this entitlement is `true`. `MDPrintView/MDPrintView.entitlements` explicitly sets it to `false` for this reason. Don't remove that line.
- **Hardened Runtime** is required for notarization. `ENABLE_HARDENED_RUNTIME=YES` is set in `project.yml` at the base level and shouldn't be overridden per-config.
- **Tag annotation** matters for `gh release create --generate-notes`. Annotated tags (`-a -m "..."`) give better release-notes context than lightweight tags.
