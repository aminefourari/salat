import { HeadContent, Link, Scripts, createRootRoute } from '@tanstack/react-router'
import { useEffect } from 'react'
import appCss from '../styles.css?url'
import { syncPush, useLoc, useNewVersion, useSettings } from '../lib/client'
import { Mark, NavAdhkar, NavQibla, NavQuran, NavSettings, NavTimes } from '../components/icons'
import { t } from '../lib/i18n'

export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1, viewport-fit=cover' },
      { name: 'theme-color', content: '#0b5d3b' },
      { name: 'apple-mobile-web-app-capable', content: 'yes' },
      { name: 'apple-mobile-web-app-status-bar-style', content: 'black-translucent' },
      { name: 'apple-mobile-web-app-title', content: 'Salat' },
      { name: 'description', content: 'Prayer times, reminders, Qibla, Quran and adhkar.' },
      { title: 'Salat' },
    ],
    links: [
      { rel: 'stylesheet', href: appCss },
      { rel: 'manifest', href: '/manifest.webmanifest' },
      { rel: 'icon', href: '/icon-192.png', type: 'image/png' },
      { rel: 'apple-touch-icon', href: '/apple-touch-icon.png' },
    ],
  }),
  shellComponent: RootDocument,
})

function RootDocument({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <HeadContent />
      </head>
      <body>
        <Shell>{children}</Shell>
        <Scripts />
      </body>
    </html>
  )
}

function Shell({ children }: { children: React.ReactNode }) {
  const [{ lang }] = useSettings()
  useEffect(() => {
    document.documentElement.lang = lang
    document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr'
  }, [lang])
  useEffect(() => {
    if ('serviceWorker' in navigator && !import.meta.env.DEV) navigator.serviceWorker.register('/sw.js').catch(err => console.error('sw', err))
    // Re-send this device's location/tz/settings/endpoint on every open, so a missed sync, a time zone
    // change or a rotated push subscription heals itself.
    syncPush().catch(() => {})
  }, [])
  const loc = useLoc()
  const stale = useNewVersion()
  let place = loc?.city ?? ''
  try { if (!place && loc?.country) place = new Intl.DisplayNames([lang], { type: 'region' }).of(loc.country) ?? '' } catch {}
  const flag = loc?.country ? String.fromCodePoint(...[...loc.country].map(c => 0x1f1a5 + c.charCodeAt(0))) : ''
  return (
    <>
      <header className="topbar">
        <span className="brand"><Mark className="brand-mark" />Salat</span>
        {place && <span className="chip"><span aria-hidden="true">{flag}</span>{place}</span>}
      </header>
      <main className="app">{children}</main>
      {stale && (
        <div className="update-banner" role="status">
          <span>{t(lang, 'newVersion')}</span>
          <button className="btn btn-solid" onClick={() => location.reload()}>{t(lang, 'reload')}</button>
        </div>
      )}
      <nav className="tabs" aria-label="Salat">
        <Link to="/"><NavTimes className="tab-icon" /><span>{t(lang, 'times')}</span></Link>
        <Link to="/quran"><NavQuran className="tab-icon" /><span>{t(lang, 'quran')}</span></Link>
        <Link to="/adhkar"><NavAdhkar className="tab-icon" /><span>{t(lang, 'adhkar')}</span></Link>
        <Link to="/qibla"><NavQibla className="tab-icon" /><span>{t(lang, 'qibla')}</span></Link>
        <Link to="/settings"><NavSettings className="tab-icon" /><span>{t(lang, 'settings')}</span></Link>
      </nav>
    </>
  )
}
