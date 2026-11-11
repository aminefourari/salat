import { createFileRoute, Link } from '@tanstack/react-router'
import { tz, useLocation, useMonth, useNow, useSettings } from '../lib/client'
import { t } from '../lib/i18n'
import { dateIn, formatHM, resolveMethod } from '../lib/prayer'

export const Route = createFileRoute('/month')({
  validateSearch: (q: Record<string, unknown>): { m?: string } =>
    typeof q.m === 'string' && /^\d{4}-(0[1-9]|1[0-2])$/.test(q.m) ? { m: q.m } : {},
  component: MonthPage,
})

const COLS = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'] as const

const shiftMonth = (ym: string, by: number) => {
  const [y, m] = ym.split('-').map(Number)
  const d = new Date(Date.UTC(y, m - 1 + by, 1))
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`
}

function MonthPage() {
  const [settings] = useSettings()
  const { lang } = settings
  const { loc } = useLocation()
  const now = useNow(60_000)
  const zone = tz()
  const today = dateIn(now, zone)
  const month = Route.useSearch().m ?? today.slice(0, 7)
  const days = useMonth(loc, settings, month, now)
  if (!days || !loc) return <p className="loading">{t(lang, 'locating')}</p>

  const title = new Date(`${month}-15T12:00:00Z`).toLocaleDateString(lang, { month: 'long', year: 'numeric', timeZone: 'UTC' })
  const official = days.some(d => d.official)
  return (
    <>
      <div className="month-nav">
        <Link to="/month" search={{ m: shiftMonth(month, -1) }} className="btn no-print" aria-label={t(lang, 'prevMonth')}>{lang === 'ar' ? '›' : '‹'}</Link>
        <h1>{t(lang, 'monthly')} · {title}</h1>
        <Link to="/month" search={{ m: shiftMonth(month, 1) }} className="btn no-print" aria-label={t(lang, 'nextMonth')}>{lang === 'ar' ? '‹' : '›'}</Link>
      </div>
      <table className="month-table">
        <thead>
          <tr><th scope="col">{t(lang, 'date')}</th>{COLS.map(k => <th key={k} scope="col">{t(lang, k)}</th>)}</tr>
        </thead>
        <tbody>
          {days.map(({ date, day }) => {
            const d = new Date(`${date}T12:00:00Z`)
            const cls = [date === today && 'is-today', d.getUTCDay() === 5 && 'is-friday'].filter(Boolean).join(' ')
            return (
              <tr key={date} className={cls || undefined} aria-current={date === today ? 'date' : undefined}>
                <td>{d.toLocaleDateString(lang, { weekday: 'short', day: 'numeric', timeZone: 'UTC' })}</td>
                {COLS.map(k => <td key={k}>{formatHM(day[k], zone)}</td>)}
              </tr>
            )
          })}
        </tbody>
      </table>
      {official ? <p className="meta center">{t(lang, 'official')}</p>
        : resolveMethod(loc.lat, loc.lon, settings) === 'morocco' && <p className="meta center">{t(lang, 'approximate')}</p>}
      <p className="center no-print"><button className="btn" onClick={() => print()}>{t(lang, 'print')}</button></p>
    </>
  )
}
