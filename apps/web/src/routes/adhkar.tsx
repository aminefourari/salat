import { createFileRoute, Link } from '@tanstack/react-router'
import { useEffect, useMemo, useRef, useState } from 'react'
import adhkarUrl from '../../../../data/adhkar.json?url'
import { badge, chapterTitle, translation, type Chapter } from '../lib/adhkar'
import { useLazy, useReadPrefs, useSettings } from '../lib/client'
import { t } from '../lib/i18n'
import type { Lang } from '../lib/prayer'

export const Route = createFileRoute('/adhkar')({
  validateSearch: (q: Record<string, unknown>): { c?: number } => (Number(q.c) > 0 ? { c: Number(q.c) } : {}),
  component: AdhkarPage,
})

let adhkar: Promise<Chapter[]> | undefined
const loadAdhkar = () => (adhkar ??= fetch(adhkarUrl).then(r => r.json()))

function AdhkarPage() {
  const { c } = Route.useSearch()
  const [{ lang }] = useSettings()
  const chapters = useLazy(loadAdhkar)
  if (!chapters) return <p className="loading">{t(lang, 'loading')}</p>
  const chapter = c ? chapters.find(x => x.id === c) : undefined
  return chapter ? <ChapterView chapter={chapter} lang={lang} /> : <ChapterList chapters={chapters} lang={lang} />
}

function ChapterList({ chapters, lang }: { chapters: Chapter[]; lang: Lang }) {
  const [q, setQ] = useState('')
  const [prefs] = useReadPrefs()
  const shown = useMemo(() => {
    const k = q.trim().toLowerCase()
    return k ? chapters.filter(x => chapterTitle(x, lang).toLowerCase().includes(k) || x.ar.includes(k)) : chapters
  }, [q, chapters, lang])
  return (
    <>
      <h1>{t(lang, 'adhkar')}</h1>
      <input className="search" type="search" value={q} onChange={e => setQ(e.target.value)} placeholder={t(lang, 'search')} aria-label={t(lang, 'search')} />
      <ul className="list">
        {shown.map(x => (
          <li key={x.id}>
            <Link to="/adhkar" search={{ c: x.id }} className={`list-row${x.id === prefs.adhkar ? ' is-last' : ''}`}>
              <span className="sparkle" aria-hidden="true">✦</span>
              <span className="list-main"><span className="list-title">{chapterTitle(x, lang)}</span></span>
            </Link>
          </li>
        ))}
      </ul>
    </>
  )
}

function ChapterView({ chapter, lang }: { chapter: Chapter; lang: Lang }) {
  const [prefs, setPrefs] = useReadPrefs()
  const [playing, setPlaying] = useState<number | null>(null)
  const [failed, setFailed] = useState<number | null>(null)
  const audio = useRef<HTMLAudioElement>(null)
  useEffect(() => { if (prefs.adhkar !== chapter.id) setPrefs({ ...prefs, adhkar: chapter.id }) }, [chapter.id]) // eslint-disable-line react-hooks/exhaustive-deps

  async function play(id: number, url: string) {
    const a = audio.current!
    if (playing === id) { a.pause(); return }
    setFailed(null)
    a.src = url
    try { await a.play(); setPlaying(id) } catch { setFailed(id); setPlaying(null) }
  }

  return (
    <>
      <Link to="/adhkar" className="back">{t(lang, 'allCategories')}</Link>
      <h1>{chapterTitle(chapter, lang)}</h1>
      {lang !== 'ar' && <p className="chapter-ar" lang="ar">{chapter.ar}</p>}
      {chapter.items.map(d => {
        const tr = translation(d, lang), n = badge(d)
        return (
          <article key={d.id} className={`dhikr panel${playing === d.id ? ' is-playing' : ''}`}>
            <p className="dhikr-ar" lang="ar" dir="rtl">{d.ar}</p>
            {tr && <p className="dhikr-tr">{tr}</p>}
            <div className="dhikr-foot">
              {n && <span className="badge">×{n.toLocaleString(lang === 'ar' ? 'ar-EG' : lang)}</span>}
              {d.ref && <span className="meta">{d.ref}</span>}
              {d.audio && (
                <button className="btn play" onClick={() => play(d.id, d.audio!)} aria-label={playing === d.id ? t(lang, 'pause') : t(lang, 'play')}>
                  {playing === d.id ? '❚❚' : '▶'}
                </button>
              )}
            </div>
            {failed === d.id && <p className="meta" role="alert">{t(lang, 'audioError')}</p>}
          </article>
        )
      })}
      <audio ref={audio} preload="none" onPause={() => setPlaying(null)} onEnded={() => setPlaying(null)} />
    </>
  )
}
