<img src="apps/web/assets/icon.svg" width="64" height="64" alt="">

# Salat

Prayer times, adhan, Quran and adhkar. Free, no accounts, no tracking. Salat is and stays free.

- **Web app** (`apps/web`): an installable PWA on Cloudflare Workers.
  - Today's prayer times for your location, with push notifications at each prayer and 10 minutes before.
  - A Qibla compass.
  - A Quran reader with streamed recitation and read-along highlighting.
  - Hisn al-Muslim adhkar with audio.
- **Mac app** (`apps/macos`): a native menu-bar app.
  - Next prayer and countdown in the menu bar.
  - The full adhan at each prayer. Madinah (Sheikh Essam Bukhari) is the default; Makkah (Ali Ahmed Mulla, Fajr),
    Mishary Alafasy, Al-Aqsa and Abdul Basit download on first use, and you can add your own recording.
  - A Quran reader with eight reciters and read-along highlighting, available offline.
  - Hisn al-Muslim adhkar in Arabic, English and French, with audio.

Both apps compute the same prayer times to the minute. The website's method table is ported to Swift, and a shared
test fixture keeps the two in sync.

| Menu bar | Quran | Adhkar |
|---|---|---|
| <img src="docs/screenshots/mac-menu-dark.png" width="220" alt="Menu-bar panel, dark"> | <img src="docs/screenshots/mac-quran-dark.png" width="300" alt="Quran window, dark"> | <img src="docs/screenshots/mac-adhkar-dark.png" width="300" alt="Adhkar window, dark"> |
| <img src="docs/screenshots/mac-menu-light.png" width="220" alt="Menu-bar panel, light"> | <img src="docs/screenshots/mac-quran-light.png" width="300" alt="Quran window, light"> | <img src="docs/screenshots/mac-adhkar-light.png" width="300" alt="Adhkar window, light"> |

## Install the Mac app

1. Download `Salat-vX.Y.Z.zip` from [Releases](https://github.com/aminefourari/salat/releases).
2. Unzip it and move `Salat.app` to Applications.
3. Open it. The build is unsigned, so macOS blocks it the first time. Open **System Settings → Privacy & Security** and click **Open Anyway**, or run:

   ```sh
   xattr -dr com.apple.quarantine /Applications/Salat.app
   ```

It requires macOS 15 or later. Salat starts at login by default; you can change this in Settings → General.

## Development

```sh
npm install
npm run dev            # web app on :3000
npm test               # web tests (Vitest), incl. the web↔Mac parity fixture
npm run deploy         # build + wrangler deploy (Cloudflare Worker "salat")

brew install xcodegen  # once
npm run mac:test       # Swift tests
npm run mac:build      # → apps/macos/build/Salat.app
ditto apps/macos/build/Salat.app /Applications/Salat.app   # install locally (quit Salat first)
```

To refresh the screenshots, run `apps/macos/build/Salat.app/Contents/MacOS/Salat -snapshot DIR`. It renders the views
in dark and light, then quits.

## Releasing

CI (`.github/workflows/ci.yml`) runs the web and Swift tests on every push to `main` and on pull requests. To publish a
release, push a version tag:

```sh
git tag v1.0.0 && git push origin v1.0.0
```

`.github/workflows/release.yml` then runs the tests, builds `Salat.app` with that version, and publishes a GitHub
Release with `Salat-v1.0.0.zip`.

## Data and credits

- **City names:** [GeoNames](https://www.geonames.org) `cities5000` (CC BY 4.0). The Worker and the Mac app both
  bundle them, so location lookups never leave our own infrastructure.
- **Morocco:** the official timetable of the Ministry of Habous (`habous.gov.ma/data/horaires-YYYY-MM.js`), fetched
  and cached by the Worker for the nearest listed city within 25 km, else calculated (Fajr 19°, Isha 17°). Loader and
  city coordinates (`apps/web/src/server/habous-cities.json`, from GeoNames, CC BY 4.0) come from
  [fr255-watchface](https://github.com/iliassjabali/fr255-watchface).
- **Country borders:** [country-coder](https://github.com/rapideditor/country-coder).
- **Quran text and recitations:** [quran.com](https://quran.com). The Mac app downloads recitations for offline use;
  the website streams them.
- **Adhkar:** Hisn al-Muslim via [hisnmuslim.com](https://www.hisnmuslim.com) (Arabic, English, audio) and the AR-FR
  ["La Citadelle du Musulman"](https://github.com/Kiwifu/la-citadelle-du-musulman) (French, references). The book is
  distributed free and not for sale.
- **Adhan recordings and fonts** (Amiri, Amiri Quran, Reem Kufi, IBM Plex Sans Arabic): see
  `apps/macos/Salat/Resources/ATTRIBUTION.md`.

Created in [T3 Code](https://t3.codes).
