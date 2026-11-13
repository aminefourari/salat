# Plan 008: The web's Habous month-pick and merge logic is pure, mirrored on the Swift names, and tested

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat e53b9a6..HEAD -- apps/web/src/lib/client.ts`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW (a behaviour-preserving extraction)
- **Depends on**: plans/001-typecheck-in-ci.md (soft)
- **Category**: tests
- **Planned at**: commit `e53b9a6`, 2026-11-13

## Why this matters

For Moroccan users the web app shows the official Habous timetable, fetched a month at a time from the Worker and
kept in `localStorage`. Two pieces of logic live inline inside a React hook, untested:

- which month to fetch next (today's, tomorrow's across a month boundary, or none);
- how a fetched month merges with what's stored (keep from yesterday on for the same place, start over for a new place).

If either regresses, Moroccan web users silently fall back to calculated times. The Mac app has the same logic as pure
functions with tests (`habousMonthToFetch`, `mergeHabous` in `apps/macos/Salat/Core/Habous.swift`). After this plan the
web has the same, under the same names, with the Swift test cases ported.

## Current state

- `apps/web/src/lib/client.ts:161-193`:
  ```ts
  /** Official Habous days for one place (YYYY-MM-DD → epoch ms), fetched a month at a time; `none` = no Habous city near. */
  type Habous = { place: string; days: Record<string, number[]>; none?: boolean }
  const HABOUS_KEYS = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'] as const
  const toDay = (ms: number[]) => Object.fromEntries(HABOUS_KEYS.map((k, i) => [k, new Date(ms[i])])) as DayTimes
  const NO_HABOUS: Habous = { place: '', days: {} }

  /** Official Habous times for Morocco: asks our Worker for a whole month once, then reads it locally (and offline). */
  function useHabous(loc: Loc | null, s: Settings, date: string): Habous['days'] | null {
    const on = !!loc && usesHabous(loc.lat, loc.lon, s)
    const place = on ? `${loc.lat.toFixed(3)},${loc.lon.toFixed(3)}` : ''
    const saved = useStored<Habous>('salat.habous', NO_HABOUS, NO_HABOUS)[0]
    const mine = saved.place === place
    // The month still missing for today or tomorrow, if any.
    const tomorrow = nextDate(date)
    const month = !place || (mine && saved.none) ? '' : !(mine && saved.days[date]) ? date.slice(0, 7) : !saved.days[tomorrow] ? tomorrow.slice(0, 7) : ''
    useEffect(() => {
      if (!month) return
      const [lat, lon] = place.split(',')
      fetch(`/api/habous?lat=${lat}&lon=${lon}&month=${month}`)
        .then(async r => {
          if (r.status === 404) return write<Habous>('salat.habous', { place, days: {}, none: true })
          if (!r.ok) return // Habous down or month not published yet: calculated meanwhile, asked again next open
          const { days } = (await r.json()) as Pick<Habous, 'days'>
          const cur = read<Habous>('salat.habous', NO_HABOUS)
          // Same place: keep what we have from yesterday on, add the new month. Another place: start over.
          const yesterday = new Date(Date.parse(`${date}T12:00:00Z`) - 86_400_000).toISOString().slice(0, 10)
          const kept = cur.place === place ? Object.fromEntries(Object.entries(cur.days).filter(([d]) => d >= yesterday)) : {}
          write<Habous>('salat.habous', { place, days: { ...kept, ...days } })
        })
        .catch(() => {})
    }, [place, month, date])
    return on && mine ? saved.days : null
  }
  ```
- `nextDate(date)` is exported from `apps/web/src/lib/prayer.ts`.
- The Swift reference is `apps/macos/Salat/Core/Habous.swift`:
  ```swift
  func habousMonthToFetch(_ h: HabousDays?, place: String, today: DateComponents, tomorrow: DateComponents) -> String? {
      for d in [today, tomorrow] where habousDay(h, place: place, date: d) == nil { return String(isoDate(d).prefix(7)) }
      return nil
  }
  func mergeHabous(_ old: HabousDays?, place: String, fetched: [String: [Double]], keepFrom: String) -> HabousDays {
      var days = old?.place == place ? old!.days.filter { $0.key >= keepFrom } : [:]
      days.merge(fetched) { _, new in new }
      return HabousDays(place: place, days: days)
  }
  ```
  The web adds one thing Swift doesn't have: `none: true` (a 404 means no Habous city is near, so stop asking for that place).
- Pure-lib test pattern: `apps/web/test/quran.test.ts` imports from `../src/lib/quran` and uses `describe`/`it`/`expect`.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Typecheck | `npm run typecheck` (or `cd apps/web && npx tsc --noEmit`) | exit 0 |
| Test file | `cd apps/web && npx vitest run test/habous-days.test.ts` | all pass |
| All tests | `npm test` | all pass |

## Scope

**In scope**: `apps/web/src/lib/client.ts`, `apps/web/src/lib/habous-days.ts` (create),
`apps/web/test/habous-days.test.ts` (create).

**Out of scope**:
- `apps/web/src/server/habous.ts`, which is Worker-side Habous code with a different job.
- Any behaviour change, including the stale-response race when the place changes mid-fetch (rejected as self-healing).
- The Swift files.

## Git workflow

- Branch: `test/web-habous-days`. Commit: `test(web): extract and test the Habous month and merge logic`.
- No `Co-Authored-By` / "Generated with" trailers. Don't push or open a PR unless instructed.

## Steps

### Step 1: Create `src/lib/habous-days.ts`

```ts
// Official Habous days kept on the device (pure; mirrors apps/macos/Salat/Core/Habous.swift).
import { nextDate } from './prayer'

/** Days for one place (YYYY-MM-DD → six epoch ms: Fajr, sunrise, Dhuhr, Asr, Maghrib, Isha); `none` = no Habous city near. */
export type HabousDays = { place: string; days: Record<string, number[]>; none?: boolean }

/** The month (YYYY-MM) to fetch so that `date` and the day after are official; '' when nothing is missing or asking is pointless. */
export function habousMonthToFetch(saved: HabousDays, place: string, date: string): string {
  if (!place) return ''
  const mine = saved.place === place
  if (mine && saved.none) return ''
  if (!(mine && saved.days[date])) return date.slice(0, 7)
  const tomorrow = nextDate(date)
  return saved.days[tomorrow] ? '' : tomorrow.slice(0, 7)
}

/** Adds a fetched month: the same place keeps its days from `keepFrom` on, another place starts over. */
export function mergeHabous(cur: HabousDays, place: string, fetched: Record<string, number[]>, keepFrom: string): HabousDays {
  const kept = cur.place === place ? Object.fromEntries(Object.entries(cur.days).filter(([d]) => d >= keepFrom)) : {}
  return { place, days: { ...kept, ...fetched } }
}
```

The month expression is the same as the inline one, written out as statements. Check it against the original
ternary: `!place || (mine && none)` → `''`; today missing → today's month; tomorrow missing → tomorrow's month; else `''`.

**Verify**: `npm run typecheck` → exit 0.

### Step 2: Use them in `client.ts`

In `client.ts`:
- Remove the local `type Habous` and import `type HabousDays` instead. Rename uses of `Habous` to `HabousDays`
  (`NO_HABOUS`, `useStored<…>`, `read<…>`, `write<…>`, the `Pick<…>`, and `dayFor`'s parameter type
  `Habous['days']` → `HabousDays['days']`).
- Replace the `const tomorrow = …` / `const month = …` lines with `const month = habousMonthToFetch(saved, place, date)`.
  Keep `const mine = saved.place === place`, because the hook's `return` still uses it.
- Replace the merge lines (`const cur = …` through the `write` call) with:
  ```ts
  const yesterday = new Date(Date.parse(`${date}T12:00:00Z`) - 86_400_000).toISOString().slice(0, 10)
  write<HabousDays>('salat.habous', mergeHabous(read<HabousDays>('salat.habous', NO_HABOUS), place, days, yesterday))
  ```
  Keep the comment "Same place: keep what we have from yesterday on…" above it.

**Verify**: `npm run typecheck` → exit 0. `grep -n "nextDate" apps/web/src/lib/client.ts`: if `nextDate` is still
used elsewhere in the file (it is, in `useDays`), keep its import. Otherwise tsc's `noUnusedLocals` will tell you to
remove it.

### Step 3: Port the Swift tests

Create `test/habous-days.test.ts` with these cases (the same data as `apps/macos/SalatTests/HabousTests.swift`):

```ts
import { describe, expect, it } from 'vitest'
import { habousMonthToFetch, mergeHabous, type HabousDays } from '../src/lib/habous-days'

const place = '33.573,-7.590'
const nov: HabousDays = { place, days: Object.fromEntries(Array.from({ length: 30 }, (_, i) => [`2026-11-${String(i + 1).padStart(2, '0')}`, [0, 0, 0, 0, 0, 0]])) }
const empty: HabousDays = { place: '', days: {} }

describe('habousMonthToFetch', () => {
  it('asks for the missing month only', () => {
    expect(habousMonthToFetch(empty, place, '2026-11-11')).toBe('2026-11')
    expect(habousMonthToFetch(nov, place, '2026-11-11')).toBe('')          // cached: no request
    expect(habousMonthToFetch(nov, place, '2026-11-30')).toBe('2026-12')   // tomorrow is in December
    expect(habousMonthToFetch(nov, '34.020,-6.840', '2026-11-11')).toBe('2026-11') // another place
  })
  it('never asks without a place, or for a place with no Habous city', () => {
    expect(habousMonthToFetch(nov, '', '2026-11-11')).toBe('')
    expect(habousMonthToFetch({ place, days: {}, none: true }, place, '2026-11-11')).toBe('')
    expect(habousMonthToFetch({ place: 'x', days: {}, none: true }, place, '2026-11-11')).toBe('2026-11')
  })
})

describe('mergeHabous', () => {
  it('keeps recent days for the same place only', () => {
    const old: HabousDays = { place, days: { '2026-11-09': [1], '2026-11-10': [2], '2026-11-11': [3] } }
    expect(Object.keys(mergeHabous(old, place, { '2026-11-12': [4] }, '2026-11-10').days).sort()).toEqual(['2026-11-10', '2026-11-11', '2026-11-12'])
    expect(Object.keys(mergeHabous(old, '1.000,2.000', { '2026-11-12': [4] }, '2026-11-10').days)).toEqual(['2026-11-12'])
    expect(mergeHabous({ ...old, none: true }, place, {}, '2026-11-10').none).toBeUndefined()
  })
})
```

**Verify**: `cd apps/web && npx vitest run test/habous-days.test.ts` → 3 passed.

## Test plan

Step 3: month pick (fresh, cached, month boundary, other place, no place, `none`) and merge (same place trims, other
place replaces, `none` cleared). Pattern: `test/quran.test.ts`.

## Done criteria

- [ ] `npm run typecheck` exits 0; `npm test` exits 0, including `test/habous-days.test.ts`
- [ ] `grep -n "Object.entries(cur.days)" apps/web/src/lib/client.ts` returns nothing
- [ ] Only the three in-scope files are touched
- [ ] `plans/README.md` status row updated

## STOP conditions

- A ported Swift case fails against the extracted function. That means the web and Mac behave differently today.
  Report which case, and don't change either side to match.
- `client.ts` changed since the plan (drift check), and the inline expressions differ from the excerpts.

## Maintenance notes

- `habous-days.ts` and `Core/Habous.swift` now carry the same function names. A change to one should be ported to the
  other (CLAUDE.md's parity rule).
