# Salat macOS Adhkar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Hisn al-Muslim adhkar library (bundled text, on-demand cached audio) to the Mac app, then install the app in /Applications.

**Architecture:** A build-time Python script merges hisnmuslim.com (Arabic, English, repeat, audio URL) with the AR-FR "Citadelle du Musulman" markdown (French, reference) by normalised Arabic similarity and writes `Resources/adhkar.json` plus a report. Swift loads it (`AdhkarText`), plays per-dhikr audio cached under Application Support (`AdhkarAudioStore`, sharing the in-flight download dedupe with `RecitationStore`), and shows an `Adhkar` window.

**Tech Stack:** Python 3 (stdlib only: `difflib`, `unicodedata`, `json`, `urllib`), Swift 6/SwiftUI, AVFoundation, XCTest.

**Spec:** `docs/superpowers/specs/2026-11-09-salat-macos-adhkar-design.md` (extends `2026-11-09-salat-macos-design.md`)

## Global Constraints

- Project stays free; credit both sources in `ATTRIBUTION.md` with the "free, not for sale" note.
- Network at runtime: only `api.quran.com`, `download.quranicaudio.com`, and `https://www.hisnmuslim.com/audio/…` (adhkar audio). The build never touches the network.
- Arabic shown = hisnmuslim Arabic, unchanged. "×N" only when `repeat > 1` and the Arabic has no inline count note.
- Translation: English (hisnmuslim) in `en`, French (Citadelle) in `fr`, none in `ar`. Reference shown in all languages when matched.
- When a pairing is uncertain, show no French and no reference.
- Morning & evening stay one chapter. Chapter order = hisnmuslim chapter ID order.
- No counter, favourites, transliteration, notifications.

## Review Focus

1. **Wrong pairing** (a French text or reference under a different dhikr): spot checks of known pairs, plus a guard that matches below the threshold get no French. Pinned by `AdhkarDataTests.testSpotChecks` and `testNoLowConfidenceFrench` (Task 1/2).
2. **Count badge contradicting the text** (ID 83 is REPEAT 1 but the text says seven times): pinned by `AdhkarDataTests.testBadgeHiddenWhenTextHasCount` (Task 2).
3. **Offline play of an undownloaded dhikr**: a clear message, text still readable, no half file counted. Pinned by `AdhkarAudioStoreTests.testPartialNotCached` (Task 2).
4. **Two audio sources at once** (dhikr + Quran + adhan): each start stops the others. This is wiring in `App.swift` (Task 3); checked manually.
5. **App moved to /Applications while the login item points at the old build path**: re-register when the bundle path changed. Pinned by the `loginItemNeedsRefresh` test (Task 3).

---

### Task 1: Merge script + bundled data

**Files:** Create `apps/macos/scripts/fetch-adhkar.py`, `apps/macos/Salat/Resources/adhkar.json`, `apps/macos/Salat/Resources/Amiri-Regular.ttf` (+ OFL); modify `scripts/fetch-assets.sh` (call fetch-adhkar, fetch Amiri) and `ATTRIBUTION.md`.

**Interfaces:**
- Produces `adhkar.json`: `[{"id":27,"ar":"أذكار الصباح والمساء","en":"Words of remembrance for morning and evening","fr":"…","items":[{"id":75,"ar":"…","en":"…","fr":"…"|null,"ref":"…"|null,"repeat":1,"count_in_text":true,"audio":"https://www.hisnmuslim.com/audio/ar/75.mp3"|null}]}]`, with chapters in ID order.
- The script runs as `python3 -I fetch-adhkar.py OUT.json` and prints a report: the number of matched, unmatched and low-confidence pairs, and the unmatched IDs.

- [ ] **Step 1:** Write the script.
  - **Fetch:** the ar and en index and every chapter. Strip control chars and the BOM before `json.loads`. Also fetch the French md from `https://raw.githubusercontent.com/Kiwifu/la-citadelle-du-musulman/main/La_Citadelle_du_Musulman_AR-FR.md`.
  - **Parse the md:** `## N. Title` chapters. Each `**k.**` entry has its Arabic in the `> «…»` blockquote, the French as the first plain paragraph after the italic transliteration, and the ref from the `— *…*` line.
  - **Normalise the Arabic:** remove `ً-ٰٟۖ-ۭ`, tatweel and punctuation/brackets. Map `أإآٱ→ا`, `ى→ي`, `ة→ه`, `ؤ→و`, `ئ→ي`. Collapse spaces.
  - **Match** within the paired chapter (hisnmuslim chapter n ↔ French chapter n+1):
    - `score = SequenceMatcher(None, a, b).ratio()`
    - If one string is a prefix of, or contained in, the other with length ≥ 25 chars, the score is 0.95.
    - Take the best one-to-one match greedily by score. Accept if `≥ 0.6`; otherwise `fr`/`ref` are null.
  - `count_in_text`: does the Arabic match `مرة|مرات|مرّات|مائة|ثلاثاً|سبعاً|عشر`?
  - The chapter `fr` title comes from French chapter n+1.
  - Audio URLs are rewritten to `https://`.
- [ ] **Step 2: Run it.** Expected: 132 chapters, a report listing the matched and unmatched pairs, and no crash. Spot-check by reading:
  - ID 75 (Ayat al-Kursi) has French with "Allah" and the ref "Al-Bukhârî…".
  - The waking-up chapter (hisnmuslim ID 1) first dhikr has French "Louange à Allah qui nous a rendu la vie…".
- [ ] **Step 3:** Add Amiri Regular (`google/fonts ofl/amiri/Amiri-Regular.ttf` + OFL) to `fetch-assets.sh`, and add the credits for hisnmuslim.com and the Citadelle edition (Badr B., from the Midad app) to `ATTRIBUTION.md`. Commit `feat(macos): bundled adhkar data merged from hisnmuslim.com and the AR-FR Citadelle`.

### Task 2: Swift model, audio store, tests

**Files:** Create `Salat/Adhkar/Adhkar.swift`, `SalatTests/AdhkarTests.swift`; modify `Quran/Recitations.swift` (extract the shared dedupe), `project.yml` (test sources + `adhkar.json` resource).

**Interfaces:**
- `struct Dhikr: Codable, Identifiable { id: Int; ar: String; en: String?; fr: String?; ref: String?; repeat: Int; count_in_text: Bool; audio: URL? }` with:
  - `func translation(_ l: Lang) -> String?` (en → `en`, fr → `fr`, ar → nil)
  - `var badge: Int?` (`repeat > 1 && !count_in_text ? repeat : nil`)
- `struct AdhkarChapter: Codable, Identifiable { id: Int; ar: String; en: String; fr: String?; items: [Dhikr]; func title(_ l: Lang) -> String }`. The `fr` title falls back to `en`.
- `enum AdhkarText { static let chapters: [AdhkarChapter] }`, bundle-anchored like `QuranText`.
- `final class SharedDownloads: Sendable { func run(_ key: String, _ work: @escaping @Sendable () async throws -> Void) async throws }`: the in-flight dedupe and cancel logic moved out of `RecitationStore.download`, which now uses it.
- `final class AdhkarAudioStore: Sendable`:
  - `static let shared` (root `~/Library/Application Support/Salat/adhkar`)
  - `init(root:session:)`
  - `func local(_ d: Dhikr) -> URL?`: `{id}.mp3` exists
  - `func download(_ d: Dhikr) async throws`: a URLSession download to a temp file, then an atomic move
  - `func downloadAll(progress: @Sendable (Int, Int) -> Void) async throws`
  - `func size() -> Int64`, `func delete()`, `var total: Int` (adhkar with audio)

- [ ] **Step 1: Write the tests.**
  - `AdhkarDataTests.testLoads`: 132 chapters, and every item has non-empty `ar`.
  - `testSpotChecks`: dhikr 75 has an `fr` containing "Allah" and a non-nil `ref`. Chapter 1, item 1 `fr` hasPrefix "Louange à Allah qui nous a rendu la vie".
  - `testBadgeHiddenWhenTextHasCount`: dhikr 83's `badge` is nil. Some dhikr with `repeat` 33 or 100 and no inline note → badge == repeat (if none exists, assert there are no badges contradicting `count_in_text`).
  - `testTranslationByLang`: `translation(.ar) == nil`, `translation(.en) == en`.
  - `AdhkarAudioStoreTests.testPartialNotCached`: only a `.part` or tmp file → `local` nil.
  - `testDownloadAndDelete`: via `StubProtocol` (existing) → local non-nil, size > 0, delete → nil.
  - `testNoLowConfidenceFrench`: the share of dhikr with `fr` is ≥ 50% and ≤ 100%, and every chapter with ≥ 1 French item has an `fr` title.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement and refactor `RecitationStore` to `SharedDownloads`. **Step 4:** `npm run mac:test` → all pass (the old download tests still pass). **Step 5:** Commit `feat(macos): adhkar model and offline audio store`.

### Task 3: Adhkar window, player, settings, login-item path, install

**Files:** Create `UI/AdhkarView.swift`; modify `App.swift`, `UI/MenuView.swift`, `UI/SettingsView.swift`, `Core/L10n.swift`, `Core/Settings.swift` (`lastAdhkarChapter: Int`, `loginItemPath: String?`); tests in `SalatTests/AdhkarTests.swift`.

**Interfaces:**
- `@MainActor @Observable final class AdhkarPlayer`:
  - `playing: Int?` (dhikr id), `loading: Int?`, `message: (id: Int, text: String)?`
  - `func play(_ d: Dhikr) async`: downloads if needed. Offline → `needsInternet`. Then plays with `AVAudioPlayer` and calls `onPlay`.
  - `func stop()`, `var onPlay: (() -> Void)?`
- Wiring in `App`:
  - Adhan `onPlay` → `quran.pause(); adhkar.stop()`
  - `adhkar.onPlay` → `quran.pause()`
  - `QuranPlayer` gets `var onPlay` → `adhkar.stop()`, called in `resume()`.
- `func loginItemNeedsRefresh(registeredPath: String?, currentPath: String, enabled: Bool) -> Bool` in `Core/Settings.swift`: `enabled && registeredPath != currentPath`. On launch, if true, `unregister` + `register` and save the path. First-launch registration also saves the path.
- `AdhkarView`:
  - A `NavigationSplitView` sidebar of chapters, `.searchable` filtering on `title(lang)` + `ar`.
  - The detail view is a `ScrollView` of cards. Each card has the Arabic (Amiri 24, RTL, selectable), the badge "×N" when `badge`, the translation (UI language), the ref (caption, secondary), and a play/stop button when `audio != nil` (a spinner while loading, the message inline).
  - The window remembers `lastAdhkarChapter`.
- Menu: an "Adhkar" button next to "Quran" (`openWindow(id: "adhkar")`).
- Settings → Quran tab gets an "Adhkar audio" section: count downloaded/total, size, Download all (progress and cancel), Delete.
- L10n keys (en/fr/ar): `adhkar`, `adhkarAudio`, `searchCategory`.

- [ ] **Step 1:** Write the test `testLoginItemNeedsRefresh`: (`"/a"`, `"/b"`, true) → true; (`"/a"`, `"/a"`, true) → false; (nil, `"/b"`, false) → false. Run → FAIL.
- [ ] **Step 2:** Implement everything above. `npm run mac:test` → PASS. `npm run mac:build` → BUILD SUCCEEDED.
- [ ] **Step 3: Install.** Quit any running Salat. `ditto apps/macos/build/Salat.app /Applications/Salat.app`, then `open /Applications/Salat.app`, and check the process path is `/Applications/Salat.app`.
- [ ] **Step 4:** Update `CLAUDE.md` and `README.md` (adhkar, `fetch-adhkar.py`, install line). Commit `feat(macos): adhkar window with audio; install to /Applications`.
