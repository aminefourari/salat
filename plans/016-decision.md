# Plan 016 decision note: Mac update authenticity

Today an update is accepted when its SHA-256 matches the digest our Worker reports (from GitHub's asset digest),
`codesign --verify` passes (ad-hoc signature: integrity, not authorship), and the bundle id/version match. Trust root:
HTTPS to our Worker (Cloudflare account) and the GitHub repo.

| Option | Removes from trust root | Cost |
|---|---|---|
| 1. Keep, document it (applied) | nothing | none |
| 2. Ed25519 signature made in CI | the Cloudflare account | one GitHub secret; the key lives in the same repo, so a GitHub compromise still wins |
| 3. Stable self-signed cert + `codesign -R` | the Cloudflare account | certificate in CI; changes the designated requirement (login item, widget) |

Applied: option 1 (one sentence in README's install section). To move to option 2, generate an Ed25519 key yourself,
store the private half as the repo secret `SALAT_UPDATE_SIGNING_KEY`, and hand over only the public key; plan 016
Phase B then applies.
