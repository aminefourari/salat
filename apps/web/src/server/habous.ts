// Official Moroccan timetable (Ministry of Habous), ported from the fr255-watchface Worker
// (github.com/iliassjabali/fr255-watchface, worker/src/adapters/habous-loader.ts).
import type { DayTimes } from '../lib/prayer'
import cities from './habous-cities.json'

/** Six local "HH:MM" times: Fajr, sunrise, Dhuhr, Asr, Maghrib, Isha. */
type Row = string[]
export type HabousMonth = { offsetMin: number; cities: Map<number, Row[]> }

const HHMM = /^\d{2}:\d{2}$/
const FUSEAU = /^GMT(?:([+-])(\d{1,2}))?$/

/** Parses `horaires-YYYY-MM.js` (`(...).push({annee, mois, fuseau, villes: [{c, h: [[6×HH:MM]…]}]})`). */
export function parseMonth(text: string): HabousMonth | null {
  const m = /\.push\((\{[\s\S]*\})\);?\s*$/.exec(text.trim())
  if (!m) return null
  try {
    const { fuseau, villes } = JSON.parse(m[1])
    const f = FUSEAU.exec(fuseau)
    if (!f || !Array.isArray(villes)) return null
    const out = new Map<number, Row[]>()
    for (const v of villes) {
      if (typeof v?.c !== 'number' || !Array.isArray(v.h)) return null
      if (!v.h.every((r: unknown) => Array.isArray(r) && r.length === 6 && r.every(c => typeof c === 'string' && HHMM.test(c)))) return null
      out.set(v.c, v.h)
    }
    return { offsetMin: (f[1] === '-' ? -1 : 1) * Number(f[2] ?? 0) * 60, cities: out }
  } catch {
    return null
  }
}

const MAX_KM = 25
/** Habous city id nearest to (lat, lon), or null when none is within 25 km (then the app calculates). */
export function habousCity(lat: number, lon: number): number | null {
  const r = Math.PI / 180
  let best: number | null = null, bestKm = MAX_KM
  for (const c of cities) {
    const dLat = (c.lat - lat) * r, dLon = (c.lon - lon) * r
    const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat * r) * Math.cos(c.lat * r) * Math.sin(dLon / 2) ** 2
    const km = 12742 * Math.asin(Math.min(1, Math.sqrt(h)))
    if (km <= bestKm) { bestKm = km; best = c.id }
  }
  return best
}

/** Times of `city` on `date` (YYYY-MM-DD, Moroccan calendar day), or null when the month has no row. */
export function habousDay(month: HabousMonth, city: number, date: string): DayTimes | null {
  const [y, mo, d] = date.split('-').map(Number)
  const row = month.cities.get(city)?.[d - 1]
  if (!row) return null
  const at = (hhmm: string) => {
    const [h, mi] = hhmm.split(':').map(Number)
    return new Date(Date.UTC(y, mo - 1, d, h, mi) - month.offsetMin * 60_000)
  }
  const [fajr, sunrise, dhuhr, asr, maghrib, isha] = row.map(at)
  return { fajr, sunrise, dhuhr, asr, maghrib, isha }
}

const UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36'
// ponytail: a parsed month lives as long as the isolate; Habous corrections show up when it recycles.
const memo = new Map<string, Promise<HabousMonth | null>>()

/** Month file for `YYYY-MM`, via the Workers cache (24 h) and an in-isolate memo; null when unavailable. */
export function loadMonth(ym: string): Promise<HabousMonth | null> {
  let p = memo.get(ym)
  if (!p) {
    p = fetchMonth(ym).then(m => { if (!m) memo.delete(ym); return m })
    memo.set(ym, p)
  }
  return p
}

async function fetchMonth(ym: string): Promise<HabousMonth | null> {
  const url = `https://www.habous.gov.ma/data/horaires-${ym}.js`
  const key = new Request(url)
  const cache = typeof caches === 'undefined' ? undefined : (caches as unknown as { default: Cache }).default
  try {
    const hit = await cache?.match(key)
    if (hit) return parseMonth(await hit.text())
    const res = await fetch(url, { headers: { 'user-agent': UA } })
    if (!res.ok) return null
    const text = await res.text()
    const month = parseMonth(text)
    if (month) await cache?.put(key, new Response(text, { headers: { 'cache-control': 'public, max-age=86400' } }))
    return month
  } catch (err) {
    console.error('habous fetch failed', ym, err)
    return null
  }
}

/** Official times for each of `dates` near (lat, lon); null when no Habous city is near or the data is missing. */
export async function habousDays(lat: number, lon: number, dates: string[]): Promise<Map<string, DayTimes> | null> {
  const city = habousCity(lat, lon)
  if (city == null) return null
  const out = new Map<string, DayTimes>()
  for (const date of dates) {
    const month = await loadMonth(date.slice(0, 7))
    const day = month && habousDay(month, city, date)
    if (day) out.set(date, day)
  }
  return out.size ? out : null
}
