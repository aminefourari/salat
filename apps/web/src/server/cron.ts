import { countryAt } from '../lib/country'
import { t } from '../lib/i18n'
import type { MethodId } from '../lib/methods'
import { dateIn, formatHM, nextDate, usesHabous, type Adjust, type DayTimes, type Lang, type Settings } from '../lib/prayer'
import { dueEvents, type DueEvent, type Sub } from '../lib/schedule'
import { ensureMonth, habousDays, type HabousStore } from './habous'

export type Row = {
  endpoint: string; p256dh: string; auth: string; lat: number; lon: number; tz: string
  method: string; asr: string; lang: string; notify_start: number; notify_reminder: number
  notify_adhkar: number; notify_friday: number; adjust: string // JSON Adjust
  notify_prayers: number // bitmask in PRAYERS order
  last_sent_at: number; updated_at: number
}
/** `url`: the page a tap opens (adhkar, Surat al-Kahf). */
export type Payload = { title: string; body: string; tag: string; url?: string }
export type SendResult = 'ok' | 'gone' | 'error'
export type Store = {
  all(): Promise<Row[]>
  markSent(endpoint: string, at: number): Promise<void>
  remove(endpoint: string): Promise<void>
}
/** Optional per-row override of day times (Morocco: official Habous timetable). */
export type DayTimesFor = (row: Row, now: Date) => Promise<((date: string) => DayTimes | null) | undefined>

/** Morocco rows use the official timetable for yesterday..tomorrow (dueEvents' window); calculated otherwise. */
export const habousDayTimes = (store: HabousStore): DayTimesFor => async (row, now) => {
  const sub = toSub(row)
  if (!usesHabous(sub.country, sub.settings)) return undefined
  const today = dateIn(now, sub.tz)
  const yesterday = new Date(Date.parse(`${today}T12:00:00Z`) - 86_400_000).toISOString().slice(0, 10)
  const days = await habousDays(store, sub.lat, sub.lon, [yesterday, today, nextDate(today)])
  return days ? date => days.get(date) ?? null : undefined
}

const parseAdjust = (json: string): Adjust | undefined => { try { return JSON.parse(json) } catch { return undefined } }

export const toSub = (r: Row): Sub => ({
  lat: r.lat, lon: r.lon, tz: r.tz, country: countryAt(r.lat, r.lon),
  settings: { method: r.method as MethodId | 'auto', asr: r.asr as Settings['asr'], lang: r.lang as Lang, adjust: parseAdjust(r.adjust) },
  notifyStart: !!r.notify_start, notifyReminder: !!r.notify_reminder, notifyAdhkar: !!r.notify_adhkar, notifyFriday: !!r.notify_friday, notifyPrayers: r.notify_prayers,
  lastSentAt: r.last_sent_at,
})

/** Morning and evening adhkar are one chapter of Hisn al-Muslim (data/adhkar.json). */
export const ADHKAR_CHAPTER = 27
const KAHF = 18

export function payloadFor(e: DueEvent, lang: Lang, tz: string): Payload {
  const vars = { prayer: t(lang, e.prayer), time: formatHM(e.prayerTime, tz) }
  const tag = `${e.prayer}-${e.kind}`
  switch (e.kind) {
    case 'start': return { title: 'Salat', body: t(lang, 'notif.start', vars), tag }
    case 'reminder': return { title: 'Salat', body: t(lang, 'notif.reminder', vars), tag }
    case 'adhkarMorning': return { title: 'Salat', body: t(lang, 'notif.adhkarMorning'), tag, url: `/adhkar?c=${ADHKAR_CHAPTER}` }
    case 'adhkarEvening': return { title: 'Salat', body: t(lang, 'notif.adhkarEvening'), tag, url: `/adhkar?c=${ADHKAR_CHAPTER}` }
    case 'kahf': return { title: 'Salat', body: t(lang, 'notif.kahf'), tag, url: `/quran?s=${KAHF}` }
    case 'jumuah': return { title: 'Salat', body: t(lang, 'notif.jumuah', vars), tag }
  }
}

/** From the 25th, imports next month's Habous timetable so a late or failing habous.gov.ma shows up days ahead
 *  (ensureMonth logs failures and retries every 10 min) instead of at midnight on the 1st. */
export async function prefetchHabous(store: HabousStore, now: Date) {
  const today = dateIn(now, 'Africa/Casablanca')
  if (Number(today.slice(8)) < 25) return
  const [y, m] = today.split('-').map(Number)
  await ensureMonth(store, m === 12 ? `${y + 1}-01` : `${y}-${String(m + 1).padStart(2, '0')}`)
}

// ponytail: scans every row each minute; fine for a handful of devices, add a next_due_at column if it grows.
export async function runCron(store: Store, now: Date, send: (r: Row, p: Payload) => Promise<SendResult>, dayTimesFor?: DayTimesFor) {
  for (const row of await store.all()) {
    try {
      const sub = toSub(row)
      const events = dueEvents(sub, now, await dayTimesFor?.(row, now))
      if (!events.length) continue
      // Events are sorted by time. On the first transient error stop, and move last_sent_at to just before that
      // event: the next minute retries it and what follows (within the 5-min window), never what was delivered.
      let failedAt: number | null = null
      for (const e of events) {
        const res = await send(row, payloadFor(e, sub.settings.lang, row.tz))
        if (res === 'gone') { await store.remove(row.endpoint); failedAt = -1; break }
        if (res === 'error') { failedAt = e.at.getTime(); break }
      }
      if (failedAt === null) await store.markSent(row.endpoint, now.getTime())
      else if (failedAt > 0 && failedAt - 1 > row.last_sent_at) await store.markSent(row.endpoint, failedAt - 1)
    } catch (err) {
      console.error('cron row failed', row.endpoint.slice(0, 60), err)
    }
  }
}

export const d1Store = (db: D1Database): Store => ({
  all: async () => (await db.prepare('SELECT * FROM subscriptions').all<Row>()).results,
  markSent: async (e, at) => { await db.prepare('UPDATE subscriptions SET last_sent_at = ? WHERE endpoint = ?').bind(at, e).run() },
  remove: async e => { await db.prepare('DELETE FROM subscriptions WHERE endpoint = ?').bind(e).run() },
})
