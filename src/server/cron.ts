import { t } from '../lib/i18n'
import type { MethodId } from '../lib/methods'
import { formatHM, type DayTimes, type Lang, type Settings } from '../lib/prayer'
import { dueEvents, type Sub } from '../lib/schedule'

export type Row = {
  endpoint: string; p256dh: string; auth: string; lat: number; lon: number; tz: string
  method: string; asr: string; lang: string; notify_start: number; notify_reminder: number
  last_sent_at: number; updated_at: number
}
export type Payload = { title: string; body: string; tag: string }
export type SendResult = 'ok' | 'gone' | 'error'
export type Store = {
  all(): Promise<Row[]>
  markSent(endpoint: string, at: number): Promise<void>
  remove(endpoint: string): Promise<void>
}
/** Optional per-row override of day times (Morocco: official Habous timetable). */
export type DayTimesFor = (row: Row) => Promise<((date: string) => DayTimes | null) | undefined>

export const toSub = (r: Row): Sub => ({
  lat: r.lat, lon: r.lon, tz: r.tz,
  settings: { method: r.method as MethodId | 'auto', asr: r.asr as Settings['asr'], lang: r.lang as Lang },
  notifyStart: !!r.notify_start, notifyReminder: !!r.notify_reminder, lastSentAt: r.last_sent_at,
})

// ponytail: scans every row each minute; fine for a handful of devices, add a next_due_at column if it grows.
export async function runCron(store: Store, now: Date, send: (r: Row, p: Payload) => Promise<SendResult>, dayTimesFor?: DayTimesFor) {
  for (const row of await store.all()) {
    try {
      const sub = toSub(row)
      const events = dueEvents(sub, now, await dayTimesFor?.(row))
      if (!events.length) continue
      let ok = true
      for (const e of events) {
        const lang = sub.settings.lang
        const vars = { prayer: t(lang, e.prayer), time: formatHM(e.prayerTime, row.tz) }
        const res = await send(row, { title: 'Salat', body: t(lang, e.kind === 'start' ? 'notif.start' : 'notif.reminder', vars), tag: `${e.prayer}-${e.kind}` })
        if (res === 'gone') { await store.remove(row.endpoint); ok = false; break }
        if (res === 'error') ok = false
      }
      // On a transient error leave last_sent_at alone so the next minute retries (within the 5-min window).
      if (ok) await store.markSent(row.endpoint, now.getTime())
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
