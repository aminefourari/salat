# Plan 017 (design spike): Per-prayer notification switches on the web, like the Mac's per-prayer alert modes

> **Executor instructions**: This is a **spike**, not a build. Produce the design note and a throwaway prototype on a
> branch. Don't merge. STOP at the end and report. Update this plan's row in `plans/README.md` when done.
>
> **Drift check (run first)**: `git diff --stat e53b9a6..HEAD -- apps/web/src/lib/schedule.ts apps/web/src/lib/client.ts apps/web/src/server/subscribe.ts apps/web/src/routes/settings.tsx apps/web/migrations`

## Status

- **Priority**: P3
- **Effort**: S for the spike (the build is about M)
- **Risk**: LOW
- **Depends on**: plans/002-push-endpoint-validation.md and plans/004-cron-no-duplicate-pushes.md (same files; land those first)
- **Category**: direction
- **Planned at**: commit `e53b9a6`, 2026-11-13

## Why this matters

The Mac app lets each prayer be **adhan / notification / off** (`AlertMode`). The web only has global switches:
"at each prayer" and "10 minutes before". Someone who prays some prayers at the mosque, or doesn't want a Fajr push,
can only turn everything off. The README says the Mac has "the same reminders … as the website", and this is the one
gap. The architecture makes it cheap: `dayEvents` already loops per prayer, and `subscriptions` gains columns through
small migrations (see `0003_reminders.sql`).

## Current state (evidence)

- Web: `apps/web/src/lib/client.ts:9`: `type Notify = { start: boolean; reminder: boolean; adhkar: boolean; friday: boolean }`.
  The switches are in `apps/web/src/routes/settings.tsx:111-124`.
- Web events: `apps/web/src/lib/schedule.ts:29-46` `dayEvents`. `for (const prayer of PRAYERS) { add(sub.notifyReminder, prayer, 'reminder', …); add(sub.notifyStart, prayer, 'start', …) }`.
- Server: `apps/web/src/server/subscribe.ts` `parseSubscribe` maps `notifyStart` → `notify_start` and so on.
  Migration pattern: `apps/web/migrations/0003_reminders.sql` (`ALTER TABLE subscriptions ADD COLUMN … NOT NULL DEFAULT …`).
- Mac: `apps/macos/Salat/Core/Scheduler.swift`, `guard (modes[p] ?? .adhan) != .off`. The UI is in
  `apps/macos/Salat/UI/SettingsView.swift` (around line 143).

## Spike tasks

1. **Data shape.** Propose `notify_prayers INTEGER NOT NULL DEFAULT 31`, a bitmask over `PRAYERS` order (fajr = 1 …
   isha = 16). Default "all on" keeps existing rows unchanged. Compare it with a JSON column, and pick one with one line
   of reasoning.
2. **Semantics.** Decide whether "off" for a prayer also silences its 10-min reminder (Mac: yes, `.off` drops both) and
   Jumuʿah (hangs off Dhuhr). Write it down, mirroring the Mac.
3. **Prototype** on branch `spike/web-per-prayer`:
   - the migration `0004_notify_prayers.sql`;
   - `Sub.notifyPrayers?: number`;
   - the `dayEvents` filter;
   - `parseSubscribe` validation (integer 0-31);
   - five toggles in settings;
   - a `schedule.test.ts` case.
   Don't run `db:migrate` against remote.
4. **Parity.** If plan 009 has landed, say how the shared fixture would cover the new mask. The Mac `modes` maps to it.
5. **i18n.** List the new keys needed in `apps/web/src/lib/i18n.ts` (ar/en/fr).

## Deliverable

`plans/017-findings.md`: the decisions from 1-2 and 5, the prototype diff stat, test results
(`npm test`, `npm run typecheck`), open questions for the owner, and a build estimate. Then STOP.

## STOP conditions

- The prototype needs a change to `cron.ts`'s send loop beyond what plan 004 left. Report it.
- You're tempted to apply the migration to remote D1. Never do that in a spike.
