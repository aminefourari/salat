# Plan 004: The cron never re-sends a notification that was already delivered

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat e53b9a6..HEAD -- apps/web/src/server/cron.ts apps/web/src/lib/schedule.ts apps/web/test/cron.test.ts`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/001-typecheck-in-ci.md (soft)
- **Category**: bug
- **Planned at**: commit `e53b9a6`, 2026-11-13

## Why this matters

Each minute the Worker cron (`runCron`) finds the due events for every push subscription and sends them. When one of a
row's events fails with a transient error, the row's `last_sent_at` watermark isn't moved at all. On the next minute
every event in the 5-minute window is sent again, including those already delivered. This repeats for up to 5 minutes.
Users get duplicate "Isha in 10 minutes" or adhkar notifications whenever a push service has a hiccup. After this
plan, the watermark moves past everything that was delivered and stops at the first failure.

## Current state

- `apps/web/src/server/cron.ts:70-88`:
  ```ts
  export async function runCron(store: Store, now: Date, send: (r: Row, p: Payload) => Promise<SendResult>, dayTimesFor?: DayTimesFor) {
    for (const row of await store.all()) {
      try {
        const sub = toSub(row)
        const events = dueEvents(sub, now, await dayTimesFor?.(row, now))
        if (!events.length) continue
        let ok = true
        for (const e of events) {
          const res = await send(row, payloadFor(e, sub.settings.lang, row.tz))
          if (res === 'gone') { await store.remove(row.endpoint); ok = false; break }
          if (res === 'error') ok = false
        }
        // On a transient error leave last_sent_at alone so the next minute retries (within the 5-min window).
        if (ok) await store.markSent(row.endpoint, now.getTime())
      } catch (err) {
        console.error('cron row failed', row.endpoint.slice(0, 60), err)
      }
    }
  }
  ```
- `apps/web/src/lib/schedule.ts:49-60`. `dueEvents` returns the events with `at` in `(max(lastSentAt, now − 5 min), now]`,
  **sorted by `at` ascending**:
  ```ts
  const from = Math.max(sub.lastSentAt, now.getTime() - MAX_LATE)
  ...
    .filter(e => e.at.getTime() > from && e.at.getTime() <= to)
    .sort((a, b) => a.at.getTime() - b.at.getTime())
  ```
  So setting `last_sent_at = X` makes the next run skip every event with `at <= X`.
- The test pattern is `apps/web/test/cron.test.ts`. `memStore(rows)` is an in-memory `Store`, and `row(endpoint)`
  builds a Hagenow subscription with `notify_start: 1, notify_reminder: 1`. `now` is 10 s after Isha on 2026-11-08,
  and the row's `last_sent_at` is `now − 60 s`.

## Commands you will need

| Purpose   | Command                                             | Expected |
|-----------|-----------------------------------------------------|----------|
| Typecheck | `npm run typecheck` (or `cd apps/web && npx tsc --noEmit`) | exit 0 |
| Test file | `cd apps/web && npx vitest run test/cron.test.ts`   | all pass |
| All tests | `npm test`                                          | all pass |

## Scope

**In scope**: `apps/web/src/server/cron.ts` (the `runCron` body only) and `apps/web/test/cron.test.ts`.

**Out of scope**:
- `lib/schedule.ts`. Its window logic is right and is mirrored by the Mac's `Scheduler.swift`.
- `d1Store`, plus overlapping cron runs and parallel sends. Those are scale concerns, deliberately deferred (see the
  `ponytail:` comment above `runCron`).

## Git workflow

- Branch: `fix/cron-partial-failure`. Commit: `fix(web): don't re-send delivered pushes after a partial failure`.
- No `Co-Authored-By` / "Generated with" trailers. Don't push or open a PR unless instructed.

## Steps

### Step 1: Write the failing test first

The bug needs two events due in the same run, and real prayer times are never that close. `runCron`'s 4th argument
(`dayTimesFor`) overrides a day's times, so use it to put Asr and Maghrib 1 minute apart. With `last_sent_at: 0` the
window is `(now − 5 min, now]`. The payload `tag` is `` `${prayer}-${kind}` `` (see `payloadFor`).

In `test/cron.test.ts`, inside `describe('runCron', …)`, add:

```ts
  it('after a partial failure, retries only what was not delivered', async () => {
    const t0 = new Date('2026-11-08T17:00:00Z')
    const day = { fajr: new Date(t0.getTime() - 6 * 3600_000), sunrise: new Date(t0.getTime() - 5 * 3600_000), dhuhr: new Date(t0.getTime() - 4 * 3600_000),
      asr: new Date(t0.getTime() - 60_000), maghrib: t0, isha: new Date(t0.getTime() + 3600_000) }
    const store = memStore([{ ...row('https://p/1'), notify_reminder: 0, last_sent_at: 0 }])
    const dayTimesFor = async () => (date: string) => (date === '2026-11-08' ? day : null)
    const sent: string[] = []
    // Minute 1: Asr start succeeds, Maghrib start fails.
    await runCron(store, new Date(t0.getTime() + 1000), async (_, p) => { sent.push(p.tag); return p.tag.startsWith('maghrib') ? 'error' : 'ok' }, dayTimesFor)
    expect(sent).toEqual(['asr-start', 'maghrib-start'])
    // Minute 2: only Maghrib is retried.
    sent.length = 0
    await runCron(store, new Date(t0.getTime() + 61_000), async (_, p) => { sent.push(p.tag); return 'ok' }, dayTimesFor)
    expect(sent).toEqual(['maghrib-start'])
    // Minute 3: nothing left.
    sent.length = 0
    await runCron(store, new Date(t0.getTime() + 121_000), async (_, p) => { sent.push(p.tag); return 'ok' }, dayTimesFor)
    expect(sent).toEqual([])
  })
```

(The `day` object needs the `DayTimes` type: `import { type DayTimes } from '../src/lib/prayer'` and annotate it.
For dates other than 2026-11-08 the returned `null` makes `dueEvents` calculate, and those days' events are outside
the window.)

**Verify**: `cd apps/web && npx vitest run test/cron.test.ts` → the new test **fails**: minute 2 sends
`['asr-start', 'maghrib-start']`. This confirms the bug.

### Step 2: Move the watermark per delivered event

Replace the inner loop and the `markSent` in `runCron` with:

```ts
        // Events are sorted by time. On the first transient error stop, and move last_sent_at to just before that
        // event, so the next minute retries it and everything after it, but nothing already delivered.
        let failedAt: number | null = null
        for (const e of events) {
          const res = await send(row, payloadFor(e, sub.settings.lang, row.tz))
          if (res === 'gone') { await store.remove(row.endpoint); failedAt = -1; break }
          if (res === 'error') { failedAt = e.at.getTime(); break }
        }
        if (failedAt === null) await store.markSent(row.endpoint, now.getTime())
        else if (failedAt > 0 && failedAt - 1 > row.last_sent_at) await store.markSent(row.endpoint, failedAt - 1)
```

Notes:
- `failedAt - 1`: two events can share the same `at`, e.g. on Friday. If the first was delivered and the second
  failed, both are retried. A rare duplicate is better than a lost notification.
- `failedAt = -1` for `'gone'` means the row is deleted, so there's nothing to mark.
- The `failedAt - 1 > row.last_sent_at` guard skips a pointless write when the very first event failed.

Update the comment above it, and delete the old `// On a transient error leave last_sent_at alone…` comment.

**Verify**: `cd apps/web && npx vitest run test/cron.test.ts` → all pass, including the new test.

### Step 3: Full suite

**Verify**: `npm run typecheck` → exit 0; `npm test` → all pass.

## Test plan

The new test in Step 1 (a regression test for this bug) together with the existing four `runCron` tests: single
send, gone removal, one row throwing, i18n copy.

## Done criteria

- [ ] `npm run typecheck` exits 0; `npm test` exits 0
- [ ] `grep -n "let ok = true" apps/web/src/server/cron.ts` returns nothing
- [ ] Only `cron.ts` and `cron.test.ts` are modified
- [ ] `plans/README.md` status row updated

## STOP conditions

- `dueEvents` no longer sorts by `at`, or no longer filters with `at > lastSentAt` (check `lib/schedule.ts`). The
  watermark logic relies on both.
- The new test still fails after Step 2 because of how `dayTimesFor` is applied (e.g. `adjustDay` or the date
  lookup). Report what `dueEvents` returned instead of reshaping the test until it passes.

## Maintenance notes

- If sends ever become parallel (a scale change), this per-event watermark has to become "the earliest failed event",
  not "the first in iteration order".
- The Mac app has its own, separate alert clock (`apps/macos/Salat/Core/Scheduler.swift`, `AlertClock`). It doesn't
  have this issue, because a local notification can't fail transiently.
