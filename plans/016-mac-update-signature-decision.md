# Plan 016 (design + optional build): Decide whether Mac updates carry a release signature, and implement it if approved

> **Executor instructions**: This plan has a **decision gate**. Do Phase A, write the decision note, and STOP for the
> owner's answer. Do Phase B only if the operator tells you the owner approved option 2. Run every verification
> command. When done, update this plan's row in `plans/README.md` (unless a reviewer maintains it).
>
> **Drift check (run first)**: `git diff --stat e53b9a6..HEAD -- apps/macos/Salat/Services/Updater.swift apps/macos/Salat/Core/Updates.swift apps/macos/project.yml .github/workflows/release.yml apps/web/src/server/update.ts`
> Plan 012 changes `Updater.swift`/`Updates.swift` on purpose. Any other change → compare with the excerpts, and STOP
> on a mismatch.

## Status

- **Priority**: P3
- **Effort**: M (Phase B)
- **Risk**: MED (a mistake can stop all future updates; the first signed release needs a bootstrap)
- **Depends on**: plans/012-mac-updater-hardening.md (same files; land 012 first)
- **Category**: security
- **Planned at**: commit `e53b9a6`, 2026-11-13

## Why this matters

The Mac app installs updates from the project's own Cloudflare Worker (`/api/update`), which proxies the latest GitHub
Release. Today the checks are:
- SHA-256 equals the digest the Worker reports, which comes from GitHub's asset digest via the same Worker;
- `codesign --verify --deep --strict`;
- the bundle id and version match.

Releases are **ad-hoc signed** (`CODE_SIGN_IDENTITY: "-"`), and `codesign --verify` has no `-R` requirement. It proves
the files match their own signature, not who built them. The swap script then clears quarantine, so Gatekeeper never
looks. The effective trust root is therefore: **whoever controls the Worker (the Cloudflare account) or the GitHub
repo can run code on every installed Mac.**

A detached Ed25519 signature, made in CI with a key whose public half is embedded in the app, removes the
**Cloudflare/Worker** from that trust root. It does **not** protect against a GitHub compromise: the private key would
live in the same repo's Actions secrets, and `release.yml` auto-releases on push to `main`. The owner should weigh that
gain against one more secret to manage.

## Current state

- `apps/macos/project.yml:13-14`: `CODE_SIGN_IDENTITY: "-"`, `CODE_SIGN_STYLE: Manual`.
- `apps/macos/Salat/Services/Updater.swift` `install(_:)`: digest compare, `ditto -x -k`, `codesign --verify --deep --strict`, bundle id/version check, swap.
- `apps/macos/Salat/Core/Updates.swift`: `UpdateInfo { version, sha256, size, notes }`, decoded from the Worker JSON.
- `apps/web/src/server/update.ts`: `parseRelease(r)` builds `UpdateInfo` from GitHub's `releases/latest`, finding
  the asset named `Salat-v${version}.zip`. `downloadZip(v)` streams that zip from
  `https://github.com/aminefourari/salat/releases/download/v${v}/Salat-v${v}.zip`.
- `.github/workflows/release.yml` builds, zips (`ditto -c -k --keepParent … "Salat-${TAG}.zip"`) and runs
  `gh release create "$TAG" "Salat-${TAG}.zip" …`.
- CryptoKit (already imported by `Updater.swift`) has `Curve25519.Signing.PublicKey(rawRepresentation:)` and
  `isValidSignature(_:for:)`.

## Phase A: decision note (always)

Write `plans/016-decision.md` (≤ 1 page) presenting three options to the owner:

1. **Keep as is.** Add one sentence to README's "Install the Mac app" section: "updates are trusted via HTTPS to the
   project's Worker and its GitHub releases". Cost: none.
2. **Ed25519 release signature.**
   - CI signs the zip bytes with a key stored in the GitHub secret `SALAT_UPDATE_SIGNING_KEY` and uploads
     `Salat-vX.Y.Z.zip.sig` as a second release asset.
   - The Worker adds `signature` (base64) to `UpdateInfo`, read from that asset.
   - The app embeds the 32-byte public key and refuses an update whose signature doesn't verify.
   - Gain: a compromised Cloudflare account can't push code. No gain against a GitHub compromise.
   - **Bootstrap**: apps without the key keep accepting unsigned updates, so the first signed release is trusted the
     old way.
3. **Stable self-signed code-signing certificate + `codesign -R`.**
   - Similar gain. It needs a certificate in CI and changes the app's designated requirement, which affects the login
     item and widget.
   - More moving parts than option 2.

Recommend **option 1** for now, unless the owner considers the Cloudflare account the weaker of the two. Option 2 only
moves the trust root to the GitHub account.

**STOP here.** Report the note's path to the operator.

## Phase B: implement option 2 (only when approved)

Scope: `Updates.swift`, `Updater.swift`, `UpdatesTests.swift`, `apps/web/src/server/update.ts`,
`apps/web/test/update.test.ts`, `.github/workflows/release.yml`.

1. **Key pair (owner, not you).** The owner generates an Ed25519 key, stores the raw 32-byte private key base64 as the
   repo secret `SALAT_UPDATE_SIGNING_KEY`, and gives you only the **public** key (base64). Never generate, print or
   commit a private key yourself.
2. **CI.** In `release.yml` after "Zip", add a step that signs `Salat-${TAG}.zip` with the secret. Use a
   `swift -e`/CryptoKit one-liner on the macOS runner, or `openssl pkeyutl -sign -rawin` with an Ed25519 PEM. Write
   `Salat-${TAG}.zip.sig` (raw 64-byte signature, base64) and pass it as a second file to `gh release create`.
   **Verify**: the step runs locally with a throwaway key (`openssl genpkey -algorithm ed25519`) and produces a 64-byte signature.
3. **Worker.** In `parseRelease`, find the asset `Salat-v${version}.zip.sig`. Expose its download URL to the Worker
   (not to the client), fetch it in `latestRelease()` (cached like the release JSON), and add `signature?: string` to
   `UpdateInfo`. Extend `test/update.test.ts` (`parseRelease` cases with and without the `.sig` asset).
   **Verify**: `npm test` passes.
4. **App.** Add `let updateSigningKey = "<public key base64>"` and `signature: String?` (optional, for decoding) in
   `Updates.swift`, plus a pure `func signatureValid(zip: Data, signature: String?, publicKey: String) -> Bool`. In
   `Updater.install`, after the SHA-256 check, `guard signatureValid(...) else { throw UpdateError.checksum }`. Add
   `UpdatesTests` cases with a test key pair made **in the test** via `Curve25519.Signing.PrivateKey()`: valid, tampered
   data, missing signature.
   **Verify**: `npm run mac:test` → `** TEST SUCCEEDED **`.
5. **Rollout.** The release with this code must itself be signed (CI step from item 2 merged first). Note in the PR:
   "after this ships, unsigned releases will be refused by updated apps".

## Done criteria

- Phase A: `plans/016-decision.md` exists, and the plan's status is set to `BLOCKED (awaiting owner decision)`.
- Phase B: all verify commands above pass. `git grep -n "PRIVATE" -- apps .github` shows no key material. Only the
  Phase B scope files are changed.

## STOP conditions

- Anyone asks you to put a private key in a file or in the plan. Refuse and report.
- Plan 012 hasn't landed (`updateSwapScript` missing from `Updates.swift`). The two plans would conflict.

## Maintenance notes

- Key rotation needs an app release that trusts both keys before the old one is retired.
