# Plan 010: The browser no longer downloads the world-borders polygons on every first load

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat e53b9a6..HEAD -- apps/web/src apps/web/test`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED (touches how the calculation method is chosen everywhere; guarded by the parity fixture)
- **Depends on**: plans/001-typecheck-in-ci.md (**hard**: the typechecker finds every call site), plans/009-parity-fixture-schedule-hijri.md (recommended first: it also pins reminder events)
- **Category**: perf
- **Planned at**: commit `e53b9a6`, 2026-11-13

## Why this matters

With "auto" method, the app picks the calculation method from the user's country (Germany → Aachen, Morocco →
Habous/19°, …). It finds the country with `@rapideditor/country-coder`, a point-in-polygon lookup over a world-borders
GeoJSON. Because `lib/prayer.ts` imports it statically and the pages import `lib/prayer.ts`, the whole borders dataset
ships in the **eager** client entry chunk. Today `dist/client/assets/client-*.js` is about 662 KB and contains a
`FeatureCollection`. Every first load on a phone downloads and parses roughly 600 KB to map one lat/lon to a country.
Yet the browser already **stores** the country with the location (`Loc.country`).

After this plan, prayer functions take the country (or a resolved method) as an argument, and only the Worker, the
tests, and one lazily-loaded client chunk import country-coder. Computed times must stay **identical**. The committed
parity fixture (`fixtures/parity.json`) proves that: `npm test` fails if any time changes.

## Current state

- `apps/web/src/lib/methods.ts:1,21`:
  ```ts
  import { iso1A2Code } from '@rapideditor/country-coder'
  ...
  export const countryAt = (lat: number, lon: number): string | null => iso1A2Code([lon, lat]) ?? null
  ```
  It also exports `MethodId`, `METHOD_IDS` and `methodForCountry(iso2)`. Those stay.
- `apps/web/src/lib/prayer.ts`:
  ```ts
  import { countryAt, methodForCountry, type MethodId } from './methods'
  ...
  export type Settings = { method: MethodId | 'auto'; asr: 'standard' | 'hanafi'; lang: Lang; adjust?: Adjust; hijri?: number }
  ...
  export const resolveMethod = (lat: number, lon: number, s: Settings): MethodId =>
    s.method === 'auto' ? methodForCountry(countryAt(lat, lon)) : s.method
  export const usesHabous = (lat: number, lon: number, s: Settings) => resolveMethod(lat, lon, s) === 'morocco' && s.asr === 'standard'
  export function computeDay(lat: number, lon: number, date: string, _tz: string, s: Settings, params?: CalculationParameters): DayTimes {
    ...
    const pt = new PrayerTimes(new Coordinates(lat, lon), new Date(y, m - 1, d), params ?? paramsFor(resolveMethod(lat, lon, s), s.asr))
  ...
  export const hijriOffset = (lat: number, lon: number, s: Settings) => s.hijri ?? (resolveMethod(lat, lon, s) === 'morocco' ? -1 : 0)
  ```
- Every production caller (from `grep -rnE "computeDay|usesHabous|hijriOffset\(|resolveMethod|countryAt" apps/web/src`):
  - `src/lib/client.ts:69`, saving a new location: `write<Loc>(KEYS.loc, { ...next, at: Date.now(), country: countryAt(next.lat, next.lon) })`
  - `src/lib/client.ts:169`: `const on = !!loc && usesHabous(loc.lat, loc.lon, s)`
  - `src/lib/client.ts:209-210`: `dayFor = (loc, s, date, habous) => adjustDay(habous?.[date] ? toDay(habous[date]) : computeDay(loc.lat, loc.lon, date, tz(), s), s.adjust)`
  - `src/lib/schedule.ts:53` (`dueEvents`): `computeDay(sub.lat, sub.lon, date, sub.tz, sub.settings)`
  - `src/server/cron.ts:27` (`habousDayTimes`): `if (!usesHabous(sub.lat, sub.lon, sub.settings)) return undefined`
  - `src/routes/index.tsx:65`: `hijriOffset(loc.lat, loc.lon, settings)`. Line 112: `resolveMethod(loc.lat, loc.lon, settings) === 'morocco'`
  - `src/routes/settings.tsx:39`: `resolveMethod(loc.lat, loc.lon, { ...s, method: 'auto' })`. Line 76: `hijriOffset(loc.lat, loc.lon, { ...s, hijri: undefined })`
  - `src/routes/month.tsx:58`: `resolveMethod(loc.lat, loc.lon, settings) === 'morocco'`
- `Loc` in `client.ts:8`: `{ lat: number; lon: number; at: number; country: string | null; city?: string | null }`. Every
  stored location already has `country`.
- `Sub` in `src/lib/schedule.ts:3`: `{ lat; lon; tz; settings; notifyStart; notifyReminder; lastSentAt; notifyAdhkar?; notifyFriday? }`.
  `toSub(row)` in `src/server/cron.ts:36` builds it from a D1 row (the row has `lat`/`lon`, no country).
- Tests calling these: `test/prayer.test.ts`, `test/schedule.test.ts`, `test/cron.test.ts`, `test/habous.test.ts`,
  `test/hijri.test.ts`, `test/mac-data.test.ts` (it also imports `iso1A2Code` directly). Most pass a concrete method
  (`'aachen'`, `'morocco'`, `'mwl'`). `mac-data.test.ts` loops over `[...METHOD_IDS, 'auto']`.
- The Swift port already takes a resolved method: `computeDay(lat:lon:date:method:asr:)` in
  `apps/macos/Salat/Core/PrayerCalc.swift`. This plan moves the web closer to it.

## Target design

1. New file `src/lib/country.ts`, the **only** module importing country-coder (besides `test/mac-data.test.ts`):
   ```ts
   import { iso1A2Code } from '@rapideditor/country-coder'
   /** ISO country at a point (bundled world borders, ~600 KB: import from the Worker, tests, or lazily in the browser). */
   export const countryAt = (lat: number, lon: number): string | null => iso1A2Code([lon, lat]) ?? null
   ```
   `methods.ts` loses its country-coder import and `countryAt`.
2. In `prayer.ts`, with `export type Resolved = Omit<Settings, 'method'> & { method: MethodId }`:
   - `resolveMethod(country: string | null, s: Settings): MethodId`
   - `resolved(country: string | null, s: Settings): Resolved` → `({ ...s, method: resolveMethod(country, s) })`
   - `usesHabous(country: string | null, s: Settings): boolean`
   - `hijriOffset(country: string | null, s: Settings): number`
   - `computeDay(lat, lon, date, _tz, s: Resolved, params?)` uses `paramsFor(s.method, s.asr)`. The type now
     **forbids** `'auto'`, so the compiler lists every caller that has to resolve first. Callers that pass a literal
     concrete method (most tests) compile unchanged.
3. `Sub` gets `country: string | null`. `toSub` sets it with `countryAt(r.lat, r.lon)` (Worker side, imported from
   `../lib/country`). `dueEvents` calls `computeDay(..., resolved(sub.country, sub.settings))`.
4. The client never imports `lib/country.ts` statically. On a new location fix it loads it lazily:
   `import('./country').then(({ countryAt }) => write<Loc>(KEYS.loc, { ...next, at: Date.now(), country: countryAt(next.lat, next.lon) }))`.
   The location is saved once the country is known, so the times never render with a guessed method. `syncPush()` and
   `resolveCity()` must run after that write, inside the same `.then`.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Typecheck | `npm run typecheck` | exit 0 |
| Tests | `npm test` | all pass **without** `UPDATE_MAC_DATA` (the fixture must not change) |
| Build | `npm run build` | exit 0 |
| Measure | `ls -l apps/web/dist/client/assets/client-*.js` | see Step 6 |

## Scope

**In scope**: `src/lib/country.ts` (create), `src/lib/methods.ts`, `src/lib/prayer.ts`, `src/lib/schedule.ts`,
`src/lib/client.ts`, `src/server/cron.ts`, `src/routes/index.tsx`, `src/routes/settings.tsx`, `src/routes/month.tsx`,
and test files under `apps/web/test/` (only to adapt call signatures). All paths are under `apps/web/`.

**Out of scope**:
- `fixtures/parity.json` and the Mac resources. **Never** run `UPDATE_MAC_DATA=1` in this plan: the unchanged
  fixture is the proof of no behaviour change.
- The Swift app.
- `server/cities.ts` and `/api/place`.
- Removing `countryAt` from the Worker. The cron still needs it.

## Git workflow

- Branch: `perf/country-lookup-off-client`. Commit per step is fine. The final message is
  `perf(web): keep the world borders out of the client bundle`.
- No `Co-Authored-By` / "Generated with" trailers. Don't push or open a PR unless instructed.

## Steps

### Step 1: Record the baseline

`npm run build && ls -l apps/web/dist/client/assets/client-*.js && grep -c FeatureCollection apps/web/dist/client/assets/client-*.js`
Write down the size (about 662 KB) and the count (≥ 1).

### Step 2: Create `lib/country.ts`; slim `methods.ts`

As in Target design 1. Then update imports: `test/mac-data.test.ts` may keep its direct country-coder import. Any other
importer of `countryAt` from `./methods` now imports from `./country`.

**Verify**: `npm run typecheck`. Errors are expected only where `countryAt` was imported from `methods`. Fix those
imports, and nothing else yet.

### Step 3: Change the `prayer.ts` signatures

As in Target design 2. Remove `countryAt` from `prayer.ts`'s imports. `prayer.ts` must not import `./country`.

**Verify**: `npm run typecheck` now lists the callers. Go through them in Steps 4-5. Don't use `as` casts to silence
errors. Each caller resolves with the country it has.

### Step 4: Worker and shared lib callers

- `schedule.ts`: add `country: string | null` to `Sub`. In `dueEvents` use `resolved(sub.country, sub.settings)`.
  `dayEvents` takes `Omit<Sub, … 'settings'>`. Also omit `'country'` there, so callers of `dayEvents` (tests,
  mac-data) don't need it.
- `cron.ts`: in `toSub`, add `country: countryAt(r.lat, r.lon)` (import from `'../lib/country'`). In `habousDayTimes`,
  use `usesHabous(sub.country, sub.settings)`.

### Step 5: Client callers

- `client.ts:69`: the lazy import from Target design 4. The block becomes:
  ```ts
  if (!prev || km(prev, next) > 5) {
    // The borders data is ~600 KB: loaded only when the device moves to a new place (then cached by the service worker).
    import('./country').then(({ countryAt }) => {
      write<Loc>(KEYS.loc, { ...next, at: Date.now(), country: countryAt(next.lat, next.lon) })
      syncPush().catch(() => {})
      resolveCity()
    }).catch(() => {})
  } else resolveCity()
  ```
  The original calls `resolveCity()` unconditionally after the `if`. Keep that behaviour. Also keep `setStatus('ok')`
  where it was.
- `client.ts:169`: `usesHabous(loc.country, s)`.
- `client.ts` `dayFor`: `computeDay(loc.lat, loc.lon, date, tz(), resolved(loc.country, s))`.
- `routes/index.tsx`, `settings.tsx`, `month.tsx`: replace `(loc.lat, loc.lon, X)` with `(loc.country, X)` for
  `resolveMethod` and `hijriOffset`.

### Step 6: Tests compile and the fixture is unchanged

Adapt the test call sites the compiler flags:
- `computeDay(..., { method: 'auto', … })` → `computeDay(..., resolved(countryAt(lat, lon), s))`, importing `countryAt`
  from `../src/lib/country`.
- Subs built by hand in `schedule.test.ts` get `country: countryAt(lat, lon)`, or a literal like `'DE'` if the test
  means a fixed country.
- In `mac-data.test.ts` `prayerCases()`, use `const r = resolved(countryAt(lat, lon), s)` and pass `r` to
  `computeDay`. The stored `method` becomes `r.method`.

**Verify**: `npm run typecheck` → exit 0. `npm test` → **all pass, without `UPDATE_MAC_DATA`**. `git status
fixtures/` → clean.

### Step 7: Measure

`npm run build`, then:
- `grep -c FeatureCollection apps/web/dist/client/assets/client-*.js` → `0`
- `grep -l FeatureCollection apps/web/dist/client/assets/*.js` → exactly one file (the lazy `country-*.js` chunk)
- `ls -l apps/web/dist/client/assets/client-*.js` → at least 400 KB smaller than the Step 1 baseline

Record both sizes in your report.

## Test plan

There's no new unit test. The guard is the existing `test/mac-data.test.ts` parity check: 840 prayer cases including
`'auto'` for 7 places, compared with the committed fixture. It must pass unchanged. `cron.test.ts` and
`habous.test.ts` cover the Worker path (`toSub`, `usesHabous` for Moroccan rows).

## Done criteria

- [ ] `npm run typecheck` exits 0; `npm test` exits 0 with no fixture change (`git diff --quiet fixtures/` succeeds)
- [ ] `grep -rn "country-coder" apps/web/src` → only `src/lib/country.ts`
- [ ] `grep -rn "from './country'\|from \"./country\"" apps/web/src/lib/prayer.ts` → nothing
- [ ] Step 7 measurements met
- [ ] `plans/README.md` status row updated

## STOP conditions

- `npm test` fails in `mac-data.test.ts` ("parity fixture matches the web code"). A time changed, so the refactor
  altered behaviour. Don't regenerate the fixture. Find the caller that resolves differently, or report.
- After Step 7, `FeatureCollection` is still in `client-*.js`. Something still imports `lib/country` (or
  country-coder) statically on the client. Report the import chain (`grep -rn "country" apps/web/src/routes apps/web/src/lib`).
- A caller has no country available and would need a network call to get one. Report it; don't add one.

## Maintenance notes

- Rule after this plan: browser code passes `loc.country`. Only the Worker and tests call `countryAt`.
- If the Swift parity rule is ever applied to signatures, note that `computeDay(…, Resolved)` now matches Swift's
  `computeDay(…, method:, asr:)`.
- If plan 005 has landed, the lazy `country-*.js` chunk is precached by the service worker (it's referenced as
  `./country-….js` from the entry chunk), so a first location fix while offline still works after one online visit.
