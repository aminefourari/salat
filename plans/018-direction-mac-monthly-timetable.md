# Plan 018 (design spike): A monthly timetable on the Mac, matching the web's printable `/month`

> **Executor instructions**: This is a **spike**. Produce a design note and a prototype on a branch. Don't merge.
> STOP at the end and report. Update this plan's row in `plans/README.md` when done.
>
> **Drift check (run first)**: `git diff --stat e53b9a6..HEAD -- apps/macos/Salat/UI apps/macos/Salat/Services/AlertEngine.swift apps/web/src/routes/month.tsx`

## Status

- **Priority**: P3
- **Effort**: S for the spike (the build is about M)
- **Risk**: LOW
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `e53b9a6`, 2026-11-13

## Why this matters

The web has a printable monthly timetable (`apps/web/src/routes/month.tsx`: a month table, prev/next month, today and
Fridays highlighted, an "official/approximate" note, a print button). The Mac app has no month view. Its window
sections are prayer times, Quran and adhkar (`AppSection` in `apps/macos/Salat/UI/MainView.swift`). Everything the
view needs already exists in Swift:
- `computeDay(lat:lon:date:method:asr:)` and `adjustDay` in `Core/PrayerCalc.swift`;
- Habous days in `Core/Habous.swift` (`habousDay`);
- the resolved location and method in `AlertEngine` (`loc`, `method`).
So it's mostly UI work.

## Current state (evidence)

- Web: `month.tsx` uses `useMonth(loc, settings, month, now)` from `src/lib/client.ts:213-224`. That's `dayFor` for each
  day, with Habous when cached (only the fetched months; other months are calculated).
- Mac: `MainView.swift` has `enum AppSection: String, CaseIterable { case prayer, quran, adhkar }` with ⌘1-3 shortcuts.
  The prayer section is in `UI/MenuView.swift`/`MainView.swift`. `AlertEngine` (`Services/AlertEngine.swift`) exposes
  `loc`, `method`, `today`, `tomorrow`, and `settings.d.habous` / `adjust`.
- The UI must follow `UI/Theme.swift` (the website's look). The CLAUDE.md rule for Mac UI changes: verify with
  `Salat.app/Contents/MacOS/Salat -snapshot DIR` (dark and light) and refresh `docs/screenshots/`.

## Spike tasks

1. **Placement.** Decide between a 4th `AppSection` (`.month`, ⌘4) and a sheet from the prayer section. Write
   trade-offs in two lines each.
2. **Data.** Write a pure `func monthDays(lat:lon:month:method:asr:adjust:habous:) -> [(date: String, day: DayTimes, official: Bool)]`
   in `Core/` (so it can be tested; add it to the test target sources in `project.yml` if it's a new file). Add one
   test: 30 days for 2026-11 at Hagenow, where day 8 equals `computeDay` + `adjustDay`.
3. **Prototype view** on branch `spike/mac-month`: a SwiftUI `Grid` or `Table` with the same columns as the web
   (`fajr, sunrise, dhuhr, asr, maghrib, isha`), and prev/next. Printing (`NSPrintOperation` on the view) is optional
   in the spike.
4. **Snapshot.** Run `npm run mac:build`, then `apps/macos/build/Salat.app/Contents/MacOS/Salat -snapshot /tmp/salat-snap`.
   If the snapshot mode doesn't render the new section, note what `UI/Snapshots.swift` would need.
5. **Strings.** List the new `L10nKey`s needed in `Core/L10n.swift` (ar/en/fr).

## Deliverable

`plans/018-findings.md`: decisions, the prototype diff stat, `npm run mac:test` result, snapshot paths, open questions,
and a build estimate. Then STOP.

## STOP conditions

- The prototype requires changing `AlertEngine`'s tick logic. The month view should read, not compute alerts.
