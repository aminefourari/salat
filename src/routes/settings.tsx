import { createFileRoute } from '@tanstack/react-router'
import { useEffect, useState } from 'react'
import {
  currentPushSub, disablePush, enablePush, isIos, isStandalone, pushSupported,
  setNotify, setSettings, testPush, useLocation, useNotify, useSettings,
} from '../lib/client'
import { VAPID_PUBLIC_KEY } from '../lib/config'
import { t } from '../lib/i18n'
import { METHOD_IDS } from '../lib/methods'
import { resolveMethod, type Lang, type Settings } from '../lib/prayer'

export const Route = createFileRoute('/settings')({ component: SettingsPage })

type PushState = 'loading' | 'on' | 'off' | 'denied' | 'unsupported' | 'install'

function SettingsPage() {
  const [s] = useSettings()
  const [notify] = useNotify()
  const { loc } = useLocation()
  const { lang } = s
  const [push, setPush] = useState<PushState>('loading')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    if (isIos() && !isStandalone()) return setPush('install')
    if (!pushSupported()) return setPush('unsupported')
    if (Notification.permission === 'denied') return setPush('denied')
    currentPushSub().then(sub => setPush(sub ? 'on' : 'off'), () => setPush('off'))
  }, [])

  const update = (patch: Partial<Settings>) => setSettings({ ...s, ...patch })
  const auto = loc ? t(lang, `m.${resolveMethod(loc.lat, loc.lon, { ...s, method: 'auto' })}`) : '…'

  async function toggle() {
    setBusy(true); setError('')
    try {
      if (push === 'on') { await disablePush(); setPush('off') } else { await enablePush(VAPID_PUBLIC_KEY); setPush('on') }
    } catch (e) {
      if (Notification.permission === 'denied') setPush('denied')
      else setError(String((e as Error).message ?? e))
    } finally { setBusy(false) }
  }

  return (
    <>
      <h1>{t(lang, 'settings')}</h1>

      <div className="field">
        <label htmlFor="lang">{t(lang, 'language')}</label>
        <select id="lang" value={lang} onChange={e => update({ lang: e.target.value as Lang })}>
          <option value="ar">العربية</option>
          <option value="en">English</option>
          <option value="fr">Français</option>
        </select>
      </div>

      <div className="field">
        <label htmlFor="method">{t(lang, 'method')}</label>
        <select id="method" value={s.method} onChange={e => update({ method: e.target.value as Settings['method'] })}>
          <option value="auto">{t(lang, 'auto', { method: auto })}</option>
          {METHOD_IDS.map(id => <option key={id} value={id}>{t(lang, `m.${id}`)}</option>)}
        </select>
      </div>

      <div className="field">
        <label htmlFor="asr">{t(lang, 'asrMethod')}</label>
        <select id="asr" value={s.asr} onChange={e => update({ asr: e.target.value as Settings['asr'] })}>
          <option value="standard">{t(lang, 'standard')}</option>
          <option value="hanafi">{t(lang, 'hanafi')}</option>
        </select>
      </div>

      <h2>{t(lang, 'notifications')}</h2>
      <label className="check">
        <input type="checkbox" checked={notify.start} onChange={e => setNotify({ ...notify, start: e.target.checked })} />
        {t(lang, 'notifyStart')}
      </label>
      <label className="check">
        <input type="checkbox" checked={notify.reminder} onChange={e => setNotify({ ...notify, reminder: e.target.checked })} />
        {t(lang, 'notifyReminder')}
      </label>

      <div className="notice" role="status">
        {push === 'install' && <p>{t(lang, 'installHint')}</p>}
        {push === 'unsupported' && <p>{t(lang, 'unsupported')}</p>}
        {push === 'denied' && <p>{t(lang, 'denied')}</p>}
        {push === 'on' && <p>{t(lang, 'enabled')}</p>}
        {(push === 'on' || push === 'off') && (
          <button className={push === 'on' ? 'btn' : 'btn btn-solid'} onClick={toggle} disabled={busy || !loc}>
            {t(lang, push === 'on' ? 'disable' : 'enable')}
          </button>
        )}
        {push === 'on' && (
          <button className="btn" style={{ marginInlineStart: '.5rem' }} disabled={busy}
            onClick={() => { setError(''); testPush().catch(e => setError(String(e.message ?? e))) }}>
            {t(lang, 'sendTest')}
          </button>
        )}
        {!loc && push === 'off' && <p className="meta">{t(lang, 'locating')}</p>}
        {error && <p className="meta" role="alert">{error}</p>}
      </div>
    </>
  )
}
