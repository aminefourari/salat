// Exports the data the Mac app needs from the web's own sources and pins web↔Mac parity.
// Regenerate after changing methods/prayer math or the bundled data: UPDATE_MAC_DATA=1 npm test
import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import { borders, feature, iso1A2Code } from '@rapideditor/country-coder'
import { describe, expect, it } from 'vitest'
import aachen from './fixtures/aachen-2026.json'
import cities from '../src/server/cities.data'
import { METHOD_IDS, type MethodId } from '../src/lib/methods'
import { computeDay, resolveMethod, type Settings } from '../src/lib/prayer'

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
          const s: Settings = { method, asr, lang: 'en' }
          const d = computeDay(lat, lon, date, tz, s)
          // Unix minutes, not local HH:mm: the two apps' time-zone databases can differ (e.g. Morocco's offset).
          const times = Object.fromEntries(KEYS.map(k => [k, Math.floor(d[k].getTime() / 60_000)]))
          out.push({ lat, lon, date, tz, method: resolveMethod(lat, lon, s) as MethodId, asr, times })
        }
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
    check(new URL('fixtures/parity.json', root), () => ({ prayer: prayerCases(), country: countryCases() })))
  it('borders resource matches country-coder', () => check(new URL('borders.json', res), bordersExport))
  it('cities resource matches cities.data', () => check(new URL('cities.txt', res), () => cities, true))
})
