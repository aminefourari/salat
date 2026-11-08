import { createFileRoute } from '@tanstack/react-router'
import { useEffect } from 'react'
import { tz, useDays, useLocation, useNow, useSettings, type Loc } from '../lib/client'
import { t } from '../lib/i18n'
import { formatHM, nextPrayer, skyAt, type Lang, type Prayer } from '../lib/prayer'

export const Route = createFileRoute('/')({ component: Home })

const ROWS: (Prayer | 'sunrise')[] = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha']

const countdown = (ms: number) => {
  const s = Math.max(0, Math.floor(ms / 1000))
  return `${Math.floor(s / 3600)}:${String(Math.floor(s / 60) % 60).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`
}

export function placeLabel(loc: Loc, lang: Lang) {
  let country = loc.country ?? ''
  try { if (loc.country) country = new Intl.DisplayNames([lang], { type: 'region' }).of(loc.country) ?? country } catch {}
  const coords = `${loc.lat.toFixed(2)}, ${loc.lon.toFixed(2)}`
  const when = new Date(loc.at).toLocaleString(lang, { dateStyle: 'medium', timeStyle: 'short' })
  return t(lang, 'lastLocation', { place: country ? `${country} (${coords})` : coords, when })
}

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
      ? <div className="notice" role="alert"><p>{t(lang, 'locationDenied')}</p><button className="btn" onClick={retry}>{t(lang, 'retry')}</button></div>
      : <p className="next-label next" aria-live="polite">{t(lang, 'locating')}</p>
  }

  const zone = tz()
  const next = nextPrayer(days.today, days.tomorrow, now)
  return (
    <>
      <section className="next" aria-live="polite">
        <p className="next-label">{t(lang, 'next')}</p>
        <p className="next-name">{t(lang, next.prayer)}</p>
        {lang !== 'ar' && <p className="next-name-ar" lang="ar">{t('ar', next.prayer)}</p>}
        <p className="next-when"><strong>{formatHM(next.at, zone)}</strong> · {t(lang, 'inTime', { time: countdown(next.at.getTime() - now.getTime()) })}</p>
      </section>

      <ul className="times" aria-label={t(lang, 'today')}>
        {ROWS.map(k => {
          const at = days.today[k]
          const cls = [k === 'sunrise' ? 'minor' : '', k === next.prayer && next.at === at ? 'is-next' : '', at < now && k !== next.prayer ? 'is-past' : '']
          return (
            <li key={k} className={cls.filter(Boolean).join(' ')}>
              <span>{t(lang, k)}</span>
              <span className="t">{formatHM(at, zone)}</span>
            </li>
          )
        })}
      </ul>
      {status === 'denied' && <p className="meta" role="status">{t(lang, 'locationDenied')} <button className="btn" onClick={retry}>{t(lang, 'retry')}</button></p>}
      <p className="meta">{placeLabel(loc, lang)}</p>
    </>
  )
}
