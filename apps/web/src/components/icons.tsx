import type { Prayer } from '../lib/prayer'

type P = { className?: string }
const base = { width: 24, height: 24, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: 1.6, strokeLinecap: 'round', strokeLinejoin: 'round', 'aria-hidden': true } as const

const sunRays = <path d="M12 2.5v2M4.6 5.6l1.4 1.4M19.4 5.6 18 7M2.5 12h2M19.5 12h2" />

export const PRAYER_ICONS: Record<Prayer | 'sunrise', (p: P) => React.ReactElement> = {
  // dawn: light before the sun, rising arrow
  fajr: p => <svg {...base} {...p}><path d="M3 18h18M7 18a5 5 0 0 1 10 0" /><path d="M12 6v6M9.5 8.5 12 6l2.5 2.5" /></svg>,
  sunrise: p => <svg {...base} {...p}><path d="M3 19h18M6.5 19a5.5 5.5 0 0 1 11 0" />{sunRays}</svg>,
  dhuhr: p => <svg {...base} {...p}><circle cx="12" cy="12" r="4" /><path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4" /></svg>,
  asr: p => <svg {...base} {...p}><circle cx="14" cy="10" r="3.5" /><path d="M3 19h18M14 3v1.5M20.5 10H19M18.6 5.4l-1 1M9.4 5.4l1 1" /><path d="M5 19l5-5" opacity=".6" /></svg>,
  maghrib: p => <svg {...base} {...p}><path d="M3 18h18M7 18a5 5 0 0 1 10 0" /><path d="M12 5v6M9.5 8.5 12 11l2.5-2.5" /></svg>,
  isha: p => <svg {...base} {...p}><path d="M18 14.5A7 7 0 1 1 10.5 5a5.5 5.5 0 0 0 7.5 9.5Z" /><path d="m18 4 .6 1.4L20 6l-1.4.6L18 8l-.6-1.4L16 6l1.4-.6Z" /></svg>,
}

export const NavTimes = (p: P) => <svg {...base} {...p}><circle cx="12" cy="12" r="8.5" /><path d="M12 7.5V12l3 2" /></svg>
export const NavQibla = (p: P) => (
  <svg {...base} {...p}><path d="M5 8.5 12 5l7 3.5v8L12 20l-7-3.5Z" /><path d="M5 8.5 12 12l7-3.5M12 12v8" /><path d="M5 11l7 3.5 7-3.5" opacity=".55" /></svg>
)
export const NavQuran = (p: P) => (
  <svg {...base} {...p}><path d="M12 6.5C10 5 7 4.5 4 5v13c3-.5 6 0 8 1.5 2-1.5 5-2 8-1.5V5c-3-.5-6 0-8 1.5Z" /><path d="M12 6.5v13" /></svg>
)
export const NavAdhkar = (p: P) => (
  <svg {...base} {...p}><circle cx="12" cy="5" r="1.6" /><circle cx="17.2" cy="8" r="1.6" /><circle cx="17.2" cy="14" r="1.6" /><circle cx="6.8" cy="8" r="1.6" /><circle cx="6.8" cy="14" r="1.6" /><circle cx="12" cy="17" r="1.6" /><path d="M12 18.6V22" /></svg>
)
export const NavSettings = (p: P) => (
  <svg {...base} {...p}><path d="M4 7h9M17 7h3M4 17h3M11 17h9" /><circle cx="15" cy="7" r="2" /><circle cx="9" cy="17" r="2" /></svg>
)

/** The app mark: crescent + eight-pointed star (matches the icon). */
export const Mark = (p: P) => (
  <svg viewBox="0 0 32 32" aria-hidden="true" {...p}>
    <path fill="currentColor" d="M14.5 4.5a11.5 11.5 0 1 0 11 15A9.6 9.6 0 1 1 14.5 4.5Z" />
    <g fill="currentColor" transform="translate(21 13)"><rect x="-2.6" y="-2.6" width="5.2" height="5.2" /><rect x="-2.6" y="-2.6" width="5.2" height="5.2" transform="rotate(45)" /></g>
  </svg>
)
