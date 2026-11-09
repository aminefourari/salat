import { createFileRoute, Link } from '@tanstack/react-router'
import { useEffect, useMemo, useRef, useState } from 'react'
import quranUrl from '../../../../data/quran.json?url'
import { useLazy, useReadPrefs, useSettings } from '../lib/client'
import { t } from '../lib/i18n'
import type { Lang } from '../lib/prayer'
import { arabicDigits, ayahIndex, parseRecitation, RECITERS, recitationApi, type Recitation, type Surah } from '../lib/quran'

export const Route = createFileRoute('/quran')({
  validateSearch: (q: Record<string, unknown>): { s?: number } => {
    const s = Number(q.s)
    return s >= 1 && s <= 114 ? { s } : {}
  },
  component: QuranPage,
})

let quran: Promise<Surah[]> | undefined
const loadQuran = () => (quran ??= fetch(quranUrl).then(r => r.json()))

const BISMILLAH = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ'
const num = (n: number, lang: Lang) => n.toLocaleString(lang === 'ar' ? 'ar-EG' : lang)

function QuranPage() {
  const { s } = Route.useSearch()
  const [{ lang }] = useSettings()
  const surahs = useLazy(loadQuran)
  if (!surahs) return <p className="loading">{t(lang, 'loading')}</p>
  return s ? <Reader surah={surahs[s - 1]} lang={lang} /> : <SurahList surahs={surahs} lang={lang} />
}

function SurahList({ surahs, lang }: { surahs: Surah[]; lang: Lang }) {
  const [q, setQ] = useState('')
  const [prefs] = useReadPrefs()
  const shown = useMemo(() => {
    const k = q.trim().toLowerCase()
    return k ? surahs.filter(x => String(x.n) === k || x.en.toLowerCase().includes(k) || x.ar.includes(k)) : surahs
  }, [q, surahs])
  return (
    <>
      <h1>{t(lang, 'quran')}</h1>
      <input className="search" type="search" value={q} onChange={e => setQ(e.target.value)} placeholder={t(lang, 'search')} aria-label={t(lang, 'search')} />
      <ul className="list">
        {shown.map(x => (
          <li key={x.n}>
            <Link to="/quran" search={{ s: x.n }} className={`list-row${x.n === prefs.surah ? ' is-last' : ''}`}>
              <span className="star-num" aria-hidden="true">{num(x.n, lang)}</span>
              <span className="list-main">
                <span className="list-title">{lang === 'ar' ? x.ar : x.en}</span>
                <span className="list-sub">{t(lang, 'ayahs', { n: num(x.ayahs.length, lang) })}</span>
              </span>
              {lang !== 'ar' && <span className="list-ar" lang="ar">{x.ar}</span>}
            </Link>
          </li>
        ))}
      </ul>
    </>
  )
}

type PlayState = 'idle' | 'loading' | 'playing' | 'paused' | 'error'

function Reader({ surah, lang }: { surah: Surah; lang: Lang }) {
  const [prefs, setPrefs] = useReadPrefs()
  // A reciter picked here is for this listen only; the default lives in Settings (as in the Mac app).
  const [reciter, setReciter] = useState(prefs.reciter)
  const [rec, setRec] = useState<Recitation | null>(null)
  const [state, setState] = useState<PlayState>('idle')
  const [current, setCurrent] = useState<number | null>(null)
  const audio = useRef<HTMLAudioElement>(null)

  useEffect(() => { setPrefs({ ...prefs, surah: surah.n }) }, [surah.n]) // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    // New surah or reciter: drop the loaded recitation.
    audio.current?.pause()
    setRec(null); setCurrent(null); setState('idle')
  }, [surah.n, reciter])
  useEffect(() => {
    if (prefs.surah === surah.n && prefs.ayah > 1) document.getElementById(`a${prefs.ayah}`)?.scrollIntoView({ block: 'start' })
  }, []) // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (current == null) return
    document.getElementById(`a${current}`)?.scrollIntoView({ block: 'center', behavior: 'smooth' })
    setPrefs({ ...prefs, surah: surah.n, ayah: current })
  }, [current]) // eslint-disable-line react-hooks/exhaustive-deps

  async function load(): Promise<Recitation> {
    if (rec) return rec
    setState('loading')
    const res = await fetch(recitationApi(reciter, surah.n))
    if (!res.ok) throw new Error(String(res.status))
    const r = parseRecitation(await res.json())
    audio.current!.src = r.audioUrl
    setRec(r)
    if ('mediaSession' in navigator) {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: `${surah.ar} — ${surah.en}`, artist: RECITERS.find(x => x.id === reciter)?.latin ?? '', album: 'Salat',
      })
    }
    return r
  }

  async function playFrom(ayah?: number) {
    try {
      const r = await load()
      const a = audio.current!
      if (ayah) a.currentTime = (r.timings.find(x => x.ayah === ayah)?.from ?? 0) / 1000
      await a.play()
    } catch {
      setState('error')
    }
  }

  const toggle = () => (state === 'playing' ? audio.current?.pause() : playFrom())
  const onTime = () => {
    if (!rec?.timings.length || !audio.current) return
    const a = rec.timings[ayahIndex(audio.current.currentTime * 1000, rec.timings)].ayah
    if (a !== current) setCurrent(a)
  }

  return (
    <>
      <Link to="/quran" className="back">{t(lang, 'allSurahs')}</Link>
      <header className="surah-head">
        <svg className="arch" viewBox="0 0 200 260" preserveAspectRatio="none" aria-hidden="true">
          <path className="arch-fill" d="M4 260V112C4 58 52 26 100 4c48 22 96 54 96 108v148Z" />
          <path className="arch-line" d="M4 260V112C4 58 52 26 100 4c48 22 96 54 96 108v148Z" />
          <path className="arch-inner" d="M14 260V116C14 68 56 38 100 18c44 20 86 50 86 98v144" />
        </svg>
        <div className="surah-head-body">
          <p className="surah-ar" lang="ar">{surah.ar}</p>
          {lang !== 'ar' && <p className="surah-en">{surah.en}</p>}
          <p className="list-sub">{t(lang, 'ayahs', { n: num(surah.ayahs.length, lang) })}</p>
        </div>
      </header>

      <div className="player" role="group" aria-label={t(lang, 'reciter')}>
        <select value={reciter} onChange={e => setReciter(Number(e.target.value))} aria-label={t(lang, 'reciter')}>
          {RECITERS.map(r => <option key={r.id} value={r.id}>{lang === 'ar' ? r.ar : r.latin}</option>)}
        </select>
        <button className="btn btn-solid play" onClick={toggle} disabled={state === 'loading'} aria-label={state === 'playing' ? t(lang, 'pause') : t(lang, 'play')}>
          {state === 'loading' ? '…' : state === 'playing' ? '❚❚' : '▶'}
        </button>
      </div>
      {state === 'error' && <p className="notice" role="alert">{t(lang, 'audioError')}</p>}

      <div className="mushaf" lang="ar" dir="rtl">
        {surah.n !== 1 && surah.n !== 9 && <p className="bismillah">{BISMILLAH}</p>}
        {surah.ayahs.map((text, i) => (
          <p key={i} id={`a${i + 1}`} className={`ayah${current === i + 1 ? ' is-current' : ''}`}>
            <button type="button" onClick={() => playFrom(i + 1)}>
              {text} <span className="ayah-no">﴿{arabicDigits(i + 1)}﴾</span>
            </button>
          </p>
        ))}
      </div>
      <audio ref={audio} preload="none" onTimeUpdate={onTime} onPlay={() => setState('playing')}
        onPause={() => setState(s => (s === 'error' ? s : 'paused'))} onEnded={() => setState('paused')} onError={() => rec && setState('error')} />
    </>
  )
}
