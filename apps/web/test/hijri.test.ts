import { describe, expect, it } from 'vitest'
import { adjustDay, computeDay, hijriDate, hijriOffset, imsak, type Settings } from '../src/lib/prayer'

const s: Settings = { method: 'auto', asr: 'standard', lang: 'en' }

describe('Hijri date', () => {
  it('reads the Umm al-Qura month and shifts by the offset', () => {
    // 1 Ramadan 1447 (Umm al-Qura) is 18 Feb 2026.
    expect(hijriDate(new Date('2026-02-18T12:00:00Z'), 0, 'en')?.month).toBe(9)
    expect(hijriDate(new Date('2026-02-18T12:00:00Z'), -1, 'en')?.month).toBe(8)
    expect(hijriDate(new Date('2026-02-18T12:00:00Z'), 0, 'en')?.label).toMatch(/Ramadan 1, 1447/)
  })

  it('defaults to −1 in Morocco, 0 elsewhere; a chosen offset wins', () => {
    expect(hijriOffset(33.57, -7.59, s)).toBe(-1)
    expect(hijriOffset(50.77, 6.08, s)).toBe(0)
    expect(hijriOffset(33.57, -7.59, { ...s, hijri: 0 })).toBe(0)
  })
})

describe('adjustDay / imsak', () => {
  const day = computeDay(50.77, 6.08, '2026-11-11', 'Europe/Berlin', s)
  it('adds minutes per prayer and leaves sunrise alone', () => {
    const a = adjustDay(day, { fajr: -2, maghrib: 3 })
    expect(a.fajr.getTime() - day.fajr.getTime()).toBe(-2 * 60_000)
    expect(a.maghrib.getTime() - day.maghrib.getTime()).toBe(3 * 60_000)
    expect(a.sunrise).toBe(day.sunrise)
    expect(adjustDay(day, undefined)).toBe(day)
  })
  it('imsak is 10 minutes before Fajr', () => {
    expect(day.fajr.getTime() - imsak(day).getTime()).toBe(10 * 60_000)
  })
})
