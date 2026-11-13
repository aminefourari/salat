// Official Moroccan timetable (Ministry of Habous), ported from the fr255-watchface Worker
// (github.com/iliassjabali/fr255-watchface, worker/src/adapters/habous-loader.ts).
import { dateIn, type DayTimes } from '../lib/prayer'
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

/** Months a client may ask for: last month to next month, Moroccan calendar (clients ask for today's or tomorrow's). */
export function monthInWindow(ym: string, now: Date): boolean {
  const [y, m] = dateIn(now, 'Africa/Casablanca').split('-').map(Number)
  const [qy, qm] = ym.split('-').map(Number)
  const diff = qy * 12 + qm - (y * 12 + m)
  return diff >= -1 && diff <= 1
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
const KEYS = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'] as const
/** One stored day: city, YYYY-MM-DD, then the six times in epoch ms. */
export type StoredRow = [number, string, number, number, number, number, number, number]

/** Where imported months live (D1 in the Worker, memory in tests). */
export type HabousStore = {
  hasMonth(month: string): Promise<boolean>
  putMonth(month: string, rows: StoredRow[]): Promise<void>
  days(city: number, dates: string[]): Promise<Map<string, DayTimes>>
}

/** All rows of a parsed month file, every city. */
export function monthRows(ym: string, month: HabousMonth): StoredRow[] {
  const out: StoredRow[] = []
  for (const [city, rows] of month.cities)
    rows.forEach((_, i) => {
      const date = `${ym}-${String(i + 1).padStart(2, '0')}`
      const d = habousDay(month, city, date)!
      out.push([city, date, ...KEYS.map(k => d[k].getTime())] as StoredRow)
    })
  return out
}

async function fetchMonth(ym: string): Promise<HabousMonth | null> {
  try {
    const res = await fetch(`https://www.habous.gov.ma/data/horaires-${ym}.js`, { headers: { 'user-agent': UA } })
    return res.ok ? parseMonth(await res.text()) : null
  } catch (err) {
    console.error('habous fetch failed', ym, err)
    return null
  }
}

const RETRY_MS = 10 * 60_000
const stored = new Set<string>() // months known to be in the store (skips a query per request)
const importing = new Map<string, Promise<boolean>>()
const failedAt = new Map<string, number>()

/** Makes sure `ym` is in the store: fetched from Habous once, then never again. Failures retry after 10 min. */
// ponytail: a stored month is never refreshed; to take a Habous correction, DELETE its habous_months row.
export function ensureMonth(store: HabousStore, ym: string): Promise<boolean> {
  if (stored.has(ym)) return Promise.resolve(true)
  let p = importing.get(ym)
  if (!p) {
    p = (async () => {
      if (await store.hasMonth(ym)) return true
      if (Date.now() - (failedAt.get(ym) ?? -Infinity) < RETRY_MS) return false
      const month = await fetchMonth(ym)
      if (!month) { failedAt.set(ym, Date.now()); return false }
      await store.putMonth(ym, monthRows(ym, month))
      return true
    })().then(ok => { if (ok) stored.add(ym); return ok }).finally(() => importing.delete(ym))
    importing.set(ym, p)
  }
  return p
}

/** Official times for each of `dates` near (lat, lon); null when no Habous city is near or none is available. */
export async function habousDays(store: HabousStore, lat: number, lon: number, dates: string[]): Promise<Map<string, DayTimes> | null> {
  const city = habousCity(lat, lon)
  if (city == null) return null
  for (const ym of new Set(dates.map(d => d.slice(0, 7)))) await ensureMonth(store, ym)
  const out = await store.days(city, dates)
  return out.size ? out : null
}

export const d1HabousStore = (db: D1Database): HabousStore => ({
  hasMonth: async ym => !!(await db.prepare('SELECT 1 FROM habous_months WHERE month = ?').bind(ym).first()),
  putMonth: async (ym, rows) => {
    // One statement for the whole month (~5,700 rows) via json_each, in the same transaction as the month marker.
    const cols = ['city', 'date', ...KEYS]
    await db.batch([
      db.prepare(`INSERT OR REPLACE INTO habous_times (${cols.join(', ')})
        SELECT ${cols.map((_, i) => `json_extract(value, '$[${i}]')`).join(', ')} FROM json_each(?)`).bind(JSON.stringify(rows)),
      db.prepare('INSERT OR REPLACE INTO habous_months (month, fetched_at) VALUES (?, ?)').bind(ym, Date.now()),
    ])
  },
  days: async (city, dates) => {
    const { results } = await db.prepare(`SELECT * FROM habous_times WHERE city = ? AND date IN (${dates.map(() => '?').join(', ')})`)
      .bind(city, ...dates).all<Record<string, number> & { date: string }>()
    return new Map(results.map(r => [r.date, Object.fromEntries(KEYS.map(k => [k, new Date(r[k])])) as DayTimes]))
  },
})
