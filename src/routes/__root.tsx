import { HeadContent, Link, Scripts, createRootRoute } from '@tanstack/react-router'
import { useEffect } from 'react'
import appCss from '../styles.css?url'
import { syncPush, useSettings } from '../lib/client'
import { t } from '../lib/i18n'

export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1, viewport-fit=cover' },
      { name: 'theme-color', content: '#141b3a' },
      { name: 'apple-mobile-web-app-capable', content: 'yes' },
      { name: 'apple-mobile-web-app-status-bar-style', content: 'black-translucent' },
      { name: 'apple-mobile-web-app-title', content: 'Salat' },
      { name: 'description', content: 'Prayer times, reminders and Qibla for where you are.' },
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
  return (
    <>
      <main className="app">{children}</main>
      <nav className="tabs" aria-label="Salat">
        <Link to="/">{t(lang, 'times')}</Link>
        <Link to="/qibla">{t(lang, 'qibla')}</Link>
        <Link to="/settings">{t(lang, 'settings')}</Link>
      </nav>
    </>
  )
}
