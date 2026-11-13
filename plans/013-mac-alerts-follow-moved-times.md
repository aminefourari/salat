# Plan 013: A Mac prayer alert fires exactly once even when that prayer's time moves after the fact

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat e53b9a6..HEAD -- apps/macos/Salat/Core/Scheduler.swift apps/macos/SalatTests/FixPassTests.swift apps/macos/SalatTests/SchedulerTests.swift apps/macos/SalatTests/RemindersTests.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED (the core alert loop; existing tests pin current behaviour and must all keep passing)
- **Depends on**: plans/009-parity-fixture-schedule-hijri.md (recommended: pins event kinds first)
- **Category**: bug
- **Planned at**: commit `e53b9a6`, 2026-11-13

## Why this matters

`AlertClock` decides which adhans and reminders to fire. Each second it fires the events whose time lies between its
watermark (the last tick) and now, then moves the watermark to now. Only an event's **time** identifies it. When a
prayer's time changes after the fact, this goes wrong:

- **Double adhan.** The official Moroccan (Habous) timetable can arrive mid-day, replacing the 19°/17° calculation, or
  the user can change a minute offset or the Asr school. If the new time is *later* than the already-fired one, the
  same prayer fires again.
- **Missed adhan.** If the new time is *earlier* and has already passed, it's behind the watermark, so it never fires.

After this plan, the clock remembers which (day, prayer, kind) it fired, and which ones it had seen coming. A prayer
whose time moves by ≤ 30 min isn't fired twice. One that moved earlier past "now" fires once (as late). Bigger jumps
(changing city, switching method) keep today's behaviour: "changing settings never replays the past".

## Current state

- `apps/macos/Salat/Core/Scheduler.swift:62-90`:
  ```swift
  /// Events in (lastHandled, now], ignoring anything older than 6 h. `late` = more than 5 min past.
  func dueEvents(days: [DayTimes], modes: [Prayer: AlertMode], reminder: Bool, extras: Extras = [], lastHandled: Date, now: Date) -> [(event: AlertEvent, late: Bool)] {
      let from = max(lastHandled, now - maxBackfill)
      return events(days: days, modes: modes, reminder: reminder, extras: extras)
          .filter { $0.at > from && $0.at <= now }
          .map { ($0, now.timeIntervalSince($0.at) > lateWindow) }
  }

  /// What the alert loop has handled. The watermark moves to `now` on every step, so changing settings or location
  /// never replays the past; only time without steps (Mac asleep) is caught up, within the 6 h cap.
  struct AlertClock {
      private(set) var watermark: Date

      init(saved: Date?, now: Date) { watermark = min(max(saved ?? now, now - lateWindow), now) }

      mutating func step(days: [DayTimes], modes: [Prayer: AlertMode], reminder: Bool, extras: Extras = [], now: Date) -> [(event: AlertEvent, late: Bool)] {
          let due = dueEvents(days: days, modes: modes, reminder: reminder, extras: extras, lastHandled: watermark, now: now)
              .filter { e in
                  switch e.event.kind {
                  case .start: true
                  case .reminder, .jumuah: !e.late && e.event.prayerTime > now
                  case .adhkarMorning, .adhkarEvening, .kahf: !e.late
                  }
              }
          watermark = max(watermark, now)
          return due
      }
  }
  ```
  `events(...)` (private, same file) returns every `AlertEvent { prayer, kind, at, prayerTime }` for the given days,
  sorted by `at`. Also available: `upcomingEvents(days:modes:reminder:extras:after:)` = events strictly after `after`.
- Caller: `apps/macos/Salat/Services/AlertEngine.swift:94`. Each tick:
  `let due = clock.step(days: …, modes: s.modes, reminder: s.reminder, extras: extras, now: now)`. The engine passes
  yesterday, today and tomorrow (adjusted, Habous-overridden) every second.
- Helpers in `Core`: `isoDate(_ c: DateComponents) -> String` (`Core/Habous.swift`), and `MAX_ADJUST` is 30 min on the
  web (Swift settings allow ±30 too).
- Existing tests that pin behaviour and **must keep passing unchanged**:
  - `apps/macos/SalatTests/FixPassTests.swift` `AlertClockTests`:
    - `testSettingsChangeDoesNotReplayPast`: Berlin → Dubai mid-day must fire nothing.
    - `testLateOrStartedRemindersAreSkipped`
    - `testWatermarkNeverInFuture`
  - `SchedulerTests.swift` (`testNoDoubleFire`, `testLateWindow`, …) and `RemindersTests.swift`.
- New test files in `apps/macos/SalatTests/` are picked up automatically (`project.yml` includes the folder).

## Design

Add two in-memory maps to `AlertClock` (they're not persisted; a relaunch only replays the 5-min late window, as today):

- `fired: [String: Date]`: key → the `at` it fired at.
- `pending: [String: Date]`: key → `at`, for events seen **in the future** at the previous step.

Key = `"\(isoDate(day of prayerTime, gregorian, current tz))/\(prayer.rawValue)/\(kind.rawValue)"`.
`let moveTolerance: TimeInterval = 30 * 60`.

`step(...)`:
1. `all = events(days…)` (call the private `events` directly; `step` is in the same file).
2. Candidates:
   - (a) as today: `at` in `(max(watermark, now − maxBackfill), now]`;
   - (b) **plus** rescued: `at ≤ watermark` and `at > now − maxBackfill`, where `pending[key]` exists and
     `|pending[key] − at| ≤ moveTolerance` (seen coming, then moved earlier past now).
3. Drop any candidate whose `fired[key]` exists and `|fired[key] − at| ≤ moveTolerance` (already fired; it only moved).
4. Apply the existing kind filter (late reminders and so on) unchanged. `late` is computed as today.
5. Record each returned event in `fired`.
6. Rebuild `pending` from `all` where `at > now` and key not in `fired`.
7. Prune `fired` to entries with `at > now − 2 days`.
8. `watermark = max(watermark, now)`.

Why the Dubai test still passes: the Berlin → Dubai jump moves each prayer by ~3 h, which is more than the 30-min
tolerance, so nothing is rescued, exactly as today.

## Commands you will need

| Purpose | Command (repo root) | Expected |
|---------|---------------------|----------|
| Swift tests | `npm run mac:test` | `** TEST SUCCEEDED **` |
| Build | `npm run mac:build` | succeeds |

## Scope

**In scope**: `apps/macos/Salat/Core/Scheduler.swift` (`AlertClock` and a small key helper), plus a new
`apps/macos/SalatTests/AlertClockMoveTests.swift`.

**Out of scope**:
- `AlertEngine.swift`. The call site is unchanged.
- `dueEvents` and `upcomingEvents` signatures, which are used by tests and the menu.
- The web cron (it has a similar watermark, but pushes are a separate system).
- Persisting `fired`/`pending`.

## Git workflow

- Branch: `fix/mac-alert-moved-times`. Commit: `fix(macos): don't double-fire or skip a prayer whose time moves`.
- No `Co-Authored-By` / "Generated with" trailers. Don't push or open a PR unless instructed.

## Steps

### Step 1: Write the failing tests

Create `SalatTests/AlertClockMoveTests.swift`. Follow `FixPassTests.swift`: `let all: [Prayer: AlertMode]` all
`.adhan`, and days via `computeDay(lat: 52.52, lon: 13.40, date: DateComponents(year: 2026, month: 11, day: 8), method: .mwl, asr: .standard)!`.
Shift one prayer with `adjustDay(d, [.asr: n])` (in `Core/PrayerCalc.swift`). In each test, create the clock with
`var c = AlertClock(saved: nil, now: <the first step's time − 1 s>)`, so the watermark starts just before the first
step (otherwise an event at exactly the first step's time minus 1 s is already "behind" it). Pass
`days: [d]` (one day is enough) and `reminder: false` unless stated.

1. `testLaterTimeDoesNotRefire`: step at `asr + 1 s` → `[asr start]`. Then step with `adjustDay(d, [.asr: 5])` at
   `asr + 4 min`, then at `asr + 5 min + 1 s` → both return `[]`.
2. `testEarlierTimePastNowStillFires`: step with `d` at `asr − 10 min` (asr pending, nothing due). Then step with
   `adjustDay(d, [.asr: -12])` at `asr − 10 min + 1 s` → returns one `.start` for `.asr`. `late` is `false` (it's 2 min
   past). Run the step again 1 s later → `[]`.
3. `testBigJumpStillDoesNotReplay`: covered by the existing Dubai test. Add an assertion-free comment pointing to it,
   so readers see the tolerance boundary is pinned there.
4. `testReminderMovedLaterDoesNotRefire`: same as 1 with `reminder: true`, stepping across the 10-min-before reminder.

**Verify**: `npm run mac:test` → tests 1, 2 and 4 **fail** (1 and 4 double-fire, 2 returns nothing). Everything else passes.

### Step 2: Implement the design in `AlertClock`

Keep `init(saved:now:)` and `watermark` as they are. Add the two maps and `moveTolerance`, and rewrite `step` per the
Design section. Keep the existing kind filter `switch` verbatim. Add a doc comment to the struct that summarises the
two maps (≤ 3 lines).

**Verify**: `npm run mac:test` → `** TEST SUCCEEDED **`, including the new tests and **all existing**
`AlertClockTests`, `SchedulerTests` and `RemindersTests`.

### Step 3: Build

**Verify**: `npm run mac:build` → succeeds.

## Test plan

The new tests cover: moved later (no refire), moved earlier past now (fires once), reminders moved later (no refire).
The boundary is pinned by the existing Dubai test (a big jump never replays). Every existing scheduler and clock test
is the regression net.

## Done criteria

- [ ] `npm run mac:test` prints `** TEST SUCCEEDED **`, with `AlertClockMoveTests` present
- [ ] `git diff --stat` shows only `Scheduler.swift` and the new test file (plus `plans/README.md`)
- [ ] No existing test was edited (`git diff apps/macos/SalatTests/FixPassTests.swift apps/macos/SalatTests/SchedulerTests.swift apps/macos/SalatTests/RemindersTests.swift` is empty)
- [ ] `plans/README.md` status row updated

## STOP conditions

- An existing test fails after Step 2 and you believe it should change. Report it; don't edit it.
- The behaviour requires changes in `AlertEngine.swift`.
- Test 2's expected `late` value differs from what the design gives. Report the actual value instead of changing the
  design's late rule.

## Maintenance notes

- The 30-min tolerance matches the ±30-minute offset limit. If offsets ever allow more, raise it too.
- `fired`/`pending` live in memory only. After a relaunch the 5-min replay window applies, as before.
- The web push cron has a similar limitation: a changed offset can replay within its 5-min window. It wasn't changed
  here. If it ever matters, the same key idea applies to `last_sent_at`.
