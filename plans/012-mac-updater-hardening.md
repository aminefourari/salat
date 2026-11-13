# Plan 012: The Mac updater downloads off the main thread, installs once, cleans up, and can never leave the app missing

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat e53b9a6..HEAD -- apps/macos/Salat/Services/Updater.swift apps/macos/Salat/Core/Updates.swift apps/macos/SalatTests/UpdatesTests.swift`
> Plan 007 changes `Updater.swift`'s timer lines on purpose; that's expected. Any other change → compare with the
> excerpts, and STOP on a mismatch.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED (it's the code that replaces the installed app; a bug can brick installs, so verify the script with real files)
- **Depends on**: none (plan 007 touches the same file's timer only; either order works)
- **Category**: bug / perf
- **Planned at**: commit `e53b9a6`, 2026-11-13

## Why this matters

The Mac app updates itself. It downloads `Salat-vX.Y.Z.zip` through the Worker, checks the SHA-256, unzips, runs
`codesign --verify`, checks the bundle id and version, and then a detached `sh` script swaps the bundles after the app
quits. Four weaknesses:

1. **UI freezes.** The download iterates `URLSession.AsyncBytes` **byte by byte** on the main actor (about 11M
   iterations for an 11 MB zip), holding the whole zip in memory. `ditto` and `codesign` run with a synchronous
   `waitUntilExit()` on the main thread.
2. **Double install.** `install()` checks `.available` but only changes state inside the spawned `Task`, so two quick
   clicks start two installs and two swap scripts.
3. **Temp leak.** On any failure (checksum, codesign, wrong app), the `salat-update-<UUID>` directory with the zip and
   the unpacked app stays in `$TMPDIR`.
4. **Unsafe swap.** If moving the new app into place fails partway (e.g. a cross-volume copy onto an external disk,
   disk full), the restore `mv` runs while a partial `Salat.app` already exists. That moves the old app *inside* it.
   If the first `mv` fails, the script exits without relaunching, so the user is left with no running app and no adhans.

## Current state

- `apps/macos/Salat/Services/Updater.swift` (`@MainActor @Observable final class Updater`, **not** in the test target):
  ```swift
  func install() {
      guard case .available(let info) = state else { return }
      Task { await install(info) }
  }

  private func install(_ info: UpdateInfo) async {
      state = .downloading(info, 0)
      do {
          let app = Bundle.main.bundleURL
          guard FileManager.default.isWritableFile(atPath: app.deletingLastPathComponent().path) else { throw UpdateError.notWritable }
          let work = FileManager.default.temporaryDirectory.appendingPathComponent("salat-update-\(UUID().uuidString)")
          try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
          let zip = try await download(info, to: work.appendingPathComponent("Salat.zip"))
          // Integrity: the digest GitHub computed for the release asset.
          let digest = SHA256.hash(data: try Data(contentsOf: zip, options: .mappedIfSafe)).map { String(format: "%02x", $0) }.joined()
          guard digest == info.sha256.lowercased() else { throw UpdateError.checksum }
          state = .installing
          try run("/usr/bin/ditto", ["-x", "-k", zip.path, work.path])
          let new = work.appendingPathComponent("Salat.app")
          try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", new.path])
          let plist = Bundle(url: new)?.infoDictionary
          guard plist?["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
                plist?["CFBundleShortVersionString"] as? String == info.version else { throw UpdateError.wrongApp }
          try swapAndRelaunch(old: app, new: new, work: work)
          NSApp.terminate(nil)
      } catch {
          state = .failed(...)
      }
  }

  private func download(_ info: UpdateInfo, to dest: URL) async throws -> URL {
      let (bytes, res) = try await URLSession.shared.bytes(from: info.downloadURL)
      guard (res as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.server }
      let total = max(Int(res.expectedContentLength), info.size, 1)
      var data = Data(); data.reserveCapacity(total)
      var buf = [UInt8](); buf.reserveCapacity(1 << 16)
      for try await b in bytes { buf.append(b); if buf.count == 1 << 16 { … state = .downloading(info, …) } }
      data.append(contentsOf: buf)
      try data.write(to: dest)
      return dest
  }

  private func swapAndRelaunch(old: URL, new: URL, work: URL) throws {
      let script = """
      while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
      mv "$2" "$4/old.app" || exit 1
      if mv "$3" "$2"; then rm -rf "$4"; else mv "$4/old.app" "$2"; fi
      xattr -dr com.apple.quarantine "$2" 2>/dev/null
      open "$2"
      """
      let p = Process()
      p.executableURL = URL(fileURLWithPath: "/bin/sh")
      p.arguments = ["-c", script, "salat-update", String(ProcessInfo.processInfo.processIdentifier), old.path, new.path, work.path]
      try p.run()
  }

  private func run(_ tool: String, _ args: [String]) throws {
      let p = Process(); p.executableURL = URL(fileURLWithPath: tool); p.arguments = args
      try p.run(); p.waitUntilExit()
      guard p.terminationStatus == 0 else { throw UpdateError.wrongApp }
  }
  ```
- An existing helper to reuse is in `apps/macos/Salat/Quran/Recitations.swift`, extension on `URLSession`:
  ```swift
  /// Downloads `url` and moves it into `dest` in one step, so a half file never sits at `dest`.
  func downloadAtomically(_ url: URL, to dest: URL, progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws
  ```
  It checks the HTTP status via `RecitationStore.check(resp)` and reports progress (0…1) through a delegate.
- `apps/macos/Salat/Core/Updates.swift` holds pure update code (`updateEndpoint`, `UpdateInfo`, `isNewer`) and **is**
  in the test target. Its tests are `apps/macos/SalatTests/UpdatesTests.swift`.
- The script passes paths as positional arguments (`$1`…`$4`) to a constant script. That's injection-safe. Keep it.
- Swift 6 strict concurrency is on. `Updater` is `@MainActor`.

## Commands you will need

| Purpose | Command (repo root) | Expected |
|---------|---------------------|----------|
| Swift tests | `npm run mac:test` | `** TEST SUCCEEDED **` |
| Build | `npm run mac:build` | ends with `→ …/apps/macos/build/Salat.app` |

## Scope

**In scope**: `Salat/Services/Updater.swift`, `Salat/Core/Updates.swift`, `SalatTests/UpdatesTests.swift`.

**Out of scope**:
- Signing/authenticity (plan 016).
- The Worker's `/api/update`.
- `Recitations.swift` (use `downloadAtomically` as-is).
- The UI in `SettingsView.swift`.

## Git workflow

- Branch: `fix/mac-updater`. Commit: `fix(macos): updater downloads off the main thread, installs once, swaps safely`.
- No `Co-Authored-By` / "Generated with" trailers. Don't push or open a PR unless instructed.

## Steps

### Step 1: Move the swap script into `Core/Updates.swift` and make it safe

Add to `Updates.swift`:

```swift
/// Run by a detached `sh -c` after the app quits: $1 pid to wait for, $2 installed app, $3 new app, $4 work dir,
/// $5 command that opens an app (`open`; tests pass `true`). Never leaves $2 missing: on any failure the old app is put
/// back (a partial copy is removed first), and whatever is at $2 is reopened.
let updateSwapScript = """
while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
if ! mv "$2" "$4/old.app"; then "$5" "$2"; exit 1; fi
if mv "$3" "$2"; then
  rm -rf "$4"
else
  rm -rf "$2"
  mv "$4/old.app" "$2"
fi
xattr -dr com.apple.quarantine "$2" 2>/dev/null
"$5" "$2"
"""
```

In `Updater.swift`'s `swapAndRelaunch`, use `updateSwapScript` and append `"/usr/bin/open"` as the 5th argument.

### Step 2: Test the script with real directories

In `UpdatesTests.swift` add a helper that runs the script synchronously, with `$1` = the pid of an already-finished
process. `kill -0` then fails at once.

```swift
private func runSwap(old: URL, new: URL, work: URL) throws {
    let done = Process(); done.executableURL = URL(fileURLWithPath: "/usr/bin/true"); try done.run(); done.waitUntilExit()
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/sh")
    p.arguments = ["-c", updateSwapScript, "test", String(done.processIdentifier), old.path, new.path, work.path, "/usr/bin/true"]
    try p.run(); p.waitUntilExit()
}

func testSwapReplacesTheApp() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let old = dir.appendingPathComponent("Salat.app"), work = dir.appendingPathComponent("work"), new = work.appendingPathComponent("Salat.app")
    try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: new, withIntermediateDirectories: true)
    try Data("old".utf8).write(to: old.appendingPathComponent("v")); try Data("new".utf8).write(to: new.appendingPathComponent("v"))
    try runSwap(old: old, new: new, work: work)
    XCTAssertEqual(try String(contentsOf: old.appendingPathComponent("v"), encoding: .utf8), "new")
    XCTAssertFalse(FileManager.default.fileExists(atPath: work.path))
    try? FileManager.default.removeItem(at: dir)
}

func testSwapRestoresTheOldAppWhenTheNewOneCannotMove() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let old = dir.appendingPathComponent("Salat.app"), work = dir.appendingPathComponent("work")
    try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    try Data("old".utf8).write(to: old.appendingPathComponent("v"))
    try runSwap(old: old, new: work.appendingPathComponent("missing.app"), work: work)
    XCTAssertEqual(try String(contentsOf: old.appendingPathComponent("v"), encoding: .utf8), "old")
    XCTAssertFalse(FileManager.default.fileExists(atPath: old.appendingPathComponent("old.app").path))
    try? FileManager.default.removeItem(at: dir)
}
```

**Verify**: `npm run mac:test` → `** TEST SUCCEEDED **` (2 more tests).

### Step 3: Single-flight `install()`

```swift
func install() {
    guard case .available(let info) = state else { return }
    state = .downloading(info, 0) // synchronously, so a second click finds no .available
    Task { await install(info) }
}
```

Remove the now-redundant `state = .downloading(info, 0)` at the top of `install(_:)`.

### Step 4: Download, hash and run tools off the main actor; always clean up

- Replace `download(_:to:)` with the shared helper:
  ```swift
  let zip = work.appendingPathComponent("Salat.zip")
  try await URLSession.shared.downloadAtomically(info.downloadURL, to: zip) { p in
      Task { @MainActor [weak self] in if case .downloading = self?.state { self?.state = .downloading(info, p) } }
  }
  ```
  Delete the old `download` function.
- Hash off the main actor:
  ```swift
  let digest = try await Task.detached { SHA256.hash(data: try Data(contentsOf: zip, options: .mappedIfSafe)).map { String(format: "%02x", $0) }.joined() }.value
  ```
- Make `run` async and run it off the main actor:
  ```swift
  private nonisolated func run(_ tool: String, _ args: [String]) async throws {
      try await Task.detached {
          let p = Process(); p.executableURL = URL(fileURLWithPath: tool); p.arguments = args
          try p.run(); p.waitUntilExit()
          guard p.terminationStatus == 0 else { throw UpdateError.wrongApp }
      }.value
  }
  ```
  Call it with `try await run(...)`.
- Clean up on failure. Right after `createDirectory(at: work…)`, add:
  ```swift
  var handedOff = false
  defer { if !handedOff { try? FileManager.default.removeItem(at: work) } }
  ```
  and set `handedOff = true` immediately after `try swapAndRelaunch(...)` succeeds. The script then owns `work`.

**Verify**: `npm run mac:build` → succeeds with no `error:` lines.
`grep -n "for try await b in bytes\|waitUntilExit" apps/macos/Salat/Services/Updater.swift` → only the
`waitUntilExit` inside `Task.detached` in `run`.

### Step 5: Full regression

**Verify**: `npm run mac:test` → `** TEST SUCCEEDED **`.

## Test plan

Two new script tests run real `mv`s on temp directories: the success path, and the failed move with the old app
restored and no nested `old.app`. The existing `testIsNewer` and `testDecodesWorkerResponse` still pass. The
async/main-actor changes are covered by the build: Swift 6 strict concurrency checks isolation.

A real end-to-end update can only be tested against a published release. Note in the PR: "verify on the next release:
install the previous version, run Settings → Updates".

## Done criteria

- [ ] `npm run mac:test` prints `** TEST SUCCEEDED **`, including the 2 new swap tests
- [ ] `npm run mac:build` succeeds
- [ ] Step 4 grep satisfied
- [ ] Only the three in-scope files are modified
- [ ] `plans/README.md` status row updated

## STOP conditions

- `downloadAtomically` isn't visible from `Updater.swift` (access level). Report it rather than copying it.
- Swift 6 isolation errors you can only silence with `@unchecked Sendable`, `nonisolated(unsafe)` or
  `MainActor.assumeIsolated` in a new place. Report the error text.
- A swap test fails. Don't weaken the assertion. The script is the safety net for every installed user.

## Maintenance notes

- The script must stay a constant string with arguments passed positionally. Never interpolate paths into it.
- `RecitationStore.check` decides which HTTP statuses are failures for the download. If the update endpoint ever
  starts answering 3xx without following, revisit it.
- `isWritableFile` on `/Applications` fails for standard (non-admin) users. That case is unchanged, and they get the
  "not writable" message.
