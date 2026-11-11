import { createFileRoute } from '@tanstack/react-router'
import { useEffect, useState } from 'react'
import {
  currentPushSub, disablePush, enablePush, isIos, isStandalone, pushSupported,
  setNotify, setSettings, testPush, useLocation, useNotify, useReadPrefs, useSettings,
} from '../lib/client'
import { VAPID_PUBLIC_KEY } from '../lib/config'
import { t } from '../lib/i18n'
import { METHOD_IDS } from '../lib/methods'
import { RECITERS } from '../lib/quran'
import { hijriOffset, MAX_ADJUST, PRAYERS, resolveMethod, type Lang, type Settings } from '../lib/prayer'

export const Route = createFileRoute('/settings')({ component: SettingsPage })

const signed = (n: number) => (n > 0 ? `+${n}` : String(n))

type PushState = 'loading' | 'on' | 'off' | 'denied' | 'unsupported' | 'install'

function SettingsPage() {
  const [s] = useSettings()
  const [notify] = useNotify()
  const [read, setRead] = useReadPrefs()
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

      <h2>{t(lang, 'times')}</h2>
      <div className="panel">
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
        <div className="field">
          <label htmlFor="hijri">{t(lang, 'hijriOffset')}</label>
          <select id="hijri" value={s.hijri ?? 'auto'} onChange={e => update({ hijri: e.target.value === 'auto' ? undefined : Number(e.target.value) })}>
            <option value="auto">{t(lang, 'hijriAuto', { n: signed(loc ? hijriOffset(loc.lat, loc.lon, { ...s, hijri: undefined }) : 0) })}</option>
            {[-2, -1, 0, 1, 2].map(n => <option key={n} value={n}>{t(lang, 'days', { n: signed(n) })}</option>)}
          </select>
        </div>
      </div>

      <h2>{t(lang, 'adjustments')}</h2>
      <div className="panel">
        <p className="meta">{t(lang, 'adjustHint')}</p>
        <div className="adjust">
          {PRAYERS.map(p => (
            <label key={p} className="field">
              {t(lang, p)}
              <input type="number" inputMode="numeric" min={-MAX_ADJUST} max={MAX_ADJUST} step={1} value={s.adjust?.[p] ?? 0}
                onChange={e => {
                  const v = Math.max(-MAX_ADJUST, Math.min(MAX_ADJUST, Math.trunc(Number(e.target.value) || 0)))
                  update({ adjust: { ...s.adjust, [p]: v } })
                }} />
            </label>
          ))}
        </div>
      </div>

      <h2>{t(lang, 'quran')}</h2>
      <div className="panel">
        <div className="field">
          <label htmlFor="reciter">{t(lang, 'defaultReciter')}</label>
          <select id="reciter" value={read.reciter} onChange={e => setRead({ ...read, reciter: Number(e.target.value) })}>
            {RECITERS.map(r => <option key={r.id} value={r.id}>{lang === 'ar' ? r.ar : r.latin}</option>)}
          </select>
        </div>
      </div>

      <h2>{t(lang, 'notifications')}</h2>
      <div className="panel">
        <label className="switch-row">
          {t(lang, 'notifyStart')}
          <input className="switch" type="checkbox" role="switch" checked={notify.start} onChange={e => setNotify({ ...notify, start: e.target.checked })} />
        </label>
        <label className="switch-row">
          {t(lang, 'notifyReminder')}
          <input className="switch" type="checkbox" role="switch" checked={notify.reminder} onChange={e => setNotify({ ...notify, reminder: e.target.checked })} />
        </label>
        <label className="switch-row">
          {t(lang, 'notifyAdhkar')}
          <input className="switch" type="checkbox" role="switch" checked={notify.adhkar} onChange={e => setNotify({ ...notify, adhkar: e.target.checked })} />
        </label>
        <label className="switch-row">
          {t(lang, 'notifyFriday')}
          <input className="switch" type="checkbox" role="switch" checked={notify.friday} onChange={e => setNotify({ ...notify, friday: e.target.checked })} />
        </label>
      </div>
      <div className="panel" role="status">
        {push === 'install' && <p>{t(lang, 'installHint')}</p>}
        {push === 'unsupported' && <p>{t(lang, 'unsupported')}</p>}
        {push === 'denied' && <p>{t(lang, 'denied')}</p>}
        {push === 'on' && <p>{t(lang, 'enabled')}</p>}
        {!loc && push === 'off' && <p className="meta">{t(lang, 'locating')}</p>}
        {(push === 'on' || push === 'off') && (
          <p>
            <button className={push === 'on' ? 'btn' : 'btn btn-solid'} onClick={toggle} disabled={busy || !loc}>
              {t(lang, push === 'on' ? 'disable' : 'enable')}
            </button>
            {push === 'on' && (
              <button className="btn" disabled={busy} onClick={() => { setError(''); testPush().catch(e => setError(String(e.message ?? e))) }}>
                {t(lang, 'sendTest')}
              </button>
            )}
          </p>
        )}
        {error && <p className="meta" role="alert">{error}</p>}
      </div>

      <h2>{t(lang, 'language')}</h2>
      <div className="panel">
        <div className="field">
          <select id="lang" aria-label={t(lang, 'language')} value={lang} onChange={e => update({ lang: e.target.value as Lang })}>
            <option value="ar">العربية</option>
            <option value="en">English</option>
            <option value="fr">Français</option>
          </select>
        </div>
      </div>
    </>
  )
}
