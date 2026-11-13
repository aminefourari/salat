# Plan 009: The shared parity fixture also pins reminder events (with offsets) and the Hijri month across web and Mac

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat e53b9a6..HEAD -- apps/web/test/mac-data.test.ts apps/macos/SalatTests/ParityTests.swift apps/web/src/lib/schedule.ts apps/macos/Salat/Core/Scheduler.swift fixtures/parity.json`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW (tests and a generated fixture only)
- **Depends on**: plans/001-typecheck-in-ci.md (soft). If plan 010 is executed, do this one **before** 010: this fixture
  then guards 010's refactor too.
- **Category**: tests
- **Planned at**: commit `e53b9a6`, 2026-11-13

## Why this matters

The web app (TypeScript) and the Mac app (Swift) implement the same rules twice. The project rule (CLAUDE.md) is that
they agree. For prayer times and country lookup that's enforced: the web test suite generates `fixtures/parity.json`
from the web code, and a Swift test checks the Swift port against it. The **reminder events** aren't covered: 10 min
before, the adhkar 20 min after Fajr/Asr, Friday Kahf at sunrise + 1 h, Jumuʿah at Dhuhr − 45 min, and the user's
per-prayer minute offsets on top. Neither is the **Hijri month**, which drives the Ramadan line and comes from
`Intl`'s Umm al-Qura calendar on the web and Foundation's on the Mac. Each side has its own hand-written tests, so
changing a constant on one side passes both suites while the apps disagree. The two sides even compute "is it Friday"
differently. After this plan, both are in the shared fixture.

## Current state

- **Generator**: `apps/web/test/mac-data.test.ts`. `PLACES` holds `[name, lat, lon, tz]`. `DATES = ['2026-01-15',
  '2026-03-29', '2026-06-21', '2026-11-08']`. `check(file, build)` writes the file when `UPDATE_MAC_DATA=1`, then asserts
  the committed file equals what the web code produces now. The fixture test today:
  ```ts
  it('parity fixture matches the web code', () =>
    check(new URL('fixtures/parity.json', root), () => ({ prayer: prayerCases(), country: countryCases() })))
  ```
  `prayerCases()` stores times as **unix minutes** (`Math.floor(ms / 60_000)`), never local HH:mm, because the two
  apps' time-zone databases can differ.
- **Web event rules**: `apps/web/src/lib/schedule.ts`.
  `dayEvents(sub: { notifyStart, notifyReminder, notifyAdhkar?, notifyFriday? }, date: string, day: DayTimes): DueEvent[]`
  where `DueEvent = { prayer, kind, at: Date, prayerTime: Date }` and `kind` is one of
  `'start' | 'reminder' | 'adhkarMorning' | 'adhkarEvening' | 'kahf' | 'jumuah'`. Friday is decided from the
  **date string**: `isFriday(date)`.
- **Web offsets**: `adjustDay(day, adjust)` in `apps/web/src/lib/prayer.ts`. `adjust` is e.g. `{ maghrib: 3 }`.
- **Web Hijri**: `hijriDate(d: Date, offset: number, lang): { month, label } | null` in `apps/web/src/lib/prayer.ts`
  (Intl `islamic-umalqura`).
- **Swift consumer**: `apps/macos/SalatTests/ParityTests.swift`:
  ```swift
  struct Fixture: Decodable {
      struct PrayerCase: Decodable { let lat, lon: Double; let date, tz: String; let method: MethodId; let asr: AsrSchool; let times: [String: Int] }
      struct CountryCase: Decodable { let lat, lon: Double; let cc: String? }
      let prayer: [PrayerCase]; let country: [CountryCase]
  }
  ```
- **Swift event rules**: `apps/macos/Salat/Core/Scheduler.swift`. The public entry point that returns all events is
  `upcomingEvents(days: [DayTimes], modes: [Prayer: AlertMode], reminder: Bool, extras: Extras = [], after: Date) -> [AlertEvent]`,
  with `AlertEvent { prayer: Prayer; kind: Kind; at: Date; prayerTime: Date }`. `Kind`'s raw values are the same
  strings as the web's `kind`, and `Prayer`'s raw values are `fajr…isha`. Friday is decided by
  `isFriday(_ d: DayTimes, tz: TimeZone = .autoupdatingCurrent)`, the weekday of **Dhuhr in the machine's time zone**.
  Extras: `[.adhkar, .friday]`.
- **Swift offsets**: `adjustDay(_ d: DayTimes, _ adjust: [Prayer: Int]?) -> DayTimes` in `Core/PrayerCalc.swift`.
- **Swift Hijri**: `hijriMonth(_ d: Date, offset: Int) -> Int` in `Core/PrayerCalc.swift`.
- **Swift prayer day**: `computeDay(lat:lon:date: DateComponents, method:asr:) -> DayTimes?`.
- All these Swift files are in `Salat/Core`, which the test target compiles.

## Commands you will need

| Purpose | Command (repo root) | Expected |
|---------|---------------------|----------|
| Regenerate fixture | `UPDATE_MAC_DATA=1 npm test` | all pass; `fixtures/parity.json` rewritten |
| Web tests | `npm test` | all pass |
| Typecheck | `npm run typecheck` (or `cd apps/web && npx tsc --noEmit`) | exit 0 |
| Swift tests | `npm run mac:test` | `** TEST SUCCEEDED **` |

## Scope

**In scope**: `apps/web/test/mac-data.test.ts`, `fixtures/parity.json` (regenerated, never hand-edited),
`apps/macos/SalatTests/ParityTests.swift`.

**Out of scope**:
- Any production code in `lib/` or `Core/`. If the new checks find a real disagreement, STOP (see below).
- i18n strings. They differ on purpose ("tap" vs "click").
- `rubInfo`/`RubInfo`. That's a one-line formula, already unit-tested on both sides.

## Git workflow

- Branch: `test/parity-schedule-hijri`. Commit: `test: pin reminder events and Hijri month in the parity fixture`.
- No `Co-Authored-By` / "Generated with" trailers. Don't push or open a PR unless instructed.

## Steps

### Step 1: Generate schedule cases on the web side

In `mac-data.test.ts` import `adjustDay` and `hijriDate` from `../src/lib/prayer` and `dayEvents` from
`../src/lib/schedule`, then add:

```ts
// Places whose Dhuhr is near noon UTC, so the Mac's "Friday = weekday of Dhuhr in the machine's zone" agrees with
// the date for any machine zone within ±10 h (CI runs in UTC).
const EVENT_PLACES = PLACES.filter(([n]) => ['Hagenow', 'Casablanca', 'Paris'].includes(n))
const EVENT_DATES = ['2026-03-27', '2026-06-21', '2026-11-13'] // two Fridays and a Sunday
const ADJUSTS = [{}, { fajr: -2, maghrib: 3, isha: 30 }]

function scheduleCases() {
  const out = []
  for (const [, lat, lon, tz] of EVENT_PLACES)
    for (const date of EVENT_DATES)
      for (const adjust of ADJUSTS) {
        const s: Settings = { method: 'auto', asr: 'standard', lang: 'en' }
        const day = adjustDay(computeDay(lat, lon, date, tz, s), adjust)
        const events = dayEvents({ notifyStart: true, notifyReminder: true, notifyAdhkar: true, notifyFriday: true }, date, day)
          .map(e => ({ kind: e.kind, prayer: e.prayer, at: Math.floor(e.at.getTime() / 60_000) }))
          .sort((a, b) => a.at - b.at || a.kind.localeCompare(b.kind) || a.prayer.localeCompare(b.prayer))
        out.push({ lat, lon, date, method: resolveMethod(lat, lon, s), asr: 'standard', adjust, events })
      }
  return out
}

/** Umm al-Qura month at noon UTC every 5 days through 2026–2027 (covers two Ramadans and every month boundary area). */
function hijriCases() {
  const out = []
  for (let t = Date.UTC(2026, 0, 1, 12); t < Date.UTC(2028, 0, 1, 12); t += 5 * 86_400_000)
    out.push({ ms: t, month: hijriDate(new Date(t), 0, 'en')!.month })
  return out
}
```

Change the fixture test to `({ prayer: prayerCases(), country: countryCases(), schedule: scheduleCases(), hijri: hijriCases() })`.

**Verify**: `UPDATE_MAC_DATA=1 npm test` → all pass. `git diff --stat fixtures/parity.json` shows it changed, and
`node -e "const f=require('./fixtures/parity.json');console.log(f.schedule.length, f.hijri.length, f.schedule[0].events.length)"`
prints `18 146 <n>`, where n is 10 (5 prayers × start+reminder) + 2 (adhkar) + 2 if Friday. Then run `npm test` without
the env var → still passes.

`resolveMethod` returns the concrete method (e.g. `aachen` for Hagenow), which is what the Swift side needs.

### Step 2: Check them on the Mac side

In `ParityTests.swift`, extend `Fixture`:

```swift
struct EventCase: Decodable { let kind, prayer: String; let at: Int }
struct ScheduleCase: Decodable { let lat, lon: Double; let date: String; let method: MethodId; let asr: AsrSchool; let adjust: [String: Int]; let events: [EventCase] }
struct HijriCase: Decodable { let ms: Double; let month: Int }
let prayer: [PrayerCase]; let country: [CountryCase]; let schedule: [ScheduleCase]; let hijri: [HijriCase]
```

Add:

```swift
func testScheduleParity() {
    let modes = Dictionary(uniqueKeysWithValues: Prayer.allCases.map { ($0, AlertMode.adhan) })
    for c in Self.fixture.schedule {
        let p = c.date.split(separator: "-").map { Int($0)! }
        guard let raw = computeDay(lat: c.lat, lon: c.lon, date: DateComponents(year: p[0], month: p[1], day: p[2]), method: c.method, asr: c.asr)
        else { XCTFail("nil for \(c.date)"); continue }
        let adjust = Dictionary(uniqueKeysWithValues: c.adjust.map { (Prayer(rawValue: $0.key)!, $0.value) })
        let got = upcomingEvents(days: [adjustDay(raw, adjust)], modes: modes, reminder: true, extras: [.adhkar, .friday], after: .distantPast)
            .map { "\(Int($0.at.timeIntervalSince1970 / 60)) \($0.kind.rawValue) \($0.prayer.rawValue)" }.sorted()
        let want = c.events.map { "\($0.at) \($0.kind) \($0.prayer)" }.sorted()
        XCTAssertEqual(got, want, "\(c.lat),\(c.lon) \(c.date) \(c.adjust)")
    }
    XCTAssertEqual(Self.fixture.schedule.count, 18)
}

func testHijriParity() {
    for c in Self.fixture.hijri {
        XCTAssertEqual(hijriMonth(Date(timeIntervalSince1970: c.ms / 1000), offset: 0), c.month, "\(c.ms)")
    }
}
```

Both sides sort by the same `"<minute> <kind> <prayer>"` string, so the order matches.

**Verify**: `npm run mac:test` → `** TEST SUCCEEDED **`, with 2 more tests than before.

### Step 3: Prove the guard bites (then revert)

Temporarily change `ADHKAR_AFTER_MIN = 20` to `21` in `apps/web/src/lib/schedule.ts`, then run `npm test`.
**Verify**: the `mac data export` fixture test fails. Revert with `git checkout apps/web/src/lib/schedule.ts`.

## Test plan

These checks are the tests: 18 schedule cases (3 places × 3 dates × 2 offset sets, including Fridays and a +30 min
Isha) and 146 Hijri-month samples, each checked on both platforms.

## Done criteria

- [ ] `npm test` passes without `UPDATE_MAC_DATA`; `npm run typecheck` exits 0
- [ ] `npm run mac:test` prints `** TEST SUCCEEDED **`, including `testScheduleParity` and `testHijriParity`
- [ ] Step 3 showed a failure and was reverted (`git diff apps/web/src/lib/schedule.ts` is empty)
- [ ] Only the three in-scope files are modified
- [ ] `plans/README.md` status row updated

## STOP conditions

- `testScheduleParity` or `testHijriParity` fails on unchanged production code. **That's a real web↔Mac
  disagreement** (e.g. the Friday rule, or ICU vs Foundation Umm al-Qura tables). Report the first failing case's
  message, and don't change production code or drop cases to make it pass.
- `hijriDate` returns `null` in Node (Intl without the Islamic calendar). Report it.

## Maintenance notes

- New reminder kinds must be added to `dayEvents` and to Swift's `events()`. This test then fails until both agree,
  which is the point. Regenerate with `UPDATE_MAC_DATA=1 npm test`.
- The Friday-place restriction is deliberate (see the comment). Don't add places far from UTC to `EVENT_PLACES`
  without first making Swift's `isFriday` take the place's time zone.
