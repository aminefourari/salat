# Salat

Prayer-times PWA (TanStack Start + React) deployed as one Cloudflare Worker (`salat`).
Spec: `docs/superpowers/specs/2026-11-08-salat-pwa-design.md`. Plan: `docs/superpowers/plans/2026-11-08-salat-pwa.md`.

## Commands

- `npm run dev`: local dev on :3000 (Vite + workerd via `@cloudflare/vite-plugin`)
- `npm test`: Vitest (pure logic in `src/lib`, cron in `src/server`)
- `npm run build` / `npm run deploy`: build, then `wrangler deploy`
- `npm run db:migrate`: apply `migrations/` to remote D1 `salat`
- `npx wrangler secret put VAPID_PRIVATE_KEY`: push signing key (never commit it)

## Structure

- `src/lib/`: isomorphic, pure code shared by browser and Worker (prayer math, methods, schedule, i18n)
- `src/server/`: Worker-only code (push sending, cron, Habous)
- `src/server.ts`: Worker entry (`fetch` from TanStack Start + `scheduled` cron)
- `src/routes/`: file-based routes; `src/routes/api/*` are server routes
- `public/`: manifest, service worker `sw.js`, icons
- `test/`: Vitest tests; `test/fixtures/aachen-2026.json` is the Islamic Center Aachen 2026 timetable

## Conventions

- Prayer times are always computed through `computeDay` in `src/lib/prayer.ts`, the same code on client and server.
- Per-country method config is data in `src/lib/methods.ts`; adding a country is one entry.
- Times are formatted in the device's/subscription's IANA time zone, never UTC.
- No accounts, analytics, or third-party client calls.
