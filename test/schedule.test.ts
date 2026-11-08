import { describe, expect, it } from 'vitest'
import { computeDay, dateIn, type Settings } from '../src/lib/prayer'
import { dueEvents, type Sub } from '../src/lib/schedule'

const settings: Settings = { method: 'aachen', asr: 'standard', lang: 'en' }
const sub = (o: Partial<Sub> = {}): Sub => ({
  lat: 53.4319, lon: 11.1903, tz: 'Europe/Berlin', settings,
  notifyStart: true, notifyReminder: true, lastSentAt: 0, ...o,
})
const MIN = 60_000
const isha = computeDay(53.4319, 11.1903, '2026-11-08', 'Europe/Berlin', settings).isha

describe('dueEvents', () => {
  it('fires Isha start once', () => {
    const now = new Date(isha.getTime() + 20_000)
    const ev = dueEvents(sub({ lastSentAt: now.getTime() - MIN }), now)
    expect(ev.map(e => `${e.prayer}:${e.kind}`)).toEqual(['isha:start'])
    expect(dueEvents(sub({ lastSentAt: now.getTime() }), new Date(now.getTime() + 30_000))).toEqual([])
  })

  it('fires reminder 10 min before', () => {
    const now = new Date(isha.getTime() - 10 * MIN)
    const ev = dueEvents(sub({ lastSentAt: now.getTime() - MIN }), now)
    expect(ev).toEqual([{ prayer: 'isha', kind: 'reminder', at: now, prayerTime: isha }])
  })

  it('skips events older than 5 min (e.g. after an outage)', () => {
    expect(dueEvents(sub(), new Date(isha.getTime() + 6 * MIN))).toEqual([])
  })

  it('respects notifyStart=false', () => {
    const now = new Date(isha.getTime())
    expect(dueEvents(sub({ notifyStart: false, lastSentAt: now.getTime() - MIN }), now)).toEqual([])
  })

  it('uses the subscription time zone (New York)', () => {
    const tz = 'America/New_York'
    const ny = { lat: 40.71, lon: -74.0, settings: { ...settings, method: 'isna' as const } }
    const t = computeDay(ny.lat, ny.lon, '2026-11-08', tz, ny.settings).fajr
    expect(dateIn(t, tz)).toBe('2026-11-08')
    const ev = dueEvents(sub({ ...ny, tz, lastSentAt: t.getTime() - MIN }), t)
    expect(ev.map(e => `${e.prayer}:${e.kind}`)).toEqual(['fajr:start'])
  })

  it('fires each event exactly once across a DST-change day, minute by minute', () => {
    for (const day of ['2026-10-25', '2026-03-29']) {
      const s = sub()
      const start = new Date(`${day}T00:00:00+01:00`).getTime() - 60 * MIN
      s.lastSentAt = start
      const seen: string[] = []
      for (let t = start + MIN; t < start + 26 * 60 * MIN; t += MIN) {
        for (const e of dueEvents(s, new Date(t))) seen.push(`${dateIn(e.prayerTime, s.tz)}:${e.prayer}:${e.kind}`)
        s.lastSentAt = t
      }
      const forDay = seen.filter(x => x.startsWith(day))
      expect(forDay.length, day).toBe(10)
      expect(new Set(forDay).size).toBe(10)
    }
  })
})
