// Exports the data the Mac app needs from the web's own sources and pins web↔Mac parity.
// Regenerate after changing methods/prayer math or the bundled data: UPDATE_MAC_DATA=1 npm test
import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import { borders, feature, iso1A2Code } from '@rapideditor/country-coder'
import { describe, expect, it } from 'vitest'
import aachen from './fixtures/aachen-2026.json'
import cities from '../src/server/cities.data'
import { METHOD_IDS } from '../src/lib/methods'
import { countryAt } from '../src/lib/country'
import { adjustDay, computeDay, hijriDate, resolved } from '../src/lib/prayer'
import { dayEvents } from '../src/lib/schedule'

const root = new URL('../../../', import.meta.url)
const res = new URL('apps/macos/Salat/Resources/', root)
const update = !!process.env.UPDATE_MAC_DATA

const PLACES: [string, number, number, string][] = [
  ['Hagenow', 53.4319, 11.1903, 'Europe/Berlin'],
  ['Aachen', aachen.lat, aachen.lon, 'Europe/Berlin'],
  ['Casablanca', 33.5731, -7.5898, 'Africa/Casablanca'],
  ['Makkah', 21.4225, 39.8262, 'Asia/Riyadh'],
  ['Paris', 48.8566, 2.3522, 'Europe/Paris'],
  ['Oslo', 59.9139, 10.7522, 'Europe/Oslo'],
  ['New York', 40.7128, -74.006, 'America/New_York'],
]
const DATES = ['2026-01-15', '2026-03-29', '2026-06-21', '2026-11-08']
const KEYS = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'] as const

function prayerCases() {
  const out = []
  for (const [, lat, lon, tz] of PLACES)
    for (const date of DATES)
      for (const method of [...METHOD_IDS, 'auto' as const])
        for (const asr of ['standard', 'hanafi'] as const) {
          const r = resolved(countryAt(lat, lon), { method, asr, lang: 'en' })
          const d = computeDay(lat, lon, date, tz, r)
          // Unix minutes, not local HH:mm: the two apps' time-zone databases can differ (e.g. Morocco's offset).
          const times = Object.fromEntries(KEYS.map(k => [k, Math.floor(d[k].getTime() / 60_000)]))
          out.push({ lat, lon, date, tz, method: r.method, asr, times })
        }
  return out
}

// Places whose Dhuhr is near noon UTC, so the Mac's "Friday = weekday of Dhuhr in the machine's zone" agrees with
// the date for any machine zone within ±10 h (CI runs in UTC).
const EVENT_PLACES = PLACES.filter(([n]) => ['Hagenow', 'Casablanca', 'Paris'].includes(n))
const EVENT_DATES = ['2026-03-27', '2026-06-21', '2026-11-13'] // two Fridays and a Sunday
const ADJUSTS = [{}, { fajr: -2, maghrib: 3, isha: 30 }]

/** Every reminder event of a day (all switches on, with and without minute offsets), as unix minutes. */
function scheduleCases() {
  const out = []
  for (const [, lat, lon, tz] of EVENT_PLACES)
    for (const date of EVENT_DATES)
      for (const adjust of ADJUSTS) {
        const s = resolved(countryAt(lat, lon), { method: 'auto', asr: 'standard', lang: 'en' })
        const day = adjustDay(computeDay(lat, lon, date, tz, s), adjust)
        const events = dayEvents({ notifyStart: true, notifyReminder: true, notifyAdhkar: true, notifyFriday: true }, date, day)
          .map(e => ({ kind: e.kind, prayer: e.prayer, at: Math.floor(e.at.getTime() / 60_000) }))
          .sort((a, b) => a.at - b.at || a.kind.localeCompare(b.kind) || a.prayer.localeCompare(b.prayer))
        out.push({ lat, lon, date, method: s.method, asr: 'standard', adjust, events })
      }
  return out
}

/** Umm al-Qura month at noon UTC every 5 days through 2026–2027 (two Ramadans, every month boundary area). */
function hijriCases() {
  const out = []
  for (let t = Date.UTC(2026, 0, 1, 12); t < Date.UTC(2028, 0, 1, 12); t += 5 * 86_400_000)
    out.push({ ms: t, month: hijriDate(new Date(t), 0, 'en')!.month })
  return out
}

function countryCases() {
  const pts: [number, number][] = [
    ...PLACES.map(([, lat, lon]) => [lat, lon] as [number, number]),
    [35.7595, -5.834], [27.1536, -13.2033], [35.8894, -5.3213], [48.5734, 7.7521], [48.5726, 7.8156],
    [47.5596, 7.5886], [30, -40],
  ]
  let seed = 42
  const rnd = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 2 ** 32)
  for (let i = 0; i < 500; i++) pts.push([-60 + rnd() * 130, -180 + rnd() * 360])
  const r = (x: number) => Math.round(x * 1e4) / 1e4
  return pts.map(([lat, lon]) => ({ lat: r(lat), lon: r(lon), cc: iso1A2Code([r(lon), r(lat)]) ?? null }))
}

/** One entry per polygon; `cc` resolved the way country-coder's countryFeature does. */
function bordersExport() {
  const out: { cc: string | null; polys: number[][][][] }[] = []
  for (const f of borders.features) {
    const g = f.geometry as { type: string; coordinates: number[][][] | number[][][][] } | null
    if (!g) continue
    const code = f.properties.country || f.properties.iso1A2
    const cc = (code && feature(code)?.properties.iso1A2) || null
    const polys = (g.type === 'Polygon' ? [g.coordinates] : g.coordinates) as number[][][][]
    out.push({ cc, polys })
  }
  return out
}

function check(file: URL, build: () => unknown, raw = false) {
  const want = build()
  if (update) writeFileSync(file, raw ? (want as string) : JSON.stringify(want))
  expect(existsSync(file), `${file.pathname} missing: run UPDATE_MAC_DATA=1 npm test`).toBe(true)
  const got = readFileSync(file, 'utf8')
  if (raw) expect(got === want).toBe(true)
  else expect(JSON.parse(got)).toEqual(want)
}

describe('mac data export', () => {
  it('parity fixture matches the web code', () =>
    check(new URL('fixtures/parity.json', root), () => ({ prayer: prayerCases(), country: countryCases(), schedule: scheduleCases(), hijri: hijriCases() })))
  it('borders resource matches country-coder', () => check(new URL('borders.json', res), bordersExport))
  it('cities resource matches cities.data', () => check(new URL('cities.txt', res), () => cities, true))
})
