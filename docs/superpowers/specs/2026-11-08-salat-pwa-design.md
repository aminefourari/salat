# Salat — prayer times PWA

## Intent

A personal prayer-times app installable on phone and Mac (one PWA, reachable anywhere).
It uses the device's location to show the correct daily prayer times and sends a push
notification on every subscribed device when a prayer starts, plus a reminder 10 minutes before.
Reference for "correct": the user trusts Muslim Pro's times for their location, so ours should
match Muslim Pro's within a minute or two.

## Goals

- Show today's five prayers (Fajr, Dhuhr, Asr, Maghrib, Isha) for the current location, with the
  next prayer highlighted and a countdown to it. Sunrise shown as info (not a prayer, no notification).
- Location via browser Geolocation. Times are computed on the device. Re-check location on app
  open; if it moved meaningfully (city level, ~5 km), recompute and update the server copy.
  Each device keeps its own last-known location for notifications (my call: browsers can't read
  location while the app is closed). The app shows "location last updated in <place>".
- Calculation method auto-picked from country, like Muslim Pro (e.g. Saudi Arabia → Umm al-Qura,
  France → UOIF, North America → ISNA, Egypt → Egyptian, Morocco → Moroccan, Gulf states → their
  official methods, Turkey → Diyanet, default → Muslim World League). Overridable in settings.
  - **Germany → "Islamic Center Aachen"** (what Muslim Pro uses for the user). Settled by
    comparing against Muslim Pro for Hagenow on 8 Nov 2026 and 21 Jun 2026 (summer is the hard case):
    - Muslim Pro = Fajr 18°, Isha 17°, high-latitude rule **TwilightAngle** (adhan built-in), Isha −3 min.
      Matches Muslim Pro within 0–3 min on both dates.
    - **User decision: keep the center's safety margins** (Diyanet temkin) on top: Sunrise −7,
      Dhuhr +5, Asr +4, Maghrib +7 min. Fajr/Isha get no margin.
    - Reference values, Hagenow (53.4319, 11.1903), Europe/Berlin, *without* margins:
      - 2026-11-08 Muslim Pro: 05:27 07:26 11:59 14:05 16:31 18:21
      - 2026-06-21 Muslim Pro: 02:40 04:45 13:17 17:44 21:49 23:43
      Tests: method without margins within ±3 min of these; with margins, the offsets add up exactly.
    - The center's own timetable (`Aachen.json`, user-supplied, committed as a fixture) uses the same
      margins and matches within ~4 min Sep–Mar, but its summer Fajr/Isha rule differs (up to ~50 min
      earlier Isha in June). We follow Muslim Pro's summer rule, since that is the user's reference.
    Each country's entry is just data in one table, so adding/fixing a country is a one-line change.
  - **Update 2026-11-08:** the Habous site is unreachable from outside Morocco (dev machine and Cloudflare
    Worker both time out) and no downloadable timetable was found, so Morocco ships with the computed
    Fajr 19° / Isha 17° method plus a visible note that times may differ by a few minutes.
  - *(Original intent)* **Morocco → strictly the official Ministry of Habous timetable** (user decision). Habous
    publishes per-city timetables (habous.gov.ma); in Morocco the app shows the published times for
    the nearest Habous city, not a calculation. The Worker fetches and caches each city's timetable
    (D1), and the client gets them from the Worker, cached for offline. Scheduling for Moroccan
    subscriptions reads the same data. Fallback when a timetable can't be fetched: compute with
    Fajr 19° / Isha 17° and show a small "approximate" label. The builder must first confirm the
    Habous source is fetchable from a Worker (format, city list, how far ahead it's published).
  - **Country comes from the user's GPS coordinates**, not IP or settings: an offline
    coordinates→country lookup bundled with the app, so travel (e.g. Germany → Morocco) switches
    method automatically and it works offline. Manual override in settings still wins.
- Asr: standard (Shafi'i/Maliki/Hanbali) by default, Hanafi toggle in settings.
- Push notifications at each prayer time and 10 minutes before:
  - at time: "It's time for Isha — 19:42"
  - reminder: "Isha in 10 minutes — 19:42"
  Works when the app is closed, on Mac (Chrome/Safari) and phone (Android; iOS 16.4+ once added to
  Home Screen). Each device subscribes independently.
- Languages: Arabic, English, French. One language setting drives both UI and notification text.
  Arabic is RTL. Default from browser language.
- Qibla direction: bearing in degrees from current location, plus a live compass arrow on devices
  with orientation sensors (iOS needs a tap-to-allow permission). On desktop, show bearing only.
- Settings: language, calculation method, Asr method, notifications on/off for at-time and for
  10-min reminder (separately).
- Works offline for viewing times (cached app shell; times computed locally).

## Non-goals

- No accounts or login. A device is identified by its push subscription only.
- No adhan audio playback, no Quran, no hijri calendar beyond maybe a date line, no social features.
- No per-prayer manual minute adjustments (can come later if a mosque differs).
- No native apps.

## Anti-goals (failure even if it "works")

- Times that disagree with Muslim Pro by more than a couple of minutes for the user's location.
- Missed or late notifications (more than ~1 minute late), or duplicate notifications.
- Notifications in the wrong time zone after travel.
- Any ads, tracking, or third-party analytics. Location stays between the device and the user's own
  Cloudflare account.

## Constraints (decided by the user)

- Cloudflare only, using the user's existing Cloudflare account (operated via the browse MCP when
  dashboard work is needed; wrangler CLI is fine for deploys).
- Website built with TanStack Start, deployed on Cloudflare Workers.

## How it works (builder's plan, recorded as my calls)

- **Calculation:** the `adhan` JS library, same code on client (display) and Worker (scheduling), so
  both agree. Country for method auto-pick comes from the device's coordinates (offline lookup, see Goals).
- **Storage:** Cloudflare D1 table of subscriptions: endpoint, keys, lat, lon, IANA timezone,
  method, asr, language, reminder flags, plus last-sent marker to prevent duplicates.
- **Scheduling:** Worker cron trigger every minute. For each subscription, compute today's times
  in its time zone and send anything due in the current minute (prayer or prayer−10 min).
  `ponytail:` scanning all rows each minute is fine for a handful of devices; precompute a
  next-due column if it ever grows.
- **Push:** Web Push with VAPID, implemented with WebCrypto (Node `web-push` doesn't run on
  Workers); builder picks a Workers-compatible library or writes the small encrypt/sign piece.
  VAPID private key stored as a Worker secret. Expired subscriptions (404/410) are deleted.
- **PWA:** web manifest, icons generated from `assets/icon.svg`, service worker handling `push`
  and `notificationclick` (opens the app), and caching the app shell.

## Left to the builder

Visual design, project layout, exact library choices beyond `adhan`, the method-by-country table
details, and the Cloudflare resource names.
