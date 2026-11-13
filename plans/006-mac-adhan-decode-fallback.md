# Plan 006: An adhan that can't be decoded falls back to the bundled adhan (never a beep), and broken downloads are discarded

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat e53b9a6..HEAD -- apps/macos/Salat/Services/AdhanStore.swift apps/macos/Salat/Services/AdhanPlayer.swift apps/macos/SalatTests/AdhanStoreTests.swift apps/macos/Salat/UI/SettingsView.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `e53b9a6`, 2026-11-13

## Why this matters

The Mac menu-bar app plays an adhan at each prayer, and its code promises "never silence". Today the bundled fallback
(`hassan2`) is only used when the chosen file is **missing**. If the file exists but can't be decoded, the app plays a
system beep at prayer time. That happens with a downloaded `.mp3` that is really an HTML error page (downloads only
check the HTTP status), or with a custom import in a format AVFoundation can't play. A broken download is also never
fetched again, because `download()` skips any id that already has a local file. After this plan, playback tries the
chosen file, then the bundled one. A broken *downloaded* file is deleted so it's fetched again. A custom file that
can't be decoded is refused at import time.

## Current state

- `apps/macos/Salat/Services/AdhanPlayer.swift:11-21` (`@MainActor` class, **not** compiled into the test target):
  ```swift
  func play(_ id: String) {
      stop()
      // Not downloaded yet (or a deleted custom file): fall back to a bundled adhan, never silence.
      if AdhanStore.shared.local(id) == nil, let v = AdhanVoice.find(id) { Task.detached { try? await AdhanStore.shared.download(v) } }
      guard let url = AdhanStore.shared.local(id) ?? AdhanStore.shared.local("hassan2"),
            let p = try? AVAudioPlayer(contentsOf: url) else { NSSound.beep(); return }
      p.delegate = self
      player = p
      isPlaying = p.play()
      onPlay?()
  }
  ```
- `apps/macos/Salat/Services/AdhanStore.swift` (`final class AdhanStore: Sendable`, **is** compiled into the test target
  via `apps/macos/project.yml`):
  ```swift
  func local(_ id: String) -> URL? {
      if let b = Bundle(for: AdhanStore.self).url(forResource: id, withExtension: "m4a") { return b }
      return files().first { $0.deletingPathExtension().lastPathComponent == id }
  }

  func download(_ v: AdhanVoice) async throws {
      guard local(v.id) == nil, let url = v.remote else { return }
      ...
  }

  /// Copies a user's audio file in; returns its id. The display name is kept in the file name.
  func importFile(_ src: URL) throws -> String {
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
      let name = src.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "~", with: "-")
      let id = "custom-\(UUID().uuidString.prefix(8))~\(name)"
      try FileManager.default.copyItem(at: src, to: root.appendingPathComponent(id).appendingPathExtension(src.pathExtension.lowercased()))
      return id
  }
  ```
  Bundled voices are `.m4a` resources inside the app bundle. Downloaded voices are `{root}/{id}.mp3`. Custom ones are
  `{root}/custom-XXXXXXXX~Name.ext`.
- `apps/macos/Salat/UI/SettingsView.swift`, `addOwn()`, calls `AdhanStore.shared.importFile(url)` inside
  `do { … } catch { failed = error.localizedDescription }`. A thrown error is already shown to the user.
- Tests: `apps/macos/SalatTests/AdhanStoreTests.swift`. `setUp` makes a temp `root`, and `AdhanStore(root: root)` is
  used directly. The existing `testImportAndDeleteCustom` writes `Data("audio".utf8)` as "My Adhan.mp3" and expects the
  import to **succeed**. That test must change, because undecodable audio is now refused. In the test target,
  `Bundle(for: AdhanStore.self)` is the test bundle, which contains `hassan2.m4a` (see `project.yml`), so
  `local("hassan2")` resolves in tests.
- Swift 6 strict concurrency is on. `AdhanStore` is `Sendable` with only `let` properties; keep it that way.

## Commands you will need

| Purpose | Command (repo root) | Expected |
|---------|---------------------|----------|
| Swift tests | `npm run mac:test` | last line `** TEST SUCCEEDED **` (58 tests today, 1 skipped) |
| Build app | `npm run mac:build` | `→ …/apps/macos/build/Salat.app` |
| Test log on failure | `tail -100 apps/macos/build/test.log` | — |

The tests need Xcode and `xcodegen` (`brew install xcodegen`). If `npm run mac:test` can't run in your environment,
STOP and report. Don't skip verification.

## Scope

**In scope**: `Services/AdhanStore.swift`, `Services/AdhanPlayer.swift`, `SalatTests/AdhanStoreTests.swift`.

**Out of scope**:
- `Quran/Recitations.swift` `downloadAtomically`, which is shared with Quran audio.
- `SettingsView.swift`. It already surfaces import errors.
- `project.yml`. `AdhanStore.swift` is already in the test target.

## Git workflow

- Branch: `fix/mac-adhan-fallback`. Commit: `fix(macos): fall back to the bundled adhan when a file won't decode`.
- No `Co-Authored-By` / "Generated with" trailers. Don't push or open a PR unless instructed.

## Steps

### Step 1: Add `playable(_:)` to `AdhanStore`

```swift
import AVFoundation   // add at the top, next to `import Foundation`

/// Errors the store reports to the UI.
enum AdhanStoreError: LocalizedError {
    case unplayable
    var errorDescription: String? { "This audio file can't be played." }
}

extension AdhanStore {
    /// A file for `id` that really decodes, else the bundled Hassan II adhan. A downloaded file that doesn't decode
    /// (e.g. an HTML error page saved as .mp3) is deleted so the next play downloads it again.
    func playable(_ id: String) -> URL? {
        if let url = local(id) {
            if (try? AVAudioPlayer(contentsOf: url)) != nil { return url }
            if url.path.hasPrefix(root.path), !id.hasPrefix("custom-") { try? FileManager.default.removeItem(at: url) }
        }
        return local("hassan2")
    }
}
```

The `hasPrefix(root.path)` guard means bundled resources are never deleted. Custom files are kept: the user chose
them, and the settings UI lists them so they can be deleted from there.

### Step 2: Refuse undecodable custom imports

In `importFile`, after `copyItem`, check the copy decodes. If it doesn't, delete it and throw:

```swift
let dest = root.appendingPathComponent(id).appendingPathExtension(src.pathExtension.lowercased())
try FileManager.default.copyItem(at: src, to: dest)
guard (try? AVAudioPlayer(contentsOf: dest)) != nil else { try? FileManager.default.removeItem(at: dest); throw AdhanStoreError.unplayable }
return id
```

### Step 3: Use it in `AdhanPlayer.play`

Replace the `guard let url = …` with:

```swift
guard let url = AdhanStore.shared.playable(id), let p = try? AVAudioPlayer(contentsOf: url) else { NSSound.beep(); return }
```

The beep stays only as a last resort, for when even the bundled file fails. Keep the download kick-off line above it.
`playable` has just deleted a broken download, so that line should run **after** the `playable` call. Reorder so the
download check (`if AdhanStore.shared.local(id) == nil, let v = …`) comes after `let url` is resolved. Only the order of
these two statements changes.

**Verify**: `npm run mac:build` → ends with `→ …/Salat.app` and no `error:` lines.

### Step 4: Tests

In `AdhanStoreTests.swift`:

1. Change `testImportAndDeleteCustom` so the source is a real audio file: copy the test bundle's `hassan2.m4a` to
   `FileManager.default.temporaryDirectory.appendingPathComponent("My Adhan.m4a")`. Keep its assertions, but expect
   `customName(id) == "My Adhan"`.
2. Add:
   ```swift
   func testImportRefusesUndecodableAudio() throws {
       let s = AdhanStore(root: root)
       let src = FileManager.default.temporaryDirectory.appendingPathComponent("Broken.mp3")
       try Data("<html>not audio</html>".utf8).write(to: src)
       XCTAssertThrowsError(try s.importFile(src))
       XCTAssertTrue(s.customIds().isEmpty)
   }

   func testBrokenDownloadFallsBackAndIsDeleted() throws {
       let s = AdhanStore(root: root)
       try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
       let broken = root.appendingPathComponent("madinah.mp3")
       try Data("<html>error</html>".utf8).write(to: broken)
       XCTAssertEqual(s.playable("madinah"), s.local("hassan2"))
       XCTAssertFalse(FileManager.default.fileExists(atPath: broken.path))
   }

   func testBundledPlays() {
       XCTAssertEqual(AdhanStore(root: root).playable("hassan2"), AdhanStore(root: root).local("hassan2"))
   }
   ```

**Verify**: `npm run mac:test` → `** TEST SUCCEEDED **`, with 3 more tests than before (61 executed, 1 skipped).

## Test plan

The Step 4 tests cover: undecodable custom import refused and not listed; broken download → falls back to `hassan2`
and the file is deleted; bundled file returned as-is; the existing import/delete flow with real audio.

## Done criteria

- [ ] `npm run mac:test` prints `** TEST SUCCEEDED **`
- [ ] `npm run mac:build` succeeds
- [ ] `grep -n "playable" apps/macos/Salat/Services/AdhanPlayer.swift` shows the new call
- [ ] Only the three in-scope files are modified
- [ ] `plans/README.md` status row updated

## STOP conditions

- `AVAudioPlayer(contentsOf:)` **succeeds** on the HTML bytes in the test, which would make the decode check
  meaningless. Report it; a different check (e.g. `AVAudioFile(forReading:)`) may be needed.
- Swift 6 concurrency errors appear about `AVAudioPlayer` in a `Sendable` class. Report the exact error rather than
  adding `@unchecked` or `nonisolated(unsafe)`.
- `npm run mac:test` can't run (no Xcode/xcodegen).

## Maintenance notes

- If more bundled voices are added, they need no change: `playable` only deletes files under `root`.
- Per CLAUDE.md, UI changes on the Mac need a snapshot check. This plan changes no UI, so none is required.
