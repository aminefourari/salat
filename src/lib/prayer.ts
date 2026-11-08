import { CalculationMethod, CalculationParameters, Coordinates, HighLatitudeRule, Madhab, PrayerTimes, Qibla } from 'adhan'
import { countryAt, methodForCountry, type MethodId } from './methods'

export type Prayer = 'fajr' | 'dhuhr' | 'asr' | 'maghrib' | 'isha'
export const PRAYERS: Prayer[] = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']
export type Lang = 'ar' | 'en' | 'fr'
export type Settings = { method: MethodId | 'auto'; asr: 'standard' | 'hanafi'; lang: Lang }
export type DayTimes = { sunrise: Date } & Record<Prayer, Date>

export function paramsFor(id: MethodId, asr: Settings['asr'], { margins = true } = {}): CalculationParameters {
  let p: CalculationParameters
  switch (id) {
    case 'aachen':
      // Matches Muslim Pro's "Islamic Center Aachen" (Isha −3), plus the center's Diyanet safety margins.
      p = new CalculationParameters('Other', 18, 17)
      p.highLatitudeRule = HighLatitudeRule.TwilightAngle
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
  if (id !== 'aachen' && !p.highLatitudeRule) p.highLatitudeRule = HighLatitudeRule.TwilightAngle
  p.madhab = asr === 'hanafi' ? Madhab.Hanafi : Madhab.Shafi
  return p
}

export const resolveMethod = (lat: number, lon: number, s: Settings): MethodId =>
  s.method === 'auto' ? methodForCountry(countryAt(lat, lon)) : s.method

/** Prayer times for calendar day `date` (YYYY-MM-DD, as seen in `tz`). */
export function computeDay(lat: number, lon: number, date: string, _tz: string, s: Settings, params?: CalculationParameters): DayTimes {
  const [y, m, d] = date.split('-').map(Number)
  // adhan only reads the local Y/M/D of this Date, so build it in local time.
  const pt = new PrayerTimes(new Coordinates(lat, lon), new Date(y, m - 1, d), params ?? paramsFor(resolveMethod(lat, lon, s), s.asr))
  return { fajr: pt.fajr, sunrise: pt.sunrise, dhuhr: pt.dhuhr, asr: pt.asr, maghrib: pt.maghrib, isha: pt.isha }
}

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
