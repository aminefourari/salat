import { adjustDay, computeDay, dateIn, PRAYERS, type DayTimes, type Prayer, type Settings } from './prayer'

export type Sub = {
  lat: number; lon: number; tz: string; settings: Settings
  notifyStart: boolean; notifyReminder: boolean; lastSentAt: number
  /** Morning adhkar after Fajr, evening adhkar after Asr. */
  notifyAdhkar?: boolean
  /** Friday: Surat al-Kahf in the morning, Jumuʿah before Dhuhr. */
  notifyFriday?: boolean
}
export type EventKind = 'start' | 'reminder' | 'adhkarMorning' | 'adhkarEvening' | 'kahf' | 'jumuah'
/** `prayer` is the prayer the event hangs off (Fajr for the morning adhkar, Dhuhr for Jumuʿah…). */
export type DueEvent = { prayer: Prayer; kind: EventKind; at: Date; prayerTime: Date }

const MIN = 60_000
export const REMINDER_MIN = 10
/** Morning/evening adhkar this long after Fajr/Asr. */
export const ADHKAR_AFTER_MIN = 20
/** Surat al-Kahf this long after sunrise on Friday; Jumuʿah this long before Dhuhr. */
export const KAHF_AFTER_SUNRISE_MIN = 60
export const JUMUAH_BEFORE_MIN = 45
const MAX_LATE = 5 * MIN

const shiftDate = (date: string, days: number) =>
  new Date(Date.parse(`${date}T12:00:00Z`) + days * 86_400_000).toISOString().slice(0, 10)
export const isFriday = (date: string) => new Date(`${date}T12:00:00Z`).getUTCDay() === 5

/** Every event of one calendar day (`date`, YYYY-MM-DD) for these switches. */
export function dayEvents(sub: Omit<Sub, 'lastSentAt' | 'lat' | 'lon' | 'tz' | 'settings'>, date: string, day: DayTimes): DueEvent[] {
  const out: DueEvent[] = []
  const add = (on: boolean | undefined, prayer: Prayer, kind: EventKind, at: number) =>
    on && out.push({ prayer, kind, at: new Date(at), prayerTime: day[prayer] })
  for (const prayer of PRAYERS) {
    add(sub.notifyReminder, prayer, 'reminder', day[prayer].getTime() - REMINDER_MIN * MIN)
    add(sub.notifyStart, prayer, 'start', day[prayer].getTime())
  }
  add(sub.notifyAdhkar, 'fajr', 'adhkarMorning', day.fajr.getTime() + ADHKAR_AFTER_MIN * MIN)
  add(sub.notifyAdhkar, 'asr', 'adhkarEvening', day.asr.getTime() + ADHKAR_AFTER_MIN * MIN)
  if (isFriday(date)) {
    add(sub.notifyFriday, 'dhuhr', 'kahf', day.sunrise.getTime() + KAHF_AFTER_SUNRISE_MIN * MIN)
    add(sub.notifyFriday, 'dhuhr', 'jumuah', day.dhuhr.getTime() - JUMUAH_BEFORE_MIN * MIN)
  }
  return out
}

/** Events with `at` in (max(lastSentAt, now − 5 min), now]. Looks at yesterday..tomorrow in the sub's tz. */
export function dueEvents(sub: Sub, now: Date, dayTimes?: (date: string) => DayTimes | null): DueEvent[] {
  const from = Math.max(sub.lastSentAt, now.getTime() - MAX_LATE)
  const to = now.getTime()
  const today = dateIn(now, sub.tz)
  return [shiftDate(today, -1), today, shiftDate(today, 1)]
    .flatMap(date => {
      const day = adjustDay(dayTimes?.(date) ?? computeDay(sub.lat, sub.lon, date, sub.tz, sub.settings), sub.settings.adjust)
      return dayEvents(sub, date, day)
    })
    .filter(e => e.at.getTime() > from && e.at.getTime() <= to)
    .sort((a, b) => a.at.getTime() - b.at.getTime())
}
