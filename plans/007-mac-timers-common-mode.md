# Plan 007: The Mac alert clock keeps ticking while a menu or modal panel is open

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat e53b9a6..HEAD -- apps/macos/Salat/Services/AlertEngine.swift apps/macos/Salat/Services/Updater.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `e53b9a6`, 2026-11-13

## Why this matters

The Mac app fires every adhan from a once-a-second `Timer` in `AlertEngine`. `Timer.scheduledTimer` only runs in the
run loop's `.default` mode. While AppKit tracks a menu, or runs a modal panel (the settings' "add your own adhan"
`NSOpenPanel.runModal()`), the run loop is in another mode and the timer doesn't fire. If a prayer time passes during
that, and more than 5 minutes go by before it closes, the app shows a "started at" notification **without the adhan**.
Adding the timer to `.common` modes fixes it. That's a one-line change per timer.

## Current state

- `apps/macos/Salat/Services/AlertEngine.swift:59-60` in `init`:
  ```swift
  timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
  timer?.tolerance = 0.2
  ```
- `apps/macos/Salat/Services/Updater.swift:29-31` in `init` (the daily update check; same issue, minor):
  ```swift
  timer = Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.autoCheck() }
  }
  ```
- `MainActor.assumeIsolated` is safe here because timers on `RunLoop.main` fire on the main thread in every mode.
- Neither file is in the test target (`apps/macos/project.yml`, target `SalatTests`), so this is verified by building
  and by a code check, not a unit test.

## Commands you will need

| Purpose | Command (repo root) | Expected |
|---------|---------------------|----------|
| Build | `npm run mac:build` | ends with `→ …/apps/macos/build/Salat.app` |
| Swift tests | `npm run mac:test` | `** TEST SUCCEEDED **` |

## Scope

**In scope**: `apps/macos/Salat/Services/AlertEngine.swift`, `apps/macos/Salat/Services/Updater.swift` (only the timer
creation lines).

**Out of scope**: replacing `runModal()` with a sheet in `SettingsView.swift`, and any other change to `tick()`.

## Git workflow

- Branch: `fix/mac-timer-modes`. Commit: `fix(macos): keep the alert clock ticking during menus and modal panels`.
- No `Co-Authored-By` / "Generated with" trailers. Don't push or open a PR unless instructed.

## Steps

### Step 1: AlertEngine

Replace the two lines with:

```swift
// .common: also fire while a menu is tracking or a modal panel runs (else a prayer can pass without its adhan).
let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
t.tolerance = 0.2
RunLoop.main.add(t, forMode: .common)
timer = t
```

### Step 2: Updater

Same pattern for the 24-hour timer: create it with `Timer(timeInterval: 24 * 3600, repeats: true) { … }` and add it with
`RunLoop.main.add(t, forMode: .common)`.

**Verify**: `npm run mac:build` → succeeds, with no `error:` lines.
`grep -n "scheduledTimer" apps/macos/Salat/Services/AlertEngine.swift apps/macos/Salat/Services/Updater.swift` →
no matches. `grep -c "forMode: .common" apps/macos/Salat/Services/AlertEngine.swift apps/macos/Salat/Services/Updater.swift` → 1 each.

### Step 3: Regression run

**Verify**: `npm run mac:test` → `** TEST SUCCEEDED **`.

### Step 4 (manual, optional): smoke test

Run `apps/macos/build/Salat.app/Contents/MacOS/Salat`, open the menu and leave it open across a minute boundary. The
menu's countdown should keep updating. If you can't run GUI apps, say so in the report.

## Test plan

There's no unit test: the timer is in AppKit glue outside the test target. The grep checks plus the build are the gate.

## Done criteria

- [ ] `npm run mac:build` succeeds; `npm run mac:test` prints `** TEST SUCCEEDED **`
- [ ] The Step 2 greps give the expected counts
- [ ] Only the two in-scope files are modified
- [ ] `plans/README.md` status row updated

## STOP conditions

- Swift 6 reports a Sendable/isolation error for the closure passed to `Timer(timeInterval:repeats:block:)`. Report it
  verbatim; don't add `@unchecked Sendable` or `nonisolated(unsafe)`.

## Maintenance notes

- Any new `Timer` that drives user-visible alerts should use `.common` mode too.
