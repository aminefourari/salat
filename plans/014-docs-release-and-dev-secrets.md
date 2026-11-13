# Plan 014: README and specs match how releases and local push actually work

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat e53b9a6..HEAD -- README.md .gitignore .github/workflows docs/superpowers/specs`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none. Run it **after** the branch `ci/auto-mac-release` (commit `e53b9a6`, "release the Mac app
  automatically from main") is merged to `main`, since it documents that workflow.
- **Category**: docs
- **Planned at**: commit `e53b9a6`, 2026-11-13

## Why this matters

- The README's "Releasing" section says to push a version tag to release. Since `e53b9a6`, **any push to `main` that
  touches `apps/macos/**`, `data/**` or the workflow** auto-releases the next patch version. A maintainer following
  the README could push a tag that collides with an auto-bumped patch. The README also doesn't say that CI deploys the
  Worker and applies D1 migrations from `main`.
- `.gitignore` tries to allow committing `.dev.vars.example` (`!.dev.vars.example` on line 2), but `.dev.vars*` on
  line 7 re-ignores it. Negations must come **after** the pattern they override. There's no example file anyway, and
  local push needs a `VAPID_PRIVATE_KEY` in JWK form that's documented nowhere except a one-line hint in CLAUDE.md.
- The two design specs that CLAUDE.md points agents to still list shipped features as non-goals (Quran on the web,
  per-prayer adjustments, tafsir, Habous download). Agents reading them are told those features are out of scope.

## Current state

- `README.md` "## Releasing" (lines 64-74):
  ```markdown
  ## Releasing

  CI (`.github/workflows/ci.yml`) runs the web and Swift tests on every push to `main` and on pull requests. To publish a
  release, push a version tag:

  ```sh
  git tag v1.0.0 && git push origin v1.0.0
  ```

  `.github/workflows/release.yml` then runs the tests, builds `Salat.app` with that version, and publishes a GitHub
  Release with `Salat-v1.0.0.zip`.
  ```
- `.github/workflows/release.yml` header comment (the source of truth):
  ```yaml
  # A push to main that touches the Mac app (or the data it bundles) releases the next patch version;
  # pushing a tag like v1.2.0 releases that version (for minor/major bumps).
  on:
    push:
      branches: [main]
      paths: ['apps/macos/**', 'data/**', '.github/workflows/release.yml']
      tags: ['v*']
  ```
  The version is the last release's tag + 1 patch (`gh release view`), with `v1.0.0` as the base when there are no releases.
- `.github/workflows/ci.yml`, job `web`: on push to `main` it runs `wrangler d1 migrations apply salat --remote` and
  then `wrangler deploy`, using repo secrets `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.
- `.gitignore` lines 1-8 (line 1 is blank):
  ```

  !.dev.vars.example
  !.env.example
  *.local
  .DS_Store
  .dev.vars
  .dev.vars*
  .env
  ```
  `git check-ignore -v apps/web/.dev.vars.example` currently prints `.gitignore:7:.dev.vars*` (the file is ignored).
- Secrets: the Worker reads `env.VAPID_PRIVATE_KEY` (`apps/web/src/server/push.ts`, passed to `@pushforge/builder` as
  `privateJWK`, i.e. a **JWK JSON string** of an EC P-256 private key). The public half is hard-coded in
  `apps/web/src/lib/config.ts`. `VAPID_SUBJECT` is a var in `apps/web/wrangler.jsonc`. In production the key is set with
  `cd apps/web && npx wrangler secret put VAPID_PRIVATE_KEY`. Locally, wrangler reads `apps/web/.dev.vars`.
- Specs: `docs/superpowers/specs/2026-11-08-salat-pwa-design.md` "## Non-goals" (around lines 63-68) and
  `docs/superpowers/specs/2026-11-09-salat-macos-design.md` "## Non-goals" (around lines 139-146).

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Ignore check | `git check-ignore -v apps/web/.dev.vars.example; echo $?` | prints nothing, then `1` (not ignored) |
| Real secrets still ignored | `git check-ignore apps/web/.dev.vars` | prints the path |

## Scope

**In scope**: `README.md`, `.gitignore`, `apps/web/.dev.vars.example` (create), and the two spec files (Non-goals sections only).

**Out of scope**: `CLAUDE.md` (already correct), the workflows, and any code. Never write a real key into any file.

## Git workflow

- Branch: `docs/release-and-secrets`. Commit: `docs: releases from main, local push secrets, superseded spec non-goals`.
- No `Co-Authored-By` / "Generated with" trailers. Don't push or open a PR unless instructed.

## Steps

### Step 1: Fix `.gitignore` order

Move the two negation lines (`!.dev.vars.example`, `!.env.example`) to just **after** the `.env` line, so they come
after `.dev.vars*` and `.env`.

**Verify**: both commands in the table above give the expected results.

### Step 2: Create `apps/web/.dev.vars.example`

```sh
# Copy to .dev.vars (git-ignored) for `npm run dev`. Never commit the real file.
# VAPID private key as a JWK JSON string (EC P-256), the pair of VAPID_PUBLIC_KEY in src/lib/config.ts.
# Generate a fresh pair for local testing with:  npx @pushforge/builder vapid
# (then put the public key in src/lib/config.ts locally only, and don't commit that change).
VAPID_PRIVATE_KEY=
```

The package ships a `pushforge` CLI (`"bin": { "pushforge": "./dist/lib/commandLine/keys.js" }` in
`node_modules/@pushforge/builder/package.json`). Its README (`node_modules/@pushforge/builder/README.md`,
line ~60) documents `npx @pushforge/builder vapid` as the key generator, which is the command used above. If that line
is no longer in the installed README, write instead: `# Generate with the pushforge CLI from @pushforge/builder (see its README).`

**Verify**: `git status --porcelain apps/web/.dev.vars.example` shows `?? apps/web/.dev.vars.example` (now trackable).

### Step 3: Rewrite README "Releasing"

Replace the section with prose that says:
- CI runs web + Swift tests on every PR and push to `main`. On `main` it also applies D1 migrations and deploys the
  Worker (needs repo secrets `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`).
- Every push to `main` touching `apps/macos/`, `data/` or `release.yml` publishes the **next patch** release
  automatically (`Salat-vX.Y.Z.zip`). Installed apps offer it through Settings → General → Updates.
- For a minor/major bump, push a tag (keep the `git tag v1.2.0 && git push origin v1.2.0` example). Pick a version
  higher than the latest release, and don't reuse one.

Also add to "## Development" one line: `cp apps/web/.dev.vars.example apps/web/.dev.vars` (only needed to send pushes locally).

**Verify**: `grep -n "next patch" README.md` → one match. `grep -n ".dev.vars.example" README.md` → one match.

### Step 4: Mark superseded spec non-goals

Don't delete history. In each spec's "## Non-goals", append ` (superseded: shipped later, see CLAUDE.md)` to each
bullet that has since shipped:
- PWA spec: "no Quran" in the adhan/Quran bullet, and "No per-prayer manual minute adjustments".
- Mac spec: "No translations or tafsir…", "No official Habous timetable download…".
Leave every other bullet as it is.

**Verify**: `grep -c "superseded" docs/superpowers/specs/2026-11-08-salat-pwa-design.md docs/superpowers/specs/2026-11-09-salat-macos-design.md` → each ≥ 1.

## Test plan

There's no code. The verification is the commands in each step.

## Done criteria

- [ ] `git check-ignore apps/web/.dev.vars.example` exits 1, and `git check-ignore apps/web/.dev.vars` exits 0
- [ ] `apps/web/.dev.vars.example` exists and contains no key material (`grep -c "=$" apps/web/.dev.vars.example` → 1)
- [ ] Step 3 and 4 greps satisfied
- [ ] Only in-scope files changed
- [ ] `plans/README.md` status row updated

## STOP conditions

- `release.yml` no longer auto-releases from `main` (the branch wasn't merged, or the approach changed). Then the
  README text in Step 3 would be wrong.
- You find an existing `.dev.vars` with content. Don't open, copy or print it.

## Maintenance notes

- If the release trigger paths change in `release.yml`, update the README sentence listing them.
