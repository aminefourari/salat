import { readFileSync } from 'node:fs'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { computeDay, formatHM } from '../src/lib/prayer'
import { habousDayTimes, type Row } from '../src/server/cron'
import { habousCity, habousDay, parseMonth } from '../src/server/habous'

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

  it('gives cron the official times for Moroccan subscribers only', async () => {
    const fetch = vi.fn(async () => new Response(text))
    vi.stubGlobal('fetch', fetch)
    const row = (lat: number, lon: number, asr = 'standard'): Row => ({
      endpoint: 'e', p256dh: '', auth: '', lat, lon, tz: TZ, method: 'auto', asr, lang: 'fr',
      notify_start: 1, notify_reminder: 1, last_sent_at: 0, updated_at: 0,
    })
    const now = new Date('2026-11-11T12:00:00Z')
    const times = (await habousDayTimes(row(CASA.lat, CASA.lon), now))!
    expect(times('2026-11-11')).toEqual(habousDay(parseMonth(text)!, 58, '2026-11-11'))
    expect(await habousDayTimes(row(CASA.lat, CASA.lon, 'hanafi'), now)).toBeUndefined()
    expect(await habousDayTimes(row(31.0, -4.0), now)).toBeUndefined() // desert, no city near
    expect(fetch).toHaveBeenCalledTimes(1) // month memoised
  })
})
