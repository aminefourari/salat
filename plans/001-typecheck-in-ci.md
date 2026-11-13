# Plan 001: CI type-checks the web app before it builds and deploys

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat e53b9a6..HEAD -- apps/web/package.json package.json .github/workflows/ci.yml .github/workflows/release.yml apps/web/tsconfig.json`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `e53b9a6`, 2026-11-13

## Why this matters

`apps/web/tsconfig.json` is strict (`strict`, `noUnusedLocals`, …) but nothing ever runs `tsc`. Vite's build strips types
without checking them, and CI deploys the Cloudflare Worker straight from `main`, so a type error can reach production.
`tsc --noEmit` passes today, so adding it is a pure guard. Every other web plan in `plans/` uses this command as a
verification gate.

## Current state

- `apps/web/package.json` scripts (lines 9-17) — no typecheck:
  ```json
  "scripts": {
    "dev": "vite dev --port 3000",
    "generate-routes": "tsr generate",
    "build": "vite build",
    "preview": "npm run build && vite preview",
    "deploy": "npm run build && wrangler deploy",
    "cf-typegen": "wrangler types",
    "test": "vitest run",
    "db:migrate": "wrangler d1 migrations apply salat --remote"
  },
  ```
- Root `package.json` forwards scripts to the workspace, e.g. `"test": "npm test -w apps/web"`, `"build": "npm run build -w apps/web"`.
- `.github/workflows/ci.yml`, job `web` (lines 15-18):
  ```yaml
      - run: npm ci
      - run: npm test
      - run: npm run build
  ```
- `.github/workflows/release.yml` runs `npm ci` then `npm test` then `npm run mac:test` (the Mac release). It does not
  need the typecheck; leave it alone.
- `apps/web/tsconfig.json` has `"include": ["**/*.ts", "**/*.tsx"]` and `"noEmit": true`, so `tsc --noEmit` with no
  arguments, run in `apps/web`, checks `src/` and `test/`.

## Commands you will need

| Purpose   | Command                                 | Expected on success |
|-----------|-----------------------------------------|---------------------|
| Typecheck | `cd apps/web && npx tsc --noEmit`       | exit 0, no output   |
| Tests     | `npm test` (repo root)                  | all test files pass |
| Build     | `npm run build` (repo root)             | exit 0              |

## Scope

**In scope**:
- `apps/web/package.json` (add one script)
- `package.json` (root, add one forwarding script)
- `.github/workflows/ci.yml` (add one step)

**Out of scope**:
- `release.yml`, because it only ships the Mac app.
- Any change to `tsconfig.json` options. Don't loosen or tighten them.
- Adding ESLint/Prettier/Biome. Lint tooling was deliberately left out.

## Git workflow

- Branch: `ci/typecheck`
- Commit style is conventional, as in `git log`: e.g. `ci: release the Mac app automatically from main`. Use
  `ci: type-check the web app in CI`.
- Do NOT add any `Co-Authored-By` or "Generated with" trailer (the repo owner's rule).
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add the scripts

In `apps/web/package.json` add `"typecheck": "tsc --noEmit"` to `scripts` (put it after `"test"`).
In the root `package.json` add `"typecheck": "npm run typecheck -w apps/web"` (after `"test"`).

**Verify**: `npm run typecheck` (repo root) → exit 0, and the output shows `tsc --noEmit` running with no errors.

### Step 2: Run it in CI before the build

In `.github/workflows/ci.yml`, job `web`, insert `- run: npm run typecheck` between `- run: npm test` and
`- run: npm run build`.

**Verify**: `grep -n "npm run typecheck" .github/workflows/ci.yml` → exactly one match, on the line just before `npm run build`.

### Step 3: Prove the gate catches errors (then undo)

Temporarily add `const x: number = 'a'` to the end of `apps/web/src/lib/i18n.ts`, then run `npm run typecheck`.

**Verify**: exit code non-zero and an error `TS2322` mentioning `i18n.ts`. Then revert the file with
`git checkout apps/web/src/lib/i18n.ts`. `git status` shows only the three in-scope files changed.

## Test plan

No new tests. The verification is Step 3: the gate fails on a planted type error.

## Done criteria

- [ ] `npm run typecheck` exits 0 from the repo root
- [ ] `npm test` passes
- [ ] `grep -c "npm run typecheck" .github/workflows/ci.yml` prints `1`
- [ ] `git status --porcelain` lists only `package.json`, `apps/web/package.json`, `.github/workflows/ci.yml` (plus `plans/README.md`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- `npx tsc --noEmit` in `apps/web` fails *before* you change anything. That means the baseline has regressed. Report
  the errors and don't fix them as part of this plan.
- Typecheck fails because of the generated `src/routeTree.gen.ts`. Report it; don't exclude it.

## Maintenance notes

- New files under `apps/web` are checked automatically through `include`.
- `public/sw.js` is plain JS and is *not* checked. Plan 005 touches it; type-checking it was considered and rejected.
