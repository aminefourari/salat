import { createFileRoute } from '@tanstack/react-router'
import { useEffect, useState } from 'react'
import { useLocation, useSettings } from '../lib/client'
import { t } from '../lib/i18n'
import { qibla } from '../lib/prayer'

export const Route = createFileRoute('/qibla')({ component: QiblaPage })

type Orientation = DeviceOrientationEvent & { webkitCompassHeading?: number }
const hasSensor = () => typeof window !== 'undefined' && 'DeviceOrientationEvent' in window && matchMedia('(pointer: coarse)').matches

function QiblaPage() {
  const [{ lang }] = useSettings()
  const { loc, status, retry } = useLocation()
  const [heading, setHeading] = useState<number | null>(null)
  const [listening, setListening] = useState(false)
  const [sensor, setSensor] = useState(false)
  useEffect(() => setSensor(hasSensor()), [])

  useEffect(() => {
    if (!listening) return
    const onIos = (e: Orientation) => { if (e.webkitCompassHeading != null) setHeading(e.webkitCompassHeading) }
    const onAbs = (e: DeviceOrientationEvent) => { if (e.absolute && e.alpha != null) setHeading((360 - e.alpha) % 360) }
    window.addEventListener('deviceorientation', onIos as EventListener)
    window.addEventListener('deviceorientationabsolute', onAbs as EventListener)
    return () => {
      window.removeEventListener('deviceorientation', onIos as EventListener)
      window.removeEventListener('deviceorientationabsolute', onAbs as EventListener)
    }
  }, [listening])

  async function start() {
    const req = (DeviceOrientationEvent as unknown as { requestPermission?: () => Promise<string> }).requestPermission
    if (req && (await req().catch(() => 'denied')) !== 'granted') return setSensor(false)
    setListening(true)
  }

  if (!loc) {
    return status === 'denied'
      ? <div className="notice" role="alert"><p>{t(lang, 'locationDenied')}</p><button className="btn" onClick={retry}>{t(lang, 'retry')}</button></div>
      : <p className="next-label next">{t(lang, 'locating')}</p>
  }

  const bearing = qibla(loc.lat, loc.lon)
  const deg = Math.round(bearing)
  // With a heading the dial turns so the arrow points at the Kaaba; without one, north is up.
  const rotate = heading == null ? bearing : bearing - heading

  return (
    <>
      <h1>{t(lang, 'qibla')}</h1>
      <p className="deg">{deg}°</p>
      <p className="center meta">{t(lang, 'qiblaBearing', { deg })}</p>
      <div className="compass" role="img" aria-label={t(lang, 'qiblaBearing', { deg })}>
        {heading == null && <span className="n">N</span>}
        <svg viewBox="0 0 100 100" style={{ transform: `rotate(${rotate}deg)` }} aria-hidden="true">
          <path d="M50 17 L55 50 L50 56 L45 50 Z" fill="var(--mark)" />
          <rect x="45.5" y="5" width="9" height="9" rx="1" fill="var(--ink)" />
          <circle cx="50" cy="50" r="2.5" fill="var(--top)" />
        </svg>
      </div>
      <p className="center meta">
        {sensor
          ? (listening ? t(lang, 'compassHint') : <button className="btn btn-solid" onClick={start}>{t(lang, 'useCompass')}</button>)
          : t(lang, 'noCompass', { deg })}
      </p>
    </>
  )
}
