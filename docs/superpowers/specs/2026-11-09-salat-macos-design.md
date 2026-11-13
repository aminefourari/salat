# Salat for macOS — design

## Intent

A native Mac app that sits next to the existing Salat website. It does two jobs:

1. **Prayer times + adhan.** It lives in the menu bar, shows the next prayer with a countdown, and
   plays the adhan at each prayer time, the way dedicated prayer apps do. The website can only
   send a push notification; the Mac app actually calls the adhan.
2. **Quran.** A window to read the Arabic text, listen to a reciter, and read along while it
   plays, with the current ayah highlighted.

It is for the user's own Mac for now: built and run locally, unsigned, with no Apple Developer
certificate, notarization, or App Store.

## Goals

### Repo: monorepo (user decision)

- The repo becomes a monorepo. The website moves to `apps/web`, and the Mac app goes in `apps/macos`.
- The root `package.json` uses npm workspaces, so `npm run dev`, `npm test`, `npm run build`,
  `npm run deploy` and `npm run db:migrate` still work from the root (they forward to `apps/web`).
- Deploys run locally with `npm run deploy` (there's no CI in the repo). If Cloudflare's dashboard
  also builds from Git, its root directory has to be set to `apps/web` (the user checks this).
- Deploying the Worker must keep working unchanged: same Worker name `salat`, same D1 binding and
  migrations, same URL. Paths in `wrangler.jsonc`, `vite.config.ts`, `tsconfig.json`, the vitest
  config and `CLAUDE.md` are updated for the move.
- `CLAUDE.md` at the root describes both apps and their commands.

### Prayer times (same results as the website, user decision)

- Times are computed on the Mac with **`adhan-swift`** (the Swift sibling of the `adhan` JS
  library the website uses). The app does not call the website or the Worker.
- The per-country method table and the parameters of each method are ported from
  `src/lib/methods.ts` and `paramsFor` in `src/lib/prayer.ts` exactly. That includes the custom
  Aachen method (Fajr 18°, Isha 17°, Isha −3, safety margins Sunrise −7, Dhuhr +5, Asr +4,
  Maghrib +7), Morocco/Habous (19°/17°), UOIF (12°/12°), the `TwilightAngle` high-latitude rule,
  and the Hanafi/standard Asr setting.
- Morocco shows the same "calculated with the Habous method" note as the website. The website
  also calculates Morocco, so the two match.
- **Parity check (my call):** the method table now exists in TypeScript and in Swift. A shared
  fixture (expected times for a few cities and dates, generated from the web code, including
  Hagenow summer and winter and the Aachen 2026 timetable) is checked by both test suites. If
  someone changes one table and not the other, a test fails. Tolerance: same minute.
- Location comes from macOS Location Services (Core Location), and the app asks for permission
  on first launch. If location is denied, the user can type coordinates or pick a city in Settings (my call).
- **Country for the automatic method (my call):** it must match the website, which looks up the
  country offline from border data (`@rapideditor/country-coder`). The Mac app bundles that same
  border dataset (exported from `node_modules` by a script into a JSON resource) and does the same
  point-in-polygon lookup offline, falling back to MWL like the website. A parity test covers a few
  points, including near borders. Apple's `CLGeocoder` is used only for the city name shown in
  the UI, cached, and optional (no name offline is fine).
- Times are shown in the Mac's time zone.

### Menu bar

- A menu-bar item shows the next prayer and a countdown (for example "Asr · 1:12"); my call:
  an option shows only an icon.
- Clicking it opens a panel with today's five prayers plus sunrise, the next one highlighted,
  the city, and buttons for **Quran**, **Settings** and **Quit**.
- While an adhan is playing, the panel and the notification have a **Stop** button.

### Adhan and alerts

- At each prayer time (not sunrise) the app plays the selected adhan in full and shows a macOS
  notification. Each prayer can be set to adhan, notification only, or off (my call; this is how
  other adhan apps work).
- Fajr can use a different adhan voice from the other prayers (my call; common in adhan apps).
- The optional 10-minute reminder from the website is a silent notification.
- The adhan only plays while the app is running. Settings has an **Open at login** switch
  (`SMAppService`), on by default (my call).
- Timing must survive sleep and wake, time-zone changes and the date changing: after any of
  these, the app recomputes today's times and reschedules.
- **Sleep (my call):** the app does not wake the Mac (that needs admin rights). If the Mac wakes
  up within 5 minutes after a prayer time (the website's `MAX_LATE`), the adhan still plays. Later
  than that, it shows a "Asr started at 14:05" notification without sound.

### Quran

- **Text:** Arabic only (user decision), Uthmani script, with a proper Quran font. The text is
  bundled in the app (about 1–2 MB) so it works on first launch with no download (my call).
- **Navigation:** a sidebar with the 114 surahs (number, Arabic name, ayah count, and the
  transliterated name for the English and French UI). Selecting one shows its ayahs in a
  right-to-left reading view with ayah-number markers. The app reopens where you left off.
- **Reciters (user decision):** there is a list of reciters. Settings picks the default
  reciter. On any surah, the user can pick a different reciter for that listen without changing
  the default. My guess: that per-surah choice isn't remembered, and next time it goes back to
  the default.
- **Playback:** play/pause, next/previous ayah, play from any ayah, and playback continues while
  the window is closed. My call: macOS Now Playing / media keys work.
- **Read-along (user decision):** while playing, the current ayah is highlighted and scrolled
  into view. Clicking an ayah jumps playback to it.
- **Download and offline (user decision):** audio and timing come from **one** online service
  and are downloaded, then kept on disk so everything plays offline afterwards. Audio downloads
  per surah the first time you play it, or a whole reciter at once from Settings. Settings shows
  the disk space each reciter uses and lets you delete it. With no internet and a surah not yet
  downloaded, the app says so clearly; it never fails silently.
- **Service (my call):** quran.com's public API (`api.quran.com/api/v4`). It provides recitation
  audio per surah *and* per-ayah timestamps for read-along, which everyayah.com does not provide
  reliably. Checked on 2026-11-09: it works without credentials.
  `GET /resources/chapter_reciters` lists reciters, and `GET /chapter_recitations/{reciter}/{surah}?segments=true`
  returns one MP3 URL per surah plus per-ayah `timestamp_from`/`timestamp_to` in ms. The MP3s are
  served from `download.quranicaudio.com`, which is quran.com's audio host and counts as the same
  service. Only reciters that have timestamps are in the list.
- **Adhan voices (my call): bundled in the app**, 3–5 recordings with licenses that allow
  redistribution. Then the adhan works from the first launch with no download, and no second
  online service is needed.

### Settings (everything the website has, in a Mac layout, user decision)

A standard macOS Settings window with tabs:

- **General:** language (Arabic, English, French, as on the website; right-to-left layout in
  Arabic; defaults to the Mac's language), Open at login, menu-bar display.
- **Prayer times:** location (automatic, or manual), calculation method (automatic by country,
  showing which, or chosen by hand from the same list as the website), Asr (standard/Hanafi).
- **Adhan & alerts:** adhan voice (and Fajr voice), per-prayer mode, the 10-minute reminder, a
  "play a test" button.
- **Quran:** default reciter, downloads per reciter with sizes and delete.
- **Qibla:** a Mac has no compass, so this shows the bearing ("118° from north"), the 8-point
  direction and the distance to Makkah, as the website does on desktop.

The web app's i18n strings are reused as the source for the Mac translations (copied into a
Swift strings catalog); they don't need to be shared at build time.

### Build

- SwiftUI app, **macOS 15+**, Swift 6. The Xcode project is generated with **XcodeGen** from
  `apps/macos/project.yml` (installed on the dev machine), so no `.xcodeproj` is committed.
- Dependencies through Swift Package Manager: `adhan-swift`. Nothing else unless it saves real
  work.
- Signing: "Sign to Run Locally" / ad-hoc only. Entitlements: location, network client, and the
  app sandbox if it works with the above (builder's call).
- A short script or npm script builds the `.app` (for example `npm run mac:build`) and the
  README says how to open it the first time (right-click → Open, because it's unsigned).
- Tests: Swift unit tests for the prayer parity fixture, next-prayer/scheduling logic, and the
  read-along "which ayah is playing at time t" lookup.

## Non-goals

- No iPhone/iPad app, no App Store, no signing or notarization (for now).
- No translations or tafsir of the Quran; Arabic text only. (Tafsir: superseded, shipped later, see CLAUDE.md)
- No accounts, sync, or connection to the website's push notifications or D1.
- No official Habous timetable download (the website doesn't have it either). (superseded: shipped later, see CLAUDE.md)
- No search, bookmarks or memorization tools in the Quran (not requested; can come later).

## Anti-goals (a failure even if it "works")

- The Mac app and the website show different prayer times for the same place and settings.
- A prayer passes without the adhan because the app missed a wake, a time-zone change or a new
  day.
- The read-along highlight drifts away from the recitation.
- Anything needs the internet after a reciter is downloaded (adhans are bundled).
- Moving the web app breaks `npm run deploy`, the Worker URL, or the D1 data.
- Analytics, tracking, or calls to services other than quran.com (API plus its audio host) and Apple's
  own location and geocoding services.

## Left to the builder

- The visual design of the menu-bar panel and the Quran window (native macOS look, matching the
  website's identity where it's easy: icon, accent colour).
- The exact list of reciters and adhan voices (about 5–8 reciters and 3–5 adhans, the
  well-known ones with timing data), and the Quran font (one with a license that allows
  bundling).
- The source and format of the bundled Quran text (for example Tanzil Uthmani or the quran.com
  API dumped at build time).
- How the app is split into Swift files and modules.
