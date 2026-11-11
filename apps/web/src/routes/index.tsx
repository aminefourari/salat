import { createFileRoute } from '@tanstack/react-router'
import { useEffect } from 'react'
import { PRAYER_ICONS } from '../components/icons'
import { tz, useDays, useLocation, useNow, useSettings, type Loc } from '../lib/client'
import { t } from '../lib/i18n'
import { formatHM, nextPrayer, PRAYERS, resolveMethod, skyAt, type DayTimes, type Lang, type Prayer } from '../lib/prayer'

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

function dates(now: Date, lang: Lang) {
  const greg = now.toLocaleDateString(lang, { weekday: 'long', day: 'numeric', month: 'long' })
  let hijri = ''
  try { hijri = new Intl.DateTimeFormat(`${lang}-u-ca-islamic-umalqura`, { day: 'numeric', month: 'long', year: 'numeric' }).format(now) } catch {}
  return { greg, hijri }
}

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
  const { greg, hijri } = dates(now, lang)
  const pct = progress(days.today, next.at, now)

  return (
    <>
      <p className="dates"><span>{greg}</span>{hijri && <span className="hijri">{hijri}</span>}</p>

      <section className="hero" aria-live="polite">
        <svg className="arch" viewBox="0 0 200 260" preserveAspectRatio="none" aria-hidden="true">
          <path className="arch-fill" d="M4 260V112C4 58 52 26 100 4c48 22 96 54 96 108v148Z" />
          <path className="arch-line" d="M4 260V112C4 58 52 26 100 4c48 22 96 54 96 108v148Z" />
          <path className="arch-inner" d="M14 260V116C14 68 56 38 100 18c44 20 86 50 86 98v144" />
        </svg>
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
      {status === 'denied' && <p className="meta" role="status">{t(lang, 'locationDenied')} <button className="btn" onClick={retry}>{t(lang, 'retry')}</button></p>}
      {days.official ? <p className="meta center">{t(lang, 'official')}</p>
        : resolveMethod(loc.lat, loc.lon, settings) === 'morocco' && <p className="meta center">{t(lang, 'approximate')}</p>}
      <p className="meta center">{placeLabel(loc, lang)}</p>
    </>
  )
}
