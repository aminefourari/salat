import { createFileRoute, Link } from '@tanstack/react-router'
import { Arch } from '../components/Arch'
import { useEffect, useMemo, useRef, useState } from 'react'
import quranUrl from '../../../../data/quran.json?url'
import { useLazy, useReadPrefs, useSettings } from '../lib/client'
import { fetchJson, memoLoad } from '../lib/load'
import { t } from '../lib/i18n'
import type { Lang } from '../lib/prayer'
import { arabicDigits, ayahIndex, hizbStarts, isBookmarked, parseRecitation, RECITERS, recitationApi, rubInfo, TAFSIRS, tafsirApi, tafsirText, toggleBookmark, searchAyahs, type Bookmark, type Recitation, type Surah } from '../lib/quran'

export const Route = createFileRoute('/quran')({
  validateSearch: (q: Record<string, unknown>): { s?: number; a?: number } => {
    const s = Number(q.s), a = Number(q.a)
    return s >= 1 && s <= 114 ? (Number.isInteger(a) && a > 1 ? { s, a } : { s }) : {}
  },
  component: QuranPage,
})

const loadQuran = memoLoad(() => fetchJson<Surah[]>(quranUrl))

const BISMILLAH = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ'
const num = (n: number, lang: Lang) => n.toLocaleString(lang === 'ar' ? 'ar-EG' : lang)
const latinDigits = (s: string) => s.replace(/[٠-٩]/g, d => String(d.charCodeAt(0) - 0x0660))
const isAbort = (e: unknown) => (e as Error)?.name === 'AbortError'

function QuranPage() {
  const { s, a } = Route.useSearch()
  const [{ lang }] = useSettings()
  const { data: surahs, failed, retry } = useLazy(loadQuran)
  if (failed) return <div className="panel" role="alert"><p>{t(lang, 'loadFailed')}</p><button className="btn" onClick={retry}>{t(lang, 'retry')}</button></div>
  if (!surahs) return <p className="loading">{t(lang, 'loading')}</p>
  return s ? <Reader key={`${s}:${a}`} surahs={surahs} surah={surahs[s - 1]} startAyah={a} lang={lang} /> : <SurahList surahs={surahs} lang={lang} />
}

function SurahList({ surahs, lang }: { surahs: Surah[]; lang: Lang }) {
  const [q, setQ] = useState('')
  const [mode, setMode] = useState<'surahs' | 'hizbs' | 'bookmarks'>('surahs')
  const [prefs] = useReadPrefs()
  const shown = useMemo(() => {
    const k = latinDigits(q.trim().toLowerCase())
    return k ? surahs.filter(x => String(x.n) === k || x.en.toLowerCase().includes(k) || x.ar.includes(k)) : surahs
  }, [q, surahs])
  return (
    <>
      <h1>{t(lang, 'quran')}</h1>
      {prefs.ayah > 1 && (
        <Link to="/quran" search={{ s: prefs.surah }} className="btn btn-solid continue">
          {t(lang, 'continueReading', { surah: lang === 'ar' ? surahs[prefs.surah - 1].ar : surahs[prefs.surah - 1].en, ayah: num(prefs.ayah, lang) })}
        </Link>
      )}
      <div className="seg" role="group">
        <button type="button" aria-pressed={mode === 'surahs'} onClick={() => setMode('surahs')}>{t(lang, 'surahs')}</button>
        <button type="button" aria-pressed={mode === 'hizbs'} onClick={() => setMode('hizbs')}>{t(lang, 'hizbs')}</button>
        <button type="button" aria-pressed={mode === 'bookmarks'} onClick={() => setMode('bookmarks')}>{t(lang, 'bookmarks')}</button>
      </div>
      {mode === 'hizbs' ? <HizbList surahs={surahs} lang={lang} /> : mode === 'bookmarks' ? <BookmarkList surahs={surahs} lang={lang} list={prefs.bookmarks} /> : <>
      <input className="search" type="search" value={q} onChange={e => setQ(e.target.value)} placeholder={t(lang, 'searchQuran')} aria-label={t(lang, 'searchQuran')} />
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
      {q.trim() && <AyahResults surahs={surahs} q={q} lang={lang} quiet={shown.length > 0} />}
      </>}
    </>
  )
}

function HizbList({ surahs, lang }: { surahs: Surah[]; lang: Lang }) {
  return (
    <ul className="list">
      {hizbStarts(surahs).map(h => {
        const s = surahs[h.surah - 1]
        return (
          <li key={h.hizb}>
            <Link to="/quran" search={{ s: h.surah, a: h.ayah }} className="list-row">
              <span className="star-num" aria-hidden="true">{num(h.hizb, lang)}</span>
              <span className="list-main">
                <span className="list-title">{t(lang, 'hizbN', { n: num(h.hizb, lang) })}</span>
                <span className="list-sub">{t(lang, 'juzN', { n: num(h.juz, lang) })} · {lang === 'ar' ? s.ar : s.en} {num(h.ayah, lang)}</span>
              </span>
              <span className="list-ar" lang="ar">{s.ayahs[h.ayah - 1].replace(/^۞\s*/, '').split(' ').slice(0, 3).join(' ')}</span>
            </Link>
          </li>
        )
      })}
    </ul>
  )
}

function BookmarkList({ surahs, lang, list }: { surahs: Surah[]; lang: Lang; list: Bookmark[] }) {
  if (!list.length) return <p className="meta">{t(lang, 'noBookmarks')}</p>
  return (
    <ul className="list">
      {list.map(b => {
        const s = surahs[b.surah - 1]
        return (
          <li key={`${b.surah}:${b.ayah}`}>
            <Link to="/quran" search={b.ayah > 1 ? { s: b.surah, a: b.ayah } : { s: b.surah }} className="list-row">
              <span className="star-num" aria-hidden="true">★</span>
              <span className="list-main">
                <span className="list-title">{lang === 'ar' ? s.ar : s.en} {num(b.ayah, lang)}</span>
                <span className="list-sub">{new Date(b.at).toLocaleDateString(lang, { day: 'numeric', month: 'short', year: 'numeric' })}</span>
              </span>
              <span className="list-ar" lang="ar">{s.ayahs[b.ayah - 1].replace(/^۞\s*/, '').split(' ').slice(0, 3).join(' ')}</span>
            </Link>
          </li>
        )
      })}
    </ul>
  )
}

/** Ayahs matching `q` anywhere in the Quran (text or "2:255"); `quiet` hides the empty message. */
function AyahResults({ surahs, q, lang, quiet }: { surahs: Surah[]; q: string; lang: Lang; quiet?: boolean }) {
  const hits = useMemo(() => searchAyahs(surahs, q), [surahs, q])
  if (!hits.length) return quiet ? null : <p className="meta">{t(lang, 'noResults')}</p>
  return (
    <ul className="list">
      {hits.map(h => {
        const s = surahs[h.surah - 1]
        return (
          <li key={`${h.surah}:${h.ayah}`}>
            <Link to="/quran" search={h.ayah > 1 ? { s: h.surah, a: h.ayah } : { s: h.surah }} className="list-row">
              <span className="list-main">
                <span className="list-title">{lang === 'ar' ? s.ar : s.en} {num(h.ayah, lang)}</span>
                <span className="list-sub hit" lang="ar" dir="rtl">{s.ayahs[h.ayah - 1]}</span>
              </span>
            </Link>
          </li>
        )
      })}
    </ul>
  )
}

/** Previous/next surah links (mirrored in RTL by the ‹ › glyphs). */
function SurahNav({ surahs, n, lang, children }: { surahs: Surah[]; n: number; lang: Lang; children?: React.ReactNode }) {
  const name = (k: number) => (lang === 'ar' ? surahs[k - 1].ar : surahs[k - 1].en)
  return (
    <nav className="surah-nav">
      {n > 1 ? <Link to="/quran" search={{ s: n - 1 }} title={t(lang, 'prevSurah')}>‹ {name(n - 1)}</Link> : <span />}
      {children}
      {n < 114 ? <Link to="/quran" search={{ s: n + 1 }} title={t(lang, 'nextSurah')}>{name(n + 1)} ›</Link> : <span />}
    </nav>
  )
}

/** Juz/hizb/quarter marker shown above the ayah where a rubʿ starts. */
function rubLabel(rub: number, lang: Lang) {
  const { juz, hizb, quarter } = rubInfo(rub)
  const n = num(hizb, lang)
  if (quarter) return t(lang, `rub.${quarter}` as 'rub.1', { n })
  return (rub % 8 === 1 ? `${t(lang, 'juzN', { n: num(juz, lang) })} · ` : '') + t(lang, 'hizbN', { n })
}

/** Tafsir of one ayah, fetched from quran.com when its <details> is first opened. */
function Tafsir({ surah, ayah, lang }: { surah: number; ayah: number; lang: Lang }) {
  const [texts, setTexts] = useState<string[][] | null>(null)
  const [failed, setFailed] = useState(false)
  const sources = TAFSIRS[lang]
  function load(open: boolean) {
    if (!open || texts) return
    setFailed(false)
    Promise.all(sources.map(x => fetchJson<{ tafsir: { text: string } }>(tafsirApi(x.id, surah, ayah)).then(j => tafsirText(j.tafsir.text))))
      .then(setTexts, () => setFailed(true))
  }
  return (
    <details className="tafsir" dir={lang === 'ar' ? 'rtl' : 'ltr'} lang={lang} onToggle={e => load(e.currentTarget.open)}>
      <summary>{t(lang, 'tafsir')}</summary>
      {failed ? <p role="alert">{t(lang, 'loadFailed')}</p>
        : !texts ? <p className="list-sub">{t(lang, 'loading')}</p>
        : sources.map((x, i) => (
          <section key={x.id} lang={x.id === 16 ? 'ar' : 'en'} dir={x.id === 16 ? 'rtl' : 'ltr'}>
            {sources.length > 1 && <h3>{x.name}</h3>}
            {texts[i].map((p, j) => <p key={j}>{p}</p>)}
          </section>
        ))}
    </details>
  )
}

type PlayState = 'idle' | 'loading' | 'playing' | 'paused' | 'error'

function Reader({ surahs, surah, startAyah, lang }: { surahs: Surah[]; surah: Surah; startAyah?: number; lang: Lang }) {
  const [prefs, setPrefs] = useReadPrefs()
  // A reciter picked here is for this listen only; the default lives in Settings (as in the Mac app).
  const [reciter, setReciter] = useState(prefs.reciter)
  const [rec, setRec] = useState<Recitation | null>(null)
  const [state, setState] = useState<PlayState>('idle')
  const [current, setCurrent] = useState<number | null>(null)
  const audio = useRef<HTMLAudioElement>(null)
  // The recitation being fetched, keyed by reciter+surah so a stale response is dropped.
  const pending = useRef<{ key: string; p: Promise<Recitation> } | null>(null)
  const key = `${reciter}:${surah.n}`
  const [q, setQ] = useState('')
  const [tools, setTools] = useState(false)

  /** Scrolls to an ayah of this surah without reloading (the recitation keeps playing). */
  function goTo(ayah: number) {
    if (!(ayah >= 1 && ayah <= surah.ayahs.length)) return
    document.getElementById(`a${ayah}`)?.scrollIntoView({ block: 'start' })
    setPrefs({ ...prefs, surah: surah.n, ayah })
    setTools(false)
  }

  const start = startAyah ?? (prefs.surah === surah.n ? prefs.ayah : 1)
  const rubAt = useMemo(() => new Map(surah.rub), [surah])
  useEffect(() => { setPrefs({ ...prefs, surah: surah.n, ayah: start }) }, [surah.n]) // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    // New surah or reciter: drop the loaded recitation, then prefetch the new one's timings so the first
    // tap can start playback synchronously (iOS only allows play() inside the tap).
    audio.current?.pause()
    pending.current = null
    setRec(null); setCurrent(null); setState('idle')
    load().catch(() => {})
  }, [key]) // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (start > 1) document.getElementById(`a${start}`)?.scrollIntoView({ block: 'start' })
  }, []) // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (current == null) return
    document.getElementById(`a${current}`)?.scrollIntoView({ block: 'center', behavior: 'smooth' })
    setPrefs({ ...prefs, surah: surah.n, ayah: current })
  }, [current]) // eslint-disable-line react-hooks/exhaustive-deps

  function load(): Promise<Recitation> {
    if (pending.current?.key === key) return pending.current.p
    const p = fetchJson<Parameters<typeof parseRecitation>[0]>(recitationApi(reciter, surah.n)).then(json => {
      if (pending.current?.key !== key) throw new DOMException('stale recitation', 'AbortError')
      const r = parseRecitation(json)
      audio.current!.src = r.audioUrl
      setRec(r)
      if ('mediaSession' in navigator) {
        navigator.mediaSession.metadata = new MediaMetadata({
          title: `${surah.ar} — ${surah.en}`, artist: RECITERS.find(x => x.id === reciter)?.latin ?? '', album: 'Salat',
        })
      }
      return r
    })
    pending.current = { key, p }
    p.catch(() => { if (pending.current?.p === p) pending.current = null })
    return p
  }

  /** Synchronous when the recitation is already loaded, so play() runs inside the tap. */
  function playFrom(ayah?: number) {
    const a = audio.current!
    const go = (r: Recitation) => {
      if (ayah) a.currentTime = (r.timings.find(x => x.ayah === ayah)?.from ?? 0) / 1000
      return a.play()
    }
    const run = rec ? go(rec) : (setState('loading'), load().then(go))
    run.catch(e => { if (!isAbort(e)) fail() })
  }

  /** After an error the next press fetches again (a failed <audio> won't replay its src). */
  function fail() {
    setState('error')
    setRec(null)
    pending.current = null
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
        <Arch />
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
        <button className="btn btn-solid play" onClick={toggle} disabled={state === 'loading'} aria-busy={state === 'loading'}
          aria-label={state === 'loading' ? t(lang, 'loading') : state === 'playing' ? t(lang, 'pause') : t(lang, 'play')}>
          {state === 'loading' ? '…' : state === 'playing' ? '❚❚' : '▶'}
        </button>
      </div>
      {state === 'error' && <p className="notice" role="alert">{t(lang, 'audioError')}</p>}

      <SurahNav surahs={surahs} n={surah.n} lang={lang}>
        <button type="button" className="tools-toggle" aria-expanded={tools} aria-controls="reader-tools" onClick={() => setTools(!tools)}
          title={`${t(lang, 'goToAyah')} · ${t(lang, 'search')}`} aria-label={`${t(lang, 'goToAyah')} · ${t(lang, 'search')}`}>
          <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true"><circle cx="11" cy="11" r="7" /><path d="m20 20-4-4" /></svg>
        </button>
      </SurahNav>
      {tools && <div className="reader-tools" id="reader-tools">
        <form className="goto" onSubmit={e => { e.preventDefault(); goTo(Number(latinDigits(String(new FormData(e.currentTarget).get('a'))))) }}>
          <input name="a" type="text" inputMode="numeric" autoFocus placeholder={`1–${num(surah.ayahs.length, lang)}`} aria-label={t(lang, 'goToAyah')} />
          <button className="btn" type="submit">{t(lang, 'goToAyah')}</button>
        </form>
        <input className="search" type="search" value={q} onChange={e => setQ(e.target.value)} placeholder={t(lang, 'searchQuran')} aria-label={t(lang, 'searchQuran')} />
        {q.trim() && <AyahResults surahs={surahs} q={q} lang={lang} />}
      </div>}

      <div className="mushaf" lang="ar" dir="rtl">
        {surah.n !== 1 && surah.n !== 9 && <p className="bismillah">{BISMILLAH}</p>}
        {surah.ayahs.map((text, i) => {
          const rub = rubAt.get(i + 1)
          return (
            <div key={i} id={`a${i + 1}`} className={`ayah${current === i + 1 ? ' is-current' : ''}`} aria-current={current === i + 1 || undefined}>
              {rub && <p className="rub-mark" dir={lang === 'ar' ? 'rtl' : 'ltr'} lang={lang}>{rubLabel(rub, lang)}</p>}
              <button type="button" onClick={() => playFrom(i + 1)}>
                {text} <span className="ayah-no">﴿{arabicDigits(i + 1)}﴾</span>
              </button>
              <div className="ayah-tools" dir={lang === 'ar' ? 'rtl' : 'ltr'}>
                <button type="button" className="bookmark" aria-pressed={isBookmarked(prefs.bookmarks, surah.n, i + 1)}
                  aria-label={t(lang, isBookmarked(prefs.bookmarks, surah.n, i + 1) ? 'removeBookmark' : 'bookmark')}
                  title={t(lang, isBookmarked(prefs.bookmarks, surah.n, i + 1) ? 'removeBookmark' : 'bookmark')}
                  onClick={() => setPrefs({ ...prefs, bookmarks: toggleBookmark(prefs.bookmarks, surah.n, i + 1, Date.now()) })}>
                  {isBookmarked(prefs.bookmarks, surah.n, i + 1) ? '★' : '☆'}
                </button>
                <Tafsir surah={surah.n} ayah={i + 1} lang={lang} />
              </div>
            </div>
          )
        })}
      </div>
      <SurahNav surahs={surahs} n={surah.n} lang={lang} />
      <audio ref={audio} preload="none" onTimeUpdate={onTime} onPlay={() => setState('playing')}
        onPause={() => setState(s => (s === 'error' ? s : 'paused'))} onEnded={() => setState('paused')} onError={() => rec && fail()} />
    </>
  )
}
