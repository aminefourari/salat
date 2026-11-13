import { METHOD_IDS } from '../lib/methods'
import { LANGS, MAX_ADJUST, PRAYERS } from '../lib/prayer'
import type { Row } from './cron'

/** Every prayer notifies (bitmask over PRAYERS). */
export const ALL_PRAYERS = 31
const isNum = (v: unknown, min: number, max: number): v is number => typeof v === 'number' && Number.isFinite(v) && v >= min && v <= max
const isStr = (v: unknown, max = 2048): v is string => typeof v === 'string' && v.length > 0 && v.length <= max
const PUSH_HOSTS = ['fcm.googleapis.com', 'updates.push.services.mozilla.com']
const PUSH_SUFFIXES = ['.push.apple.com', '.notify.windows.com']
/** A browser push service URL (anything else would let callers make the Worker POST to arbitrary hosts). */
export const isPushEndpoint = (v: unknown): v is string => {
  if (!isStr(v)) return false
  try {
    const u = new URL(v)
    return u.protocol === 'https:' && !u.port && (PUSH_HOSTS.includes(u.hostname) || PUSH_SUFFIXES.some(s => u.hostname.endsWith(s)))
  } catch { return false }
}
/** Byte length of a base64url string (padding optional), or -1 when it isn't one. */
const b64urlBytes = (s: string) => {
  const t = s.replace(/=+$/, '')
  if (!/^[A-Za-z0-9_-]+$/.test(t) || t.length % 4 === 1) return -1
  return Math.floor((t.length * 3) / 4)
}
/** RFC 8291 keys: p256dh is an uncompressed P-256 point (65 bytes), auth a 16-byte secret. */
export const validKeys = (p256dh: unknown, auth: unknown) =>
  isStr(p256dh, 256) && isStr(auth, 256) && b64urlBytes(p256dh) === 65 && b64urlBytes(auth) === 16
const validTz = (tz: unknown) => {
  if (!isStr(tz, 64)) return false
  try { new Intl.DateTimeFormat('en', { timeZone: tz }); return true } catch { return false }
}

/** Validates the POST /api/subscribe body. Returns the row to upsert, or an error message. */
export function parseSubscribe(b: any): Omit<Row, 'last_sent_at' | 'updated_at'> | string {
  if (!b || typeof b !== 'object') return 'body must be an object'
  const sub = b.subscription
  if (!isPushEndpoint(sub?.endpoint)) return 'bad endpoint'
  if (!validKeys(sub.keys?.p256dh, sub.keys?.auth)) return 'bad keys'
  if (!isNum(b.lat, -90, 90) || !isNum(b.lon, -180, 180)) return 'bad coordinates'
  if (!validTz(b.tz)) return 'bad tz'
  const s = b.settings
  if (!(s?.method === 'auto' || METHOD_IDS.includes(s?.method))) return 'bad method'
  if (!['standard', 'hanafi'].includes(s.asr)) return 'bad asr'
  if (!LANGS.includes(s.lang)) return 'bad lang'
  const adjust = s.adjust ?? {}
  if (typeof adjust !== 'object' || Object.entries(adjust).some(([k, v]) => !PRAYERS.includes(k as never) || !Number.isInteger(v) || !isNum(v, -MAX_ADJUST, MAX_ADJUST)))
    return 'bad adjust'
  const prayers = b.notifyPrayers ?? ALL_PRAYERS
  if (!Number.isInteger(prayers) || !isNum(prayers, 0, ALL_PRAYERS)) return 'bad prayers'
  return {
    endpoint: sub.endpoint, p256dh: sub.keys.p256dh, auth: sub.keys.auth, lat: b.lat, lon: b.lon, tz: b.tz,
    method: s.method, asr: s.asr, lang: s.lang, notify_start: b.notifyStart ? 1 : 0, notify_reminder: b.notifyReminder ? 1 : 0,
    notify_adhkar: b.notifyAdhkar ? 1 : 0, notify_friday: b.notifyFriday ? 1 : 0, adjust: JSON.stringify(adjust), notify_prayers: prayers,
  }
}

/** Validates PATCH /api/subscribe: move a row from `oldEndpoint` to a new subscription (the browser rotated it). */
export function parseResubscribe(b: any): { oldEndpoint: string; endpoint: string; p256dh: string; auth: string } | string {
  if (!b || typeof b !== 'object' || !isStr(b.oldEndpoint)) return 'bad old endpoint'
  const sub = b.subscription
  if (!isPushEndpoint(sub?.endpoint)) return 'bad endpoint'
  if (!validKeys(sub.keys?.p256dh, sub.keys?.auth)) return 'bad keys'
  return { oldEndpoint: b.oldEndpoint, endpoint: sub.endpoint, p256dh: sub.keys.p256dh, auth: sub.keys.auth }
}
