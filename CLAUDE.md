# Salat

Prayer-times monorepo (npm workspaces):

- `apps/web`: PWA (TanStack Start + React), deployed as one Cloudflare Worker (`salat`).
- `apps/macos`: native SwiftUI menu-bar app (adhan + Quran), local/unsigned.

Specs: `docs/superpowers/specs/` (PWA: `2026-11-08-salat-pwa-design.md`, Mac: `2026-11-09-salat-macos-design.md`). Plans: `docs/superpowers/plans/`.

## Commands (from repo root)

- `npm run dev`: web dev on :3000 (Vite + workerd via `@cloudflare/vite-plugin`)
- `npm test`: Vitest (`apps/web/test`), incl. the shared parity fixture check
- `npm run build` / `npm run deploy`: build, then `wrangler deploy` (runs in `apps/web`)
- `npm run db:migrate`: apply `apps/web/migrations/` to remote D1 `salat`
- `cd apps/web && npx wrangler secret put VAPID_PRIVATE_KEY`: push signing key (never commit it)
- `npm run mac:build` / `npm run mac:test`: XcodeGen + xcodebuild → `apps/macos/build/Salat.app` / Swift tests
- `TEST_RUNNER_SALAT_LIVE=1 npm run mac:test`: also runs the live quran.com download test
- `apps/macos/scripts/fetch-assets.sh`: regenerate bundled Quran text, font, adhans (outputs are committed)

## Structure

- `apps/web/src/lib/`: isomorphic, pure code shared by browser and Worker (prayer math, methods, schedule, i18n)
- `apps/web/src/server/`: Worker-only code (push sending, cron, Habous)
- `apps/web/src/server.ts`: Worker entry (`fetch` from TanStack Start + `scheduled` cron)
- `apps/web/src/routes/`: file-based routes; `src/routes/api/*` are server routes
- `apps/web/public/`: manifest, service worker `sw.js`, icons
- `apps/web/test/`: Vitest tests; `fixtures/aachen-2026.json` is the Islamic Center Aachen 2026 timetable
- `fixtures/parity.json`: prayer/country cases generated from the web code, checked by both apps
- `apps/macos/Salat/Core`: Swift ports of methods/prayer math, scheduler, strings, settings
- `apps/macos/Salat/{Services,Quran,UI}`: location, adhan alerts, Quran reader/player, SwiftUI views
- `apps/macos/project.yml`: XcodeGen spec (no `.xcodeproj` committed). The test target compiles the pure sources directly (no app host); add new pure files there too.
- `apps/macos/Salat/Resources/ATTRIBUTION.md`: licenses of the bundled Quran text, font, adhans, borders, cities

## Conventions

- Prayer times are always computed through `computeDay` in `apps/web/src/lib/prayer.ts` (web) and its Swift port `computeDay` in `apps/macos/Salat/Core/PrayerCalc.swift`. They must agree to the minute.
- Parity rule: changing `methods.ts`/`paramsFor` → port it to `Core/Methods.swift`, then `UPDATE_MAC_DATA=1 npm test` (regenerates `fixtures/parity.json` and the Mac's borders/cities resources) and `npm run mac:test`.
- Per-country method config is data in `methods.ts` / `Methods.swift`; adding a country is one entry in each.
- Times are formatted in the device's/subscription's IANA time zone, never UTC.
- No accounts, analytics, or third-party client calls. Exception: the Mac app downloads recitations from quran.com (`api.quran.com`, `download.quranicaudio.com`) and caches them offline.
