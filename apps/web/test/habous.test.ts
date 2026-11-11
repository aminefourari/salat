import { readFileSync } from 'node:fs'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { computeDay, formatHM, type DayTimes } from '../src/lib/prayer'
import { habousDayTimes, type Row } from '../src/server/cron'
import { habousCity, habousDay, habousDays, parseMonth, type HabousStore, type StoredRow } from '../src/server/habous'

// Real Habous file for 2026-11, trimmed to Rabat (1) and Casablanca (58).
const text = readFileSync(new URL('./fixtures/habous-2026-11.js', import.meta.url), 'utf8')
const CASA = { lat: 33.5731, lon: -7.5898 }
const TZ = 'Africa/Casablanca'

describe('habous', () => {
  afterEach(() => vi.unstubAllGlobals())

  it('parses the month file and rejects anything else', () => {
    const m = parseMonth(text)!
    expect(m.offsetMin).toBe(0)
    expect(m.cities.get(1)![0]).toEqual(['05:17', '06:44', '12:16', '15:12', '17:39', '18:54'])
    expect(parseMonth('<html>blocked</html>')).toBeNull()
    expect(parseMonth(text.replace('"05:17"', '"5:17"'))).toBeNull()
    expect(parseMonth(text.replace('"fuseau":"GMT"', '"fuseau":"GMT+1"'))!.offsetMin).toBe(60)
  })

  it('finds the nearest listed city within 25 km', () => {
    expect(habousCity(CASA.lat, CASA.lon)).toBe(58)
    expect(habousCity(34.02, -6.84)).toBe(1)
    expect(habousCity(50.7753, 6.0839)).toBeNull() // Aachen
  })

  it('turns the GMT-stamped row into instants that format in Morocco time, close to the 19°/17° calculation', () => {
    const day = habousDay(parseMonth(text)!, 58, '2026-11-11')!
    const calc = computeDay(CASA.lat, CASA.lon, '2026-11-11', TZ, { method: 'morocco', asr: 'standard', lang: 'en' })
    for (const k of ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'] as const)
      expect(Math.abs(day[k].getTime() - calc[k].getTime())).toBeLessThan(10 * 60_000)
    expect(habousDay(parseMonth(text)!, 58, '2026-11-31')).toBeNull()
    expect(formatHM(day.fajr, TZ)).toMatch(/^0[5-7]:\d{2}$/)
  })

  it('imports a month from Habous once, then serves it from the store; cron uses it for Moroccan subscribers only', async () => {
    const fetch = vi.fn(async (url: string) => (url.includes('2026-11') ? new Response(text) : new Response('', { status: 503 })))
    vi.stubGlobal('fetch', fetch)
    const store = memStore()
    const dayTimes = habousDayTimes(store)
    const row = (lat: number, lon: number, asr = 'standard'): Row => ({
      endpoint: 'e', p256dh: '', auth: '', lat, lon, tz: TZ, method: 'auto', asr, lang: 'fr',
      notify_start: 1, notify_reminder: 1, last_sent_at: 0, updated_at: 0,
    })
    const now = new Date('2026-11-11T12:00:00Z')
    const times = (await dayTimes(row(CASA.lat, CASA.lon), now))!
    expect(times('2026-11-11')).toEqual(habousDay(parseMonth(text)!, 58, '2026-11-11'))
    expect(store.rows.size).toBe(2 * 30) // both cities of the fixture, every day
    await dayTimes(row(34.02, -6.84), now) // Rabat, same month: no new fetch
    expect(await dayTimes(row(CASA.lat, CASA.lon, 'hanafi'), now)).toBeUndefined()
    expect(await dayTimes(row(31.0, -4.0), now)).toBeUndefined() // desert, no city near
    expect(fetch).toHaveBeenCalledTimes(1)

    // December isn't published: calculated (null), and Habous isn't asked again for 10 minutes.
    expect(await habousDays(store, CASA.lat, CASA.lon, ['2026-12-01'])).toBeNull()
    expect(await habousDays(store, CASA.lat, CASA.lon, ['2026-12-01'])).toBeNull()
    expect(fetch).toHaveBeenCalledTimes(2)
  })
})

function memStore(): HabousStore & { rows: Map<string, StoredRow> } {
  const months = new Set<string>(), rows = new Map<string, StoredRow>()
  const keys = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'] as const
  return {
    rows,
    hasMonth: async ym => months.has(ym),
    putMonth: async (ym, rs) => { months.add(ym); for (const r of rs) rows.set(`${r[0]} ${r[1]}`, r) },
    days: async (city, dates) => new Map(dates.flatMap(d => {
      const r = rows.get(`${city} ${d}`)
      return r ? [[d, Object.fromEntries(keys.map((k, i) => [k, new Date(r[i + 2])])) as DayTimes]] : []
    })),
  }
}
