import { computeDay, dateIn, PRAYERS, type DayTimes, type Prayer, type Settings } from './prayer'

export type Sub = {
  lat: number; lon: number; tz: string; settings: Settings
  notifyStart: boolean; notifyReminder: boolean; lastSentAt: number
}
export type DueEvent = { prayer: Prayer; kind: 'start' | 'reminder'; at: Date; prayerTime: Date }

const MIN = 60_000
export const REMINDER_MIN = 10
const MAX_LATE = 5 * MIN

const shiftDate = (date: string, days: number) =>
  new Date(Date.parse(`${date}T12:00:00Z`) + days * 86_400_000).toISOString().slice(0, 10)

/** Events with `at` in (max(lastSentAt, now − 5 min), now]. Looks at yesterday..tomorrow in the sub's tz. */
export function dueEvents(sub: Sub, now: Date, dayTimes?: (date: string) => DayTimes | null): DueEvent[] {
  const from = Math.max(sub.lastSentAt, now.getTime() - MAX_LATE)
  const to = now.getTime()
  const today = dateIn(now, sub.tz)
  const out: DueEvent[] = []
  for (const date of [shiftDate(today, -1), today, shiftDate(today, 1)]) {
    const day = dayTimes?.(date) ?? computeDay(sub.lat, sub.lon, date, sub.tz, sub.settings)
    for (const prayer of PRAYERS) {
      const t = day[prayer]
      const cands: [DueEvent['kind'], number, boolean][] = [
        ['reminder', t.getTime() - REMINDER_MIN * MIN, sub.notifyReminder],
        ['start', t.getTime(), sub.notifyStart],
      ]
      for (const [kind, at, on] of cands)
        if (on && at > from && at <= to) out.push({ prayer, kind, at: new Date(at), prayerTime: t })
    }
  }
  return out.sort((a, b) => a.at.getTime() - b.at.getTime())
}
