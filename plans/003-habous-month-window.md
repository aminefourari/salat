# Plan 003: `/api/habous` only serves months near today, so callers can't make the Worker hammer habous.gov.ma

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat e53b9a6..HEAD -- apps/web/src/routes/api/habous.ts apps/web/src/server/habous.ts apps/web/test/habous.test.ts`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/001-typecheck-in-ci.md (soft)
- **Category**: security
- **Planned at**: commit `e53b9a6`, 2026-11-13

## Why this matters

`GET /api/habous?lat&lon&month=YYYY-MM` accepts any month from `0000-01` to `9999-12`. Each month not yet in D1 makes
the Worker fetch `https://www.habous.gov.ma/data/horaires-YYYY-MM.js`. The 10-minute failure back-off lives in memory
per isolate, so it doesn't stop a caller cycling through thousands of month values. That can get the Worker's egress
blocked by the ministry site, which breaks the real monthly import that Moroccan users (web, push and Mac) rely on.
Real clients only ever ask for the current or next month.

## Current state

- `apps/web/src/routes/api/habous.ts` (server route, whole handler):
  ```ts
  GET: async ({ request }) => {
    const q = new URL(request.url).searchParams
    const lat = Number(q.get('lat')), lon = Number(q.get('lon')), month = q.get('month') ?? ''
    if (!q.get('lat') || !q.get('lon') || !(Math.abs(lat) <= 90) || !(Math.abs(lon) <= 180) || !/^\d{4}-(0[1-9]|1[0-2])$/.test(month))
      return Response.json({ error: 'bad request' }, { status: 400 })
    // 404: no listed city near, the client calculates for good. 502: Habous down, the client retries later.
    if (habousCity(lat, lon) == null) return Response.json({ error: 'no habous city near' }, { status: 404 })
    const days = await habousDays(d1HabousStore(env.DB), lat, lon, Array.from({ length: 31 }, (_, i) => `${month}-${String(i + 1).padStart(2, '0')}`))
    ...
  ```
- `apps/web/src/server/habous.ts` holds the pure Habous helpers (`parseMonth`, `habousCity`, `habousDay`, `monthRows`) and
  `ensureMonth` (the fetch with the in-memory back-off, lines 94-116).
- Who calls the route, and which months they ask for:
  - Web `apps/web/src/lib/client.ts:175`: the month of today or tomorrow, in the device's time zone.
  - Mac `apps/macos/Salat/Core/Habous.swift:38` `habousMonthToFetch`: the month of today or tomorrow.
  - The cron does NOT use the route. It calls `ensureMonth` directly, including next month from the 25th
    (`server/cron.ts` `prefetchHabous`).
- `dateIn(now: Date, tz: string): string` (YYYY-MM-DD) is exported from `apps/web/src/lib/prayer.ts`, and `cron.ts`
  already uses it with `'Africa/Casablanca'`.
- The test pattern is `apps/web/test/habous.test.ts` (plain `describe`/`it`/`expect`).

## Commands you will need

| Purpose   | Command                                                 | Expected |
|-----------|---------------------------------------------------------|----------|
| Typecheck | `npm run typecheck` (or `cd apps/web && npx tsc --noEmit`) | exit 0 |
| Test file | `cd apps/web && npx vitest run test/habous.test.ts`     | all pass |
| All tests | `npm test`                                              | all pass |

## Scope

**In scope**: `apps/web/src/server/habous.ts`, `apps/web/src/routes/api/habous.ts`, `apps/web/test/habous.test.ts`.

**Out of scope**: `ensureMonth`'s back-off, `cron.ts` and `prefetchHabous` (the cron is trusted), the clients.

## Git workflow

- Branch: `fix/habous-month-window`. Commit: `fix(web): only serve Habous months near today`.
- No `Co-Authored-By` / "Generated with" trailers. Don't push or open a PR unless instructed.

## Steps

### Step 1: Add a pure window check to `server/habous.ts`

```ts
/** Months a client may ask for: last month to next month, Moroccan calendar (clients ask for today's or tomorrow's). */
export function monthInWindow(ym: string, now: Date): boolean {
  const [y, m] = dateIn(now, 'Africa/Casablanca').split('-').map(Number)
  const [qy, qm] = ym.split('-').map(Number)
  const diff = (qy * 12 + qm) - (y * 12 + m)
  return diff >= -1 && diff <= 1
}
```

Import `dateIn` from `'../lib/prayer'`. `habous.ts` already imports `type DayTimes` from there, so add `dateIn` to that
same import.

**Verify**: `npm run typecheck` → exit 0.

### Step 2: Use it in the route

In `routes/api/habous.ts`, right after the existing 400 check, add:

```ts
    if (!monthInWindow(month, new Date())) return Response.json({ error: 'month out of range' }, { status: 400 })
```

and import `monthInWindow` from `'../../server/habous'`. Use 400, not 404. On a 404 the web client stores `none: true`
and stops asking for good (`client.ts:181`), and the Mac stops for that place and month. A 400 just retries later.

**Verify**: `npm run typecheck` → exit 0.

### Step 3: Tests

In `test/habous.test.ts`, import `monthInWindow` and add:

```ts
  it('only allows last month to next month (Moroccan date)', () => {
    const now = new Date('2026-11-15T12:00:00Z')
    expect(['2026-10', '2026-11', '2026-12'].map(m => monthInWindow(m, now))).toEqual([true, true, true])
    expect(['2026-09', '2027-01', '0000-01', '9999-12'].map(m => monthInWindow(m, now))).toEqual([false, false, false, false])
    // Year boundary, and 23:30 UTC on Dec 31 is already Jan 1 in Casablanca (GMT+1)
    expect(monthInWindow('2027-01', new Date('2026-12-20T12:00:00Z'))).toBe(true)
    expect(monthInWindow('2026-11', new Date('2026-12-31T23:30:00Z'))).toBe(false)
  })
```

Morocco is on GMT+1 except during Ramadan. If the last assertion fails because the date falls inside a Ramadan GMT+0
period in the tz database, STOP and report. Don't change the expected value.

**Verify**: `cd apps/web && npx vitest run test/habous.test.ts` → all pass, including the new test.

## Test plan

Step 3 covers in-window, out-of-window, extreme years, year rollover and the Casablanca-vs-UTC day boundary.

## Done criteria

- [ ] `npm run typecheck` exits 0; `npm test` exits 0
- [ ] `grep -n "monthInWindow" apps/web/src/routes/api/habous.ts` shows one import and one use
- [ ] Only the three in-scope files are modified
- [ ] `plans/README.md` status row updated

## STOP conditions

- You find a client that asks for a month outside current ±1 (search for `/api/habous` in `apps/web/src` and
  `habousURL` in `apps/macos`). Report it; don't widen the window on your own.
- The route has gained more callers or parameters since this plan was written (the drift check shows changes).

## Maintenance notes

- If a client is ever changed to prefetch two months ahead, widen the window here in the same PR.
- `failedAt` in `ensureMonth` still grows per isolate, but now with at most 3 keys per month, so it's bounded.
