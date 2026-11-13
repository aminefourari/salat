// Official Habous days kept on the device (pure; mirrors apps/macos/Salat/Core/Habous.swift).
import { nextDate } from './prayer'

/** Days for one place (YYYY-MM-DD → six epoch ms: Fajr, sunrise, Dhuhr, Asr, Maghrib, Isha); `none` = no Habous city near. */
export type HabousDays = { place: string; days: Record<string, number[]>; none?: boolean }

/** The month (YYYY-MM) to fetch so that `date` and the day after are official; '' when nothing is missing or asking is pointless. */
export function habousMonthToFetch(saved: HabousDays, place: string, date: string): string {
  if (!place) return ''
  const mine = saved.place === place
  if (mine && saved.none) return ''
  if (!(mine && saved.days[date])) return date.slice(0, 7)
  const tomorrow = nextDate(date)
  return saved.days[tomorrow] ? '' : tomorrow.slice(0, 7)
}

/** Adds a fetched month: the same place keeps its days from `keepFrom` on, another place starts over. */
export function mergeHabous(cur: HabousDays, place: string, fetched: Record<string, number[]>, keepFrom: string): HabousDays {
  const kept = cur.place === place ? Object.fromEntries(Object.entries(cur.days).filter(([d]) => d >= keepFrom)) : {}
  return { place, days: { ...kept, ...fetched } }
}
