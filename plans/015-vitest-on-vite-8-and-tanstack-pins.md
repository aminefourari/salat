# Plan 015: Tests run on the same Vite major as the build, and the TanStack tooling is consistent

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat e53b9a6..HEAD -- apps/web/package.json package-lock.json apps/web/vitest.config.ts apps/web/tsr.config.json`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/001-typecheck-in-ci.md (soft)
- **Category**: migration
- **Planned at**: commit `e53b9a6`, 2026-11-13

## Why this matters

The app builds with **Vite 8** (`vite@8.3.6`), but Vitest 3's peer range stops at Vite 7. So npm installed a second,
nested `vite@7.3.7` under `node_modules/vitest/`, and the test suite transforms code (including the `?url` and JSON
imports the Quran/adhkar loaders use) with a different bundler major than production. A passing test run proves less
than it seems, and two copies get installed. Separately, `@tanstack/router-cli` is on a caret range (`^1.132.0`) while
`@tanstack/react-router` and `@tanstack/react-start` are pinned exactly. Its only use is a `generate-routes` script
that nothing calls: the `tanstackStart()` Vite plugin already generates `src/routeTree.gen.ts` on every dev and build.

## Current state

- `apps/web/package.json`:
  - deps: `"@tanstack/react-router": "1.170.46"`, `"@tanstack/react-start": "1.169.5"`
  - devDeps: `"@tanstack/router-cli": "^1.132.0"`, `"vite": "^8.0.0"`, `"vitest": "^3.2.7"`
  - scripts: `"generate-routes": "tsr generate"`
- `apps/web/tsr.config.json` is `{ "target": "react" }` (router-cli config only).
- `package-lock.json` has both `node_modules/vite` 8.3.6 and `node_modules/vitest/node_modules/vite` 7.3.7.
- `npm view vitest@latest peerDependencies.vite` printed `^6.4.0 || ^7.0.0 || ^8.0.0` for `vitest@5.1.0` on 2026-11-13.
- `apps/web/vitest.config.ts`: `defineConfig({ test: { include: ['test/**/*.test.ts'] } })` from `vitest/config`.
- Nothing in `.github/`, `README.md` or `CLAUDE.md` calls `generate-routes` or `tsr`.
- The suite is `npm test` (Vitest, 11 files / 71 tests at plan time).

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Peer check | `npm view vitest@<ver> peerDependencies.vite` | includes `^8` |
| Install | `npm install` (repo root) | exit 0 |
| Tests | `npm test` | all pass |
| Typecheck | `npm run typecheck` | exit 0 |
| Build | `npm run build` | exit 0, `src/routeTree.gen.ts` unchanged |
| Single Vite | `npm ls vite` | only `vite@8.x` entries, deduped |

## Scope

**In scope**: `apps/web/package.json`, `package-lock.json`, `apps/web/tsr.config.json` (delete), and
`apps/web/vitest.config.ts` (only if the new Vitest major requires a config change).

**Out of scope**:
- Upgrading Vite, React, TanStack Start/Router or wrangler.
- Test code changes beyond what the Vitest major's migration guide requires.

## Git workflow

- Branch: `chore/vitest-vite8`. Commit: `chore(web): run tests on Vite 8; drop the unused router CLI`.
- No `Co-Authored-By` / "Generated with" trailers. Don't push or open a PR unless instructed.

## Steps

### Step 1: Pick the Vitest version

Find the lowest Vitest major whose `peerDependencies.vite` includes `^8`:
`npm view vitest@4 peerDependencies.vite` and `npm view vitest@5 peerDependencies.vite`. Use the lowest that
qualifies, to keep the jump small.

**Verify**: write the chosen version and its peer range in your report.

### Step 2: Upgrade and drop the CLI

`cd apps/web && npm install -D vitest@^<major> && npm uninstall @tanstack/router-cli`. Remove the
`"generate-routes"` script and delete `apps/web/tsr.config.json`.

**Verify**: `npm ls vite` (repo root) → every `vite` line is 8.x (`deduped` is fine). No 7.x remains.

### Step 3: Run everything

**Verify**:
- `npm test` → all pass, same test count as before.
- `npm run typecheck` → exit 0.
- `npm run build` → exit 0, and `git diff --quiet apps/web/src/routeTree.gen.ts` succeeds (generation unchanged).

If tests fail because of a Vitest API change, apply the fix from that version's migration guide only.

## Test plan

The existing suite. The point is that it now runs on Vite 8. No new tests.

## Done criteria

- [ ] `npm ls vite` shows no 7.x
- [ ] `npm test`, `npm run typecheck` and `npm run build` all pass, and `routeTree.gen.ts` is unchanged
- [ ] `grep -n "router-cli\|generate-routes" apps/web/package.json` → nothing; `apps/web/tsr.config.json` is gone
- [ ] `plans/README.md` status row updated

## STOP conditions

- No published Vitest version supports Vite 8. Report and stop.
- More than 3 test files need changes for the new Vitest. Report the list; the upgrade is bigger than planned.
- The build regenerates `routeTree.gen.ts` differently once router-cli is gone. That would mean something did use
  it. Restore it and report.

## Maintenance notes

- When Vite gets a new major, check Vitest's peer range in the same PR.
