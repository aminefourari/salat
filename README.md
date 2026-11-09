<img src="apps/web/assets/icon.svg" width="64" height="64" alt="">

# salat

Prayer times, adhan and Quran. Monorepo:

- `apps/web`: the PWA + Cloudflare Worker (`npm run dev`, `npm test`, `npm run deploy`)
- `apps/macos`: the native Mac app (menu bar adhan + Quran reader), see below

Created in [T3 Code](https://t3.codes).

## Mac app

Needs Xcode and XcodeGen (`brew install xcodegen`).

```sh
npm run mac:build              # → apps/macos/build/Salat.app
open apps/macos/build/Salat.app
npm run mac:test               # Swift tests, incl. parity with the web's prayer times
```

The app is unsigned (local only). If macOS refuses to open it, right-click → Open once.

## Data

City names come from [GeoNames](https://www.geonames.org) `cities5000` (CC BY 4.0), bundled into the Worker by `apps/web/scripts/cities.py`, so location lookups never leave our own Cloudflare account. The Mac app bundles the same list.

Quran text and recitations: [quran.com](https://quran.com). Adhan recordings and font: see `apps/macos/Salat/Resources/ATTRIBUTION.md`.
