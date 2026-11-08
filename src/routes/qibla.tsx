import { createFileRoute } from '@tanstack/react-router'
import { useEffect, useRef, useState } from 'react'
import { useLocation, useSettings } from '../lib/client'
import { t } from '../lib/i18n'
import { compass8, kaabaDistanceKm, qibla, turnDelta } from '../lib/prayer'

export const Route = createFileRoute('/qibla')({ component: QiblaPage })

type Orientation = DeviceOrientationEvent & { webkitCompassHeading?: number; webkitCompassAccuracy?: number }
const ALIGNED_DEG = 5
const TICKS = Array.from({ length: 72 }, (_, i) => i * 5)

const hasSensor = () => typeof window !== 'undefined' && 'DeviceOrientationEvent' in window && matchMedia('(pointer: coarse)').matches
const screenAngle = () => (typeof screen !== 'undefined' && screen.orientation ? screen.orientation.angle : 0)

/** Live compass heading (degrees from north), or null until the sensor reports. */
function useHeading(enabled: boolean) {
  const [heading, setHeading] = useState<number | null>(null)
  const [inaccurate, setInaccurate] = useState(false)
  useEffect(() => {
    if (!enabled) return
    const onIos = (e: Orientation) => {
      if (e.webkitCompassHeading == null) return
      setHeading((e.webkitCompassHeading + screenAngle()) % 360)
      setInaccurate(e.webkitCompassAccuracy == null || e.webkitCompassAccuracy < 0 || e.webkitCompassAccuracy > 25)
    }
    const onAbs = (e: DeviceOrientationEvent) => {
      if (e.alpha == null) return
      setHeading((360 - e.alpha + screenAngle()) % 360)
    }
    window.addEventListener('deviceorientation', onIos as EventListener)
    window.addEventListener('deviceorientationabsolute', onAbs as EventListener)
    return () => {
      window.removeEventListener('deviceorientation', onIos as EventListener)
      window.removeEventListener('deviceorientationabsolute', onAbs as EventListener)
    }
  }, [enabled])
  return { heading, inaccurate }
}

function QiblaPage() {
  const [{ lang }] = useSettings()
  const { loc, status, retry } = useLocation()
  const [sensor, setSensor] = useState(false)
  const [listening, setListening] = useState(false)
  const [denied, setDenied] = useState(false)
  const { heading, inaccurate } = useHeading(listening)
  useEffect(() => setSensor(hasSensor()), [])

  // Unwrapped dial rotation so the dial never spins the long way round between 359° and 0°.
  const rot = useRef(0)
  if (heading != null) rot.current += turnDelta(heading, ((rot.current % 360) + 360) % 360)

  const bearing = loc ? qibla(loc.lat, loc.lon) : 0
  const delta = heading == null ? null : turnDelta(bearing, heading)
  const aligned = delta != null && Math.abs(delta) <= ALIGNED_DEG

  const wasAligned = useRef(false)
  useEffect(() => {
    if (aligned && !wasAligned.current) navigator.vibrate?.(40)
    wasAligned.current = aligned
  }, [aligned])

  async function start() {
    const req = (DeviceOrientationEvent as unknown as { requestPermission?: () => Promise<string> }).requestPermission
    if (req && (await req().catch(() => 'denied')) !== 'granted') return setDenied(true)
    setListening(true)
  }

  if (!loc) {
    return status === 'denied'
      ? <div className="notice" role="alert"><p>{t(lang, 'locationDenied')}</p><button className="btn" onClick={retry}>{t(lang, 'retry')}</button></div>
      : <p className="next-label next">{t(lang, 'locating')}</p>
  }

  const deg = Math.round(bearing)
  const dirs = t(lang, 'dirs').split(',')
  const dir = t(lang, 'dirWords').split(',')[compass8(bearing)]
  const km = Math.round(kaabaDistanceKm(loc.lat, loc.lon)).toLocaleString(lang)
  const live = heading != null
  const r = live ? rot.current : 0 // dial rotation; labels counter-rotate by it to stay upright

  return (
    <>
      <h1>{t(lang, 'qibla')}</h1>

      <div className={`dial${aligned ? ' is-aligned' : ''}`} role="img" aria-label={t(lang, 'qiblaBearing', { deg })}>
        <svg viewBox="-160 -160 320 320" aria-hidden="true">
          <g className="dial-rot" style={{ transform: `rotate(${-r}deg)` }}>
            <circle className="ring" r="140" />
            {TICKS.map(a => (
              <line key={a} className={a % 90 === 0 ? 'tick tick-major' : a % 30 === 0 ? 'tick tick-mid' : 'tick'}
                y1="-140" y2={a % 30 === 0 ? -126 : -133} transform={`rotate(${a})`} />
            ))}
            {[0, 90, 180, 270].map((a, i) => (
              <text key={a} className={a === 0 ? 'cardinal is-north' : 'cardinal'} transform={`rotate(${a}) translate(0 -108) rotate(${-a + r})`}>
                {dirs[i * 2]}
              </text>
            ))}
            {[30, 60, 120, 150, 210, 240, 300, 330].map(a => (
              <text key={a} className="deg-label" transform={`rotate(${a}) translate(0 -110) rotate(${-a + r})`}>{a}</text>
            ))}
            <g transform={`rotate(${bearing})`}>
              <line className="needle-trail" y1="0" y2="-84" />
              <path className="needle" d="M0 -96 L9 -66 L0 -72 L-9 -66 Z" />
              <g transform={`translate(0 -120) rotate(${-bearing + r})`}>
                <rect className="kaaba" x="-10" y="-10" width="20" height="20" rx="1.5" />
                <rect className="kaaba-band" x="-10" y="-5" width="20" height="3.5" />
              </g>
            </g>
          </g>
          {live && <path className="lubber" d="M0 -146 L-8 -159 L8 -159 Z" />}
          <circle className="hub" r="7" />
        </svg>
      </div>

      <div className="qibla-info" aria-live="polite">
        {live
          ? <p className={`qibla-status${aligned ? ' is-aligned' : ''}`}>
              {aligned ? t(lang, 'facing') : t(lang, delta! > 0 ? 'turnRight' : 'turnLeft', { deg: Math.abs(Math.round(delta!)) })}
            </p>
          : <p className="deg">{deg}°</p>}
        <p className="meta">{t(lang, 'qiblaBearing', { deg })} · {dir}</p>
        <p className="meta">{t(lang, 'distance', { km })}</p>
        {sensor && !listening && !denied && <button className="btn btn-solid" onClick={start}>{t(lang, 'useCompass')}</button>}
        {listening && !live && <p className="meta">{t(lang, 'compassHint')}</p>}
        {live && inaccurate && <p className="meta" role="status">{t(lang, 'calibrate')}</p>}
        {denied && <p className="meta" role="alert">{t(lang, 'compassDenied', { deg, dir })}</p>}
        {!sensor && <p className="meta">{t(lang, 'noCompass', { deg, dir })}</p>}
      </div>
    </>
  )
}
