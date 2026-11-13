# Plan 019 (design spike): Quran bookmarks with the same semantics on web and Mac

> **Executor instructions**: This is a **spike**: a design note plus, optionally, a web-only prototype on a branch.
> Don't merge. STOP at the end and report. Update this plan's row in `plans/README.md` when done.
>
> **Drift check (run first)**: `git diff --stat e53b9a6..HEAD -- apps/web/src/lib/client.ts apps/web/src/routes/quran.tsx apps/macos/Salat/Core/Settings.swift apps/macos/Salat/UI/QuranView.swift`

## Status

- **Priority**: P3
- **Effort**: S for the spike (the build is about M, across both apps)
- **Risk**: LOW
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `e53b9a6`, 2026-11-13

## Why this matters

The Mac design spec lists "No search, bookmarks or memorization tools in the Quran (not requested; can come later)"
(`docs/superpowers/specs/2026-11-09-salat-macos-design.md`, Non-goals). It's the last "can come later" item that hasn't
shipped. Both apps keep exactly **one** reading position per device. Readers following a khatm, now helped by the
juz/hizb markers (`rubInfo`, `hizbStarts`), may want a few named bookmarks. This is a product call for the owner.
The spike makes the call cheap.

## Current state (evidence)

- Web: `apps/web/src/lib/client.ts:234-236`:
  ```ts
  export type ReadPrefs = { reciter: number; surah: number; ayah: number; adhkar: number }
  const DEFAULT_READ: ReadPrefs = { reciter: 7, surah: 1, ayah: 1, adhkar: 27 }
  export const useReadPrefs = () => useStored<ReadPrefs>('salat.read', DEFAULT_READ, DEFAULT_READ)
  ```
  `apps/web/src/routes/quran.tsx:46-48` shows a "continue reading" link from `prefs.surah`/`prefs.ayah`.
  `useStored` merges stored JSON over defaults (`{ ...fallback, ...JSON.parse(raw) }`), so adding a field is backward compatible.
- Mac: `apps/macos/Salat/Core/Settings.swift`: `var lastSurah = 1`, `var lastAyah = 1` in `AppSettings.Data`. New
  fields must be **optional** ("Fields added later are optional so older saved settings still decode", line 24).
  Used in `apps/macos/Salat/UI/QuranView.swift:46-50,177-200`.
- Per-device state only. The project has no accounts or sync, by design (CLAUDE.md: "No accounts, analytics…").
  Bookmarks stay local, and there's no cross-device sync.

## Spike tasks

1. **Semantics.** Propose `bookmarks: { surah: number; ayah: number; at: number }[]` (max ~20, newest first) on both
   platforms. Decide:
   - how to add one (long-press/context menu on an ayah);
   - how to remove one;
   - whether the existing "last position" stays separate (recommended: yes).
2. **Web prototype** on branch `spike/quran-bookmarks`:
   - extend `ReadPrefs` with `bookmarks?`;
   - add an ayah context action in `quran.tsx`;
   - add a bookmarks list on the surah list page;
   - add a pure helper `toggleBookmark(list, surah, ayah, now)` in `src/lib/quran.ts`, with tests in `test/quran.test.ts`.
3. **Mac mapping.** Describe (no code) the `bookmarks: [Bookmark]?` field in `AppSettings.Data` and where it shows in
   `QuranView`.
4. **Search** (separate question). In two paragraphs, assess Arabic full-text search over `data/quran.json`: diacritic
   normalisation, and size and speed in the browser. Don't prototype it.

## Deliverable

`plans/019-findings.md`: decisions, the prototype diff stat and test results (`npm test`, `npm run typecheck`), the Mac
mapping, the search assessment, and open questions. Then STOP.

## STOP conditions

- The design seems to need syncing bookmarks between devices. That conflicts with the no-accounts rule, so report
  it rather than designing sync.
