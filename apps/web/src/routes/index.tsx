import { createFileRoute, Link } from '@tanstack/react-router'
import { Arch } from '../components/Arch'
import { useEffect } from 'react'
import { PRAYER_ICONS } from '../components/icons'
import { tz, useDays, useLocation, useNow, useSettings, type Loc } from '../lib/client'
import { t } from '../lib/i18n'
import { formatHM, hijriDate, hijriOffset, imsak, nextPrayer, PRAYERS, resolveMethod, skyAt, type DayTimes, type Lang, type Prayer } from '../lib/prayer'

export const Route = createFileRoute('/')({ component: Home })

const ROWS: (Prayer | 'sunrise')[] = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha']
const DAY = 86_400_000

const countdown = (ms: number) => {
  const s = Math.max(0, Math.floor(ms / 1000))
  return `${Math.floor(s / 3600)}:${String(Math.floor(s / 60) % 60).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`
}

/** Fraction of the wait elapsed between the previous prayer and the next one. */
function progress(today: DayTimes, nextAt: Date, now: Date) {
  const past = PRAYERS.filter(p => today[p] <= now)
  const prev = past.length ? today[past[past.length - 1]].getTime() : today.isha.getTime() - DAY
  return Math.min(1, Math.max(0, (now.getTime() - prev) / (nextAt.getTime() - prev)))
}

/** Ramadan line: the next of imsak (end of suhoor) or iftar (Maghrib), with its countdown. */
function ramadanLine(today: DayTimes, tomorrow: DayTimes, now: Date, lang: Lang, zone: string) {
  const [key, at] = now < imsak(today) ? ['imsak', imsak(today)] as const
    : now < today.maghrib ? ['iftar', today.maghrib] as const : ['imsak', imsak(tomorrow)] as const
  return `${t(lang, 'ramadan')} · ${t(lang, key)} ${formatHM(at, zone)} · ${t(lang, 'inTime', { time: countdown(at.getTime() - now.getTime()) })}`
}

const CalendarIcon = () => (
  <svg viewBox="0 0 24 24" width="1em" height="1em" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" aria-hidden="true">
    <rect x="3.5" y="5" width="17" height="15" rx="2.5" /><path d="M3.5 10h17M8 3v4M16 3v4" />
  </svg>
)

const placeLabel = (loc: Loc, lang: Lang) =>
  t(lang, 'lastLocation', {
    place: loc.city ?? `${loc.lat.toFixed(2)}, ${loc.lon.toFixed(2)}`,
    when: new Date(loc.at).toLocaleString(lang, { dateStyle: 'medium', timeStyle: 'short' }),
  })

function Home() {
  const [settings] = useSettings()
  const { lang } = settings
  const { loc, status, retry } = useLocation()
  const now = useNow()
  const days = useDays(loc, settings, now)

  const sky = days ? skyAt(days.today, now) : 'night'
  useEffect(() => { document.documentElement.dataset.sky = sky }, [sky])

  if (!days || !loc) {
    return status === 'denied'
      ? <div className="panel" role="alert"><p>{t(lang, 'locationDenied')}</p><button className="btn" onClick={retry}>{t(lang, 'retry')}</button></div>
      : <p className="loading" aria-live="polite">{t(lang, 'locating')}</p>
  }

  const zone = tz()
  const next = nextPrayer(days.today, days.tomorrow, now)
  const greg = now.toLocaleDateString(lang, { weekday: 'long', day: 'numeric', month: 'long' })
  // Ramadan starts at the Maghrib before its first day: count from tonight once Maghrib has passed.
  const offset = hijriOffset(loc.country, settings)
  const hijri = hijriDate(now, offset, lang)
  const tonight = now >= days.today.maghrib ? hijriDate(new Date(now.getTime() + DAY), offset, lang) : hijri
  const pct = progress(days.today, next.at, now)

  return (
    <>
      <p className="dates">
        <span>{greg} <Link to="/month" className="month-link" aria-label={t(lang, 'monthly')} title={t(lang, 'monthly')}><CalendarIcon /></Link></span>
        {hijri && <span className="hijri">{hijri.label}</span>}
        {tonight?.month === 9 && <span className="ramadan">{ramadanLine(days.today, days.tomorrow, now, lang, zone)}</span>}
      </p>

      <div className="today">
      <section className="hero" aria-live="polite">
        <Arch />
        <div className="hero-body">
          <p className="hero-label">{t(lang, 'next')}</p>
          <p className="hero-name">{t(lang, next.prayer)}</p>
          {lang !== 'ar' && <p className="hero-name-ar" lang="ar">{t('ar', next.prayer)}</p>}
          <p className="hero-time">{formatHM(next.at, zone)}</p>
          <p className="hero-countdown">{t(lang, 'inTime', { time: countdown(next.at.getTime() - now.getTime()) })}</p>
          <div className="hero-progress" role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(pct * 100)}>
            <span style={{ width: `${pct * 100}%` }} />
          </div>
        </div>
      </section>

      <ul className="times" aria-label={t(lang, 'today')}>
        {ROWS.map(k => {
          const at = days.today[k]
          const Icon = PRAYER_ICONS[k]
          const isNext = k === next.prayer && next.at === at
          const cls = ['row', k === 'sunrise' && 'is-minor', isNext && 'is-next', !isNext && at < now && 'is-past'].filter(Boolean).join(' ')
          return (
            <li key={k} className={cls}>
              <Icon className="row-icon" />
              <span className="row-name">{t(lang, k)}</span>
              {lang !== 'ar' && <span className="row-ar" lang="ar">{t('ar', k)}</span>}
              <span className="row-time">{formatHM(at, zone)}</span>
            </li>
          )
        })}
      </ul>
      </div>
      {status === 'denied' && <p className="meta" role="status">{t(lang, 'locationDenied')} <button className="btn" onClick={retry}>{t(lang, 'retry')}</button></p>}
      {days.official ? <p className="meta center">{t(lang, 'official')}</p>
        : resolveMethod(loc.country, settings) === 'morocco' && <p className="meta center">{t(lang, 'approximate')}</p>}
      <p className="meta center">{placeLabel(loc, lang)}</p>
    </>
  )
}
