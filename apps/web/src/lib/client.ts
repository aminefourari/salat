// Browser-only helpers and hooks: persisted settings, location, push subscription.
import { useCallback, useEffect, useMemo, useState, useSyncExternalStore } from 'react'
import { detectLang } from './i18n'
import { countryAt } from './methods'
import { computeDay, dateIn, nextDate, type DayTimes, type Settings } from './prayer'

export type Loc = { lat: number; lon: number; at: number; country: string | null; city?: string | null }
export type Notify = { start: boolean; reminder: boolean }

const KEYS = { settings: 'salat.settings', loc: 'salat.loc', notify: 'salat.notify' } as const
const listeners = new Set<() => void>()
const cache = new Map<string, unknown>()

function read<T>(key: string, fallback: T): T {
  if (cache.has(key)) return cache.get(key) as T
  let v = fallback
  try { const raw = localStorage.getItem(key); if (raw) v = { ...fallback, ...JSON.parse(raw) } } catch {}
  cache.set(key, v)
  return v
}
function write<T>(key: string, v: T) {
  cache.set(key, v)
  try { localStorage.setItem(key, JSON.stringify(v)) } catch {}
  listeners.forEach(l => l())
}
const subscribe = (l: () => void) => { listeners.add(l); return () => listeners.delete(l) }

function useStored<T>(key: string, fallback: T, serverValue: T): [T, (v: T) => void] {
  const v = useSyncExternalStore(subscribe, () => read(key, fallback), () => serverValue)
  return [v, useCallback((nv: T) => write(key, nv), [key])]
}

const DEFAULT_SETTINGS: Settings = { method: 'auto', asr: 'standard', lang: 'en' }
const defaultSettings = (): Settings =>
  typeof navigator === 'undefined' ? DEFAULT_SETTINGS : { ...DEFAULT_SETTINGS, lang: detectLang(navigator.language) }
let initialSettings: Settings | undefined
export const useSettings = () => useStored<Settings>(KEYS.settings, (initialSettings ??= defaultSettings()), DEFAULT_SETTINGS)
const NO_NOTIFY: Notify = { start: true, reminder: true }
export const useNotify = () => useStored<Notify>(KEYS.notify, NO_NOTIFY, NO_NOTIFY)

const NO_LOC = null as Loc | null
export function useLoc() {
  const loc = useSyncExternalStore(subscribe, () => read<Loc | null>(KEYS.loc, NO_LOC), () => NO_LOC)
  return loc && typeof loc.lat === 'number' ? loc : null
}

export const tz = () => Intl.DateTimeFormat().resolvedOptions().timeZone

const km = (a: Loc, b: { lat: number; lon: number }) => {
  const r = Math.PI / 180, dLat = (b.lat - a.lat) * r, dLon = (b.lon - a.lon) * r
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * r) * Math.cos(b.lat * r) * Math.sin(dLon / 2) ** 2
  return 12742 * Math.asin(Math.sqrt(h))
}

export type LocStatus = 'locating' | 'ok' | 'denied'
/** Requests the position on mount; saves it (and re-syncs push) when it moved more than 5 km. */
export function useLocation() {
  const loc = useLoc()
  const [status, setStatus] = useState<LocStatus>('locating')
  const locate = useCallback(() => {
    if (!('geolocation' in navigator)) return setStatus('denied')
    setStatus('locating')
    navigator.geolocation.getCurrentPosition(
      ({ coords }) => {
        const prev = read<Loc | null>(KEYS.loc, null)
        const next = { lat: coords.latitude, lon: coords.longitude }
        if (!prev || km(prev, next) > 5) {
          write<Loc>(KEYS.loc, { ...next, at: Date.now(), country: countryAt(next.lat, next.lon) })
          syncPush().catch(() => {})
        }
        resolveCity()
        setStatus('ok')
      },
      () => setStatus('denied'),
      { enableHighAccuracy: false, maximumAge: 10 * 60_000, timeout: 20_000 },
    )
  }, [])
  useEffect(locate, [locate])
  return { loc, status, retry: locate }
}

/** Looks up the town for the saved location once (on our Worker) and stores it; offline it retries next open. */
async function resolveCity() {
  const loc = read<Loc | null>(KEYS.loc, null)
  if (!loc || loc.city !== undefined) return
  try {
    const res = await fetch(`/api/place?lat=${loc.lat.toFixed(3)}&lon=${loc.lon.toFixed(3)}`)
    if (!res.ok) return
    const { city } = (await res.json()) as { city: { name: string } | null }
    const cur = read<Loc | null>(KEYS.loc, null)
    if (cur && cur.lat === loc.lat && cur.lon === loc.lon) write<Loc>(KEYS.loc, { ...cur, city: city?.name ?? null })
  } catch {}
}

export function useNow(ms = 1000) {
  const [now, setNow] = useState(() => new Date())
  useEffect(() => { const id = setInterval(() => setNow(new Date()), ms); return () => clearInterval(id) }, [ms])
  return now
}

// ---- push ----

export const isIos = () => /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
export const isStandalone = () => matchMedia('(display-mode: standalone)').matches || (navigator as any).standalone === true
export const pushSupported = () => 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window

const b64ToBytes = (b64: string) => {
  const s = atob((b64 + '='.repeat((4 - (b64.length % 4)) % 4)).replace(/-/g, '+').replace(/_/g, '/'))
  return Uint8Array.from(s, c => c.charCodeAt(0))
}

async function post(sub: PushSubscription) {
  const loc = read<Loc | null>(KEYS.loc, null)
  if (!loc) throw new Error('no location yet')
  const notify = read(KEYS.notify, NO_NOTIFY)
  const res = await fetch('/api/subscribe', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      subscription: sub.toJSON(), lat: loc.lat, lon: loc.lon, tz: tz(),
      settings: read(KEYS.settings, defaultSettings()), notifyStart: notify.start, notifyReminder: notify.reminder,
    }),
  })
  if (!res.ok) throw new Error(`subscribe failed: ${res.status}`)
}

export async function currentPushSub() {
  if (!pushSupported()) return null
  const reg = await navigator.serviceWorker.ready
  return reg.pushManager.getSubscription()
}

export async function enablePush(vapidPublicKey: string) {
  if ((await Notification.requestPermission()) !== 'granted') throw new Error('denied')
  const reg = await navigator.serviceWorker.ready
  const sub = (await reg.pushManager.getSubscription()) ??
    (await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: b64ToBytes(vapidPublicKey) }))
  await post(sub)
}

export async function disablePush() {
  const sub = await currentPushSub()
  if (!sub) return
  await fetch('/api/subscribe', { method: 'DELETE', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ endpoint: sub.endpoint }) })
  await sub.unsubscribe()
}

/** Re-sends location/settings for this device's subscription, if it has one. */
export async function syncPush() {
  const sub = await currentPushSub()
  if (sub) await post(sub)
}

export function setSettings(s: Settings) { write(KEYS.settings, s); syncPush().catch(() => {}) }
export function setNotify(n: Notify) { write(KEYS.notify, n); syncPush().catch(() => {}) }

// ---- day times ----


/** Today's and tomorrow's times for the saved location, in this device's time zone. */
export function useDays(loc: Loc | null, s: Settings, now: Date): { today: DayTimes; tomorrow: DayTimes; date: string } | null {
  const zone = tz()
  const date = dateIn(now, zone)
  return useMemo(() => {
    if (!loc) return null
    return { today: computeDay(loc.lat, loc.lon, date, zone, s), tomorrow: computeDay(loc.lat, loc.lon, nextDate(date), zone, s), date }
  }, [loc, s, date, zone])
}

export async function testPush() {
  const sub = await currentPushSub()
  if (!sub) throw new Error('not subscribed')
  const res = await fetch('/api/test-push', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ endpoint: sub.endpoint }) })
  if (!res.ok) throw new Error(`test failed: ${res.status}`)
}

/** Quran and adhkar reading state, per device. */
export type ReadPrefs = { reciter: number; surah: number; ayah: number; adhkar: number }
const DEFAULT_READ: ReadPrefs = { reciter: 7, surah: 1, ayah: 1, adhkar: 27 }
export const useReadPrefs = () => useStored<ReadPrefs>('salat.read', DEFAULT_READ, DEFAULT_READ)

/** Runs a memoised `load()` (see lib/load.ts); `failed` + `retry` for when it couldn't (offline). */
export function useLazy<T>(load: () => Promise<T>): { data: T | null; failed: boolean; retry: () => void } {
  const [data, setData] = useState<T | null>(null)
  const [failed, setFailed] = useState(false)
  const run = useCallback(() => { setFailed(false); load().then(setData, () => setFailed(true)) }, [load])
  useEffect(run, [run])
  return { data, failed, retry: run }
}
