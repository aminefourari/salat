import { CalculationMethod, CalculationParameters, Coordinates, HighLatitudeRule, Madhab, PrayerTimes, Qibla } from 'adhan'
import { methodForCountry, type MethodId } from './methods'

export type Prayer = 'fajr' | 'dhuhr' | 'asr' | 'maghrib' | 'isha'
export const PRAYERS: Prayer[] = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']
export type Lang = 'ar' | 'en' | 'fr' | 'de' | 'nl' | 'es' | 'pt' | 'it'
export const LANGS: Lang[] = ['ar', 'en', 'fr', 'de', 'nl', 'es', 'pt', 'it']
export type Adjust = Partial<Record<Prayer, number>>
/** Per-prayer offsets are limited to ±30 min. */
export const MAX_ADJUST = 30
/** `adjust`: minutes added to each prayer (local mosque offsets). `hijri`: days added to the Hijri date (unset = auto). */
export type Settings = { method: MethodId | 'auto'; asr: 'standard' | 'hanafi'; lang: Lang; adjust?: Adjust; hijri?: number }
/** Settings with the method resolved ('auto' → the country's method), as `computeDay` needs them. */
export type Resolved = Omit<Settings, 'method'> & { method: MethodId }
export type DayTimes = { sunrise: Date } & Record<Prayer, Date>

export function paramsFor(id: MethodId, asr: Settings['asr'], { margins = true } = {}): CalculationParameters {
  let p: CalculationParameters
  switch (id) {
    case 'aachen':
      // Matches Muslim Pro's "Islamic Center Aachen" (Isha −3), plus the center's Diyanet safety margins.
      p = new CalculationParameters('Other', 18, 17)
      p.adjustments.isha = -3
      if (margins) Object.assign(p.adjustments, { sunrise: -7, dhuhr: 5, asr: 4, maghrib: 7 })
      break
    case 'morocco': p = new CalculationParameters('Other', 19, 17); break // fallback when Habous data is missing
    case 'uoif': p = new CalculationParameters('Other', 12, 12); break
    case 'mwl': p = CalculationMethod.MuslimWorldLeague(); break
    case 'ummalqura': p = CalculationMethod.UmmAlQura(); break
    case 'isna': p = CalculationMethod.NorthAmerica(); break
    case 'egyptian': p = CalculationMethod.Egyptian(); break
    case 'karachi': p = CalculationMethod.Karachi(); break
    case 'dubai': p = CalculationMethod.Dubai(); break
    case 'kuwait': p = CalculationMethod.Kuwait(); break
    case 'qatar': p = CalculationMethod.Qatar(); break
    case 'singapore': p = CalculationMethod.Singapore(); break
    case 'turkey': p = CalculationMethod.Turkey(); break
    case 'tehran': p = CalculationMethod.Tehran(); break
  }
  // adhan defaults to MiddleOfTheNight, which puts summer Isha after midnight up north; Muslim Pro uses angle-based.
  p.highLatitudeRule = HighLatitudeRule.TwilightAngle
  p.madhab = asr === 'hanafi' ? Madhab.Hanafi : Madhab.Shafi
  return p
}

/** `country`: ISO code of the place (`Loc.country` in the browser, `countryAt` on the Worker). */
export const resolveMethod = (country: string | null, s: Settings): MethodId =>
  s.method === 'auto' ? methodForCountry(country) : s.method

export const resolved = (country: string | null, s: Settings): Resolved => ({ ...s, method: resolveMethod(country, s) })

/** Morocco with the standard Asr: the official Habous timetable applies (when a listed city is near). */
export const usesHabous = (country: string | null, s: Settings) => resolveMethod(country, s) === 'morocco' && s.asr === 'standard'

/** Prayer times for calendar day `date` (YYYY-MM-DD, as seen in `tz`). */
export function computeDay(lat: number, lon: number, date: string, _tz: string, s: Resolved, params?: CalculationParameters): DayTimes {
  const [y, m, d] = date.split('-').map(Number)
  // adhan only reads the local Y/M/D of this Date, so build it in local time.
  const pt = new PrayerTimes(new Coordinates(lat, lon), new Date(y, m - 1, d), params ?? paramsFor(s.method, s.asr))
  return { fajr: pt.fajr, sunrise: pt.sunrise, dhuhr: pt.dhuhr, asr: pt.asr, maghrib: pt.maghrib, isha: pt.isha }
}

/** `day` with the user's per-prayer minute offsets applied (on top of the calculation or the Habous timetable). */
export function adjustDay(day: DayTimes, adjust: Adjust | undefined): DayTimes {
  if (!adjust) return day
  const out = { ...day }
  for (const p of PRAYERS) if (adjust[p]) out[p] = new Date(day[p].getTime() + adjust[p]! * 60_000)
  return out
}

/** Days to add to the Umm al-Qura date: the user's choice, else −1 in Morocco (sighting usually a day after Makkah). */
export const hijriOffset = (country: string | null, s: Settings) => s.hijri ?? (resolveMethod(country, s) === 'morocco' ? -1 : 0)

/** Hijri date of `d` shifted by `offset` days: its month number (9 = Ramadan) and a long label in `lang`. */
export function hijriDate(d: Date, offset: number, lang: Lang): { month: number; label: string } | null {
  const at = new Date(d.getTime() + offset * 86_400_000)
  try {
    const month = Number(new Intl.DateTimeFormat('en-u-ca-islamic-umalqura-nu-latn', { month: 'numeric' }).formatToParts(at).find(p => p.type === 'month')?.value)
    const label = new Intl.DateTimeFormat(`${lang}-u-ca-islamic-umalqura`, { day: 'numeric', month: 'long', year: 'numeric' }).format(at)
    return { month, label }
  } catch { return null }
}

/** Imsak: the customary 10 minutes before Fajr, when suhoor stops. */
export const imsak = (day: DayTimes) => new Date(day.fajr.getTime() - 10 * 60_000)

export const formatHM = (d: Date, tz: string) =>
  d.toLocaleTimeString('en-GB', { timeZone: tz, hour: '2-digit', minute: '2-digit', hourCycle: 'h23' })

/** Calendar date (YYYY-MM-DD) of instant `d` in `tz`. */
export const dateIn = (d: Date, tz: string) => d.toLocaleDateString('en-CA', { timeZone: tz })

export const qibla = (lat: number, lon: number) => Qibla(new Coordinates(lat, lon))

export type Sky = 'night' | 'dawn' | 'day' | 'afternoon' | 'dusk'
export function skyAt(d: DayTimes, now: Date): Sky {
  const n = now.getTime()
  if (n < d.fajr.getTime() || n >= d.isha.getTime()) return 'night'
  if (n < d.sunrise.getTime()) return 'dawn'
  if (n < d.asr.getTime()) return 'day'
  if (n < d.maghrib.getTime()) return 'afternoon'
  return 'dusk'
}

/** The next prayer after `now`: today's if any remain, else tomorrow's Fajr. */
export function nextPrayer(today: DayTimes, tomorrow: DayTimes, now: Date): { prayer: Prayer; at: Date } {
  const p = PRAYERS.find(k => today[k].getTime() > now.getTime())
  return p ? { prayer: p, at: today[p] } : { prayer: 'fajr', at: tomorrow.fajr }
}

export const nextDate = (date: string) => new Date(Date.parse(`${date}T12:00:00Z`) + 86_400_000).toISOString().slice(0, 10)

const KAABA = { lat: 21.4225, lon: 39.8262 }
/** Great-circle distance to the Kaaba in km. */
export function kaabaDistanceKm(lat: number, lon: number) {
  const r = Math.PI / 180, dLat = (KAABA.lat - lat) * r, dLon = (KAABA.lon - lon) * r
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat * r) * Math.cos(KAABA.lat * r) * Math.sin(dLon / 2) ** 2
  return 12742 * Math.asin(Math.sqrt(h))
}
/** Signed shortest turn (degrees, −180..180) from `heading` to `bearing`; positive = turn right. */
export const turnDelta = (bearing: number, heading: number) => {
  const d = (((bearing - heading) % 360) + 540) % 360 - 180
  return d === 180 ? -180 : d
}
/** 0..7 index into N, NE, E, SE, S, SW, W, NW. */
export const compass8 = (deg: number) => Math.round((((deg % 360) + 360) % 360) / 45) % 8
