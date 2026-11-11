import { METHOD_IDS } from '../lib/methods'
import { MAX_ADJUST, PRAYERS } from '../lib/prayer'
import type { Row } from './cron'

const isNum = (v: unknown, min: number, max: number): v is number => typeof v === 'number' && Number.isFinite(v) && v >= min && v <= max
const isStr = (v: unknown, max = 2048): v is string => typeof v === 'string' && v.length > 0 && v.length <= max
const validTz = (tz: unknown) => {
  if (!isStr(tz, 64)) return false
  try { new Intl.DateTimeFormat('en', { timeZone: tz }); return true } catch { return false }
}

/** Validates the POST /api/subscribe body. Returns the row to upsert, or an error message. */
export function parseSubscribe(b: any): Omit<Row, 'last_sent_at' | 'updated_at'> | string {
  if (!b || typeof b !== 'object') return 'body must be an object'
  const sub = b.subscription
  if (!isStr(sub?.endpoint) || !sub.endpoint.startsWith('https://')) return 'bad endpoint'
  if (!isStr(sub.keys?.p256dh, 256) || !isStr(sub.keys?.auth, 256)) return 'bad keys'
  if (!isNum(b.lat, -90, 90) || !isNum(b.lon, -180, 180)) return 'bad coordinates'
  if (!validTz(b.tz)) return 'bad tz'
  const s = b.settings
  if (!(s?.method === 'auto' || METHOD_IDS.includes(s?.method))) return 'bad method'
  if (!['standard', 'hanafi'].includes(s.asr)) return 'bad asr'
  if (!['ar', 'en', 'fr'].includes(s.lang)) return 'bad lang'
  const adjust = s.adjust ?? {}
  if (typeof adjust !== 'object' || Object.entries(adjust).some(([k, v]) => !PRAYERS.includes(k as never) || !Number.isInteger(v) || !isNum(v, -MAX_ADJUST, MAX_ADJUST)))
    return 'bad adjust'
  return {
    endpoint: sub.endpoint, p256dh: sub.keys.p256dh, auth: sub.keys.auth, lat: b.lat, lon: b.lon, tz: b.tz,
    method: s.method, asr: s.asr, lang: s.lang, notify_start: b.notifyStart ? 1 : 0, notify_reminder: b.notifyReminder ? 1 : 0,
    notify_adhkar: b.notifyAdhkar ? 1 : 0, notify_friday: b.notifyFriday ? 1 : 0, adjust: JSON.stringify(adjust),
  }
}
