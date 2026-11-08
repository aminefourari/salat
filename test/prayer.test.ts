import { describe, expect, it } from 'vitest'
import fixture from './fixtures/aachen-2026.json'
import { computeDay, formatHM, nextPrayer, paramsFor, skyAt, type Settings } from '../src/lib/prayer'
import { countryAt, methodForCountry } from '../src/lib/methods'

const TZ = 'Europe/Berlin'
const HAGENOW = [53.4319, 11.1903] as const
const KEYS = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'] as const
const s: Settings = { method: 'aachen', asr: 'standard', lang: 'en' }
const mins = (hm: string) => +hm.slice(0, 2) * 60 + +hm.slice(3)
const diff = (a: string, b: string) => ((mins(a) - mins(b) + 720 + 1440) % 1440) - 720

function expectNear(got: Record<string, Date>, want: string[], tol: number, shift: Partial<Record<string, number>> = {}) {
  KEYS.forEach((k, i) => {
    const d = diff(formatHM(got[k], TZ), want[i]) - (shift[k] ?? 0)
    expect(Math.abs(d), `${k} got ${formatHM(got[k], TZ)} want ${want[i]}`).toBeLessThanOrEqual(tol)
  })
}

describe('aachen method', () => {
  it('hagenow matches Muslim Pro (no margins)', () => {
    const p = paramsFor('aachen', 'standard', { margins: false })
    expectNear(computeDay(...HAGENOW, '2026-11-08', TZ, s, p), ['05:27', '07:26', '11:59', '14:05', '16:31', '18:21'], 3)
    expectNear(computeDay(...HAGENOW, '2026-06-21', TZ, s, p), ['02:40', '04:45', '13:17', '17:44', '21:49', '23:43'], 3)
  })

  it('hagenow with center margins', () => {
    expectNear(computeDay(...HAGENOW, '2026-06-21', TZ, s), ['02:41', '04:39', '13:22', '17:48', '21:55', '23:43'], 1)
  })

  // The center's own table vs our Muslim Pro–matching method: Isha is deliberately 3 min earlier.
  it('aachen fixture Sep–Mar within 4 min', () => {
    const times = fixture.times as unknown as Record<string, Record<string, Record<string, { t: string }>>>
    let n = 0
    for (const m of ['1', '2', '3', '9', '10', '11', '12']) {
      for (const [day, v] of Object.entries(times[m])) {
        const date = `2026-${m.padStart(2, '0')}-${day.padStart(2, '0')}`
        expectNear(computeDay(fixture.lat, fixture.lon, date, TZ, s), KEYS.map((_, i) => v[`p${i + 1}`].t), 4, { isha: -3 })
        n++
      }
    }
    expect(n).toBe(212)
  })
})

describe('country → method', () => {
  it('maps countries', () => {
    expect(methodForCountry('DE')).toBe('aachen')
    expect(methodForCountry('MA')).toBe('morocco')
    expect(methodForCountry('XX')).toBe('mwl')
    expect(methodForCountry(null)).toBe('mwl')
  })
  it('finds country from coordinates', () => {
    expect(countryAt(53.43, 11.19)).toBe('DE')
    expect(countryAt(33.57, -7.59)).toBe('MA')
  })
})

describe('next prayer and sky', () => {
  const day = computeDay(...HAGENOW, '2026-11-08', TZ, s)
  const tom = computeDay(...HAGENOW, '2026-11-09', TZ, s)
  const at = (hm: string) => new Date(`2026-11-08T${hm}:00+01:00`)
  it('picks the next prayer, rolling to tomorrow after Isha', () => {
    expect(nextPrayer(day, tom, at('13:00')).prayer).toBe('asr')
    expect(nextPrayer(day, tom, at('23:00'))).toEqual({ prayer: 'fajr', at: tom.fajr })
  })
  it('maps time to sky period', () => {
    expect([at('03:00'), at('06:00'), at('12:00'), at('15:00'), at('17:00'), at('22:00')].map(n => skyAt(day, n)))
      .toEqual(['night', 'dawn', 'day', 'afternoon', 'dusk', 'night'])
  })
})

describe('high-latitude rule', () => {
  it('non-Aachen methods use TwilightAngle in summer up north (no Isha after midnight)', () => {
    const d = computeDay(...HAGENOW, '2026-06-21', TZ, { method: 'mwl', asr: 'standard', lang: 'en' })
    expect(formatHM(d.isha, TZ) > '23:00' && formatHM(d.isha, TZ) < '23:59', formatHM(d.isha, TZ)).toBe(true)
    expect(formatHM(d.fajr, TZ) > '02:00' && formatHM(d.fajr, TZ) < '03:30', formatHM(d.fajr, TZ)).toBe(true)
  })
})
