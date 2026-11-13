import { describe, expect, it } from 'vitest'
import quran from '../../../data/quran.json'
import adhkar from '../../../data/adhkar.json'
import { ayahIndex, hizbStarts, isBookmarked, MAX_BOOKMARKS, parseRecitation, RECITERS, recitationApi, rubInfo, tafsirText, toggleBookmark, type Surah } from '../src/lib/quran'
import { badge, chapterTitle, translation, type Chapter } from '../src/lib/adhkar'
import { memoLoad } from '../src/lib/load'

describe('quran', () => {
  it('bundled text is complete', () => {
    expect(quran.length).toBe(114)
    expect(quran.reduce((n, s) => n + s.ayahs.length, 0)).toBe(6236)
  })

  it('hizb and juz boundaries', () => {
    expect(rubInfo(1)).toEqual({ juz: 1, hizb: 1, quarter: 0 })
    expect(rubInfo(240)).toEqual({ juz: 30, hizb: 60, quarter: 3 })
    const h = hizbStarts(quran as Surah[])
    expect(h.length).toBe(60)
    expect(h[2]).toEqual({ juz: 2, hizb: 3, quarter: 0, surah: 2, ayah: 142 })
    expect(h[59]).toEqual({ juz: 30, hizb: 60, quarter: 0, surah: 87, ayah: 1 })
  })

  it('tafsir HTML becomes plain paragraphs', () => {
    expect(tafsirText('<h2>Title</h2><p>A &amp; B<br>C &#1575;</p><p><span class="x">D</span> <script>x</script></p>'))
      .toEqual(['Title', 'A & B', 'C ا', 'D x'])
  })

  it('ayahIndex picks the ayah playing at a time, clamped', () => {
    const t = [{ ayah: 1, from: 0, to: 6090 }, { ayah: 2, from: 6090, to: 11680 }, { ayah: 3, from: 11680, to: 15000 }]
    expect([0, 6089, 6090, 14999, 99999, -5].map(ms => ayahIndex(ms, t))).toEqual([0, 0, 1, 2, 2, 0])
    expect(ayahIndex(10, [])).toBe(0)
  })

  it('parses the quran.com chapter_recitations response', () => {
    const r = parseRecitation({ audio_file: { audio_url: 'https://download.quranicaudio.com/qdc/x/1.mp3', timestamps: [
      { verse_key: '1:1', timestamp_from: 0, timestamp_to: 6090 }, { verse_key: '1:2', timestamp_from: 6090, timestamp_to: 11680 },
    ] } })
    expect(r.audioUrl).toBe('https://download.quranicaudio.com/qdc/x/1.mp3')
    expect(r.timings).toEqual([{ ayah: 1, from: 0, to: 6090 }, { ayah: 2, from: 6090, to: 11680 }])
  })

  it('reciters match the Mac app', () => {
    expect(RECITERS.map(r => r.id)).toEqual([7, 3, 10, 6, 2, 9, 97, 4])
    expect(recitationApi(7, 2)).toBe('https://api.quran.com/api/v4/chapter_recitations/7/2?segments=true')
  })
})

describe('adhkar', () => {
  const chapters = adhkar as Chapter[]
  const all = chapters.flatMap(c => c.items)
  const d = (id: number) => all.find(x => x.id === id)!

  it('loads the shared data', () => {
    expect(chapters.length).toBe(132)
    expect(new Set(all.map(x => x.id)).size).toBe(all.length)
  })

  it('translation follows the UI language, none in Arabic', () => {
    expect(translation(d(1), 'ar')).toBeNull()
    expect(translation(d(1), 'en')).toBe(d(1).en)
    expect(translation(d(1), 'fr')).toMatch(/^Louange à Allah qui nous a rendu la vie/)
  })

  it('×N badge only when the Arabic has no count note', () => {
    expect(badge(d(96))).toBeNull()
    expect(badge({ ...d(1), repeat: 33, count_in_text: false })).toBe(33)
  })

  it('chapter titles per language, French falling back to English', () => {
    const c = chapters.find(x => x.id === 27)!
    expect(chapterTitle(c, 'fr')).toBe('Évocations du matin et du soir')
    expect(chapterTitle({ ...c, fr: null }, 'fr')).toBe(c.en)
    expect(chapterTitle(c, 'ar')).toBe(c.ar)
  })
})

describe('memoLoad', () => {
  it('shares one load, and retries after a failure', async () => {
    let calls = 0
    const load = memoLoad(async () => { calls++; if (calls === 1) throw new Error('offline'); return calls })
    await expect(load()).rejects.toThrow('offline')
    expect(await load()).toBe(2)
    expect(await load()).toBe(2)
    expect(calls).toBe(2)
  })
})

describe('bookmarks', () => {
  it('adds newest first, removes on second toggle, keeps at most MAX_BOOKMARKS', () => {
    let list = toggleBookmark([], 2, 255, 1)
    list = toggleBookmark(list, 18, 1, 2)
    expect(list.map(b => [b.surah, b.ayah])).toEqual([[18, 1], [2, 255]])
    expect(isBookmarked(list, 2, 255)).toBe(true)
    list = toggleBookmark(list, 2, 255, 3)
    expect(isBookmarked(list, 2, 255)).toBe(false)
    for (let i = 1; i <= 30; i++) list = toggleBookmark(list, 3, i, 10 + i)
    expect(list.length).toBe(MAX_BOOKMARKS)
    expect(list[0]).toEqual({ surah: 3, ayah: 30, at: 40 })
  })
})

describe('languages', () => {
  it('every language has every string, and adhkar fall back to English where there is no translation', async () => {
    const { t, detectLang, LANG_NAMES } = await import('../src/lib/i18n')
    const { LANGS } = await import('../src/lib/prayer')
    for (const l of LANGS) {
      expect(LANG_NAMES[l]).toBeTruthy()
      expect(t(l, 'notif.start', { prayer: 'X', time: '05:00' })).toContain('05:00')
    }
    expect(detectLang('de-AT')).toBe('de')
    expect(detectLang('pt-BR')).toBe('pt')
    expect(detectLang('sv-SE')).toBe('en')
    const d = (adhkar as Chapter[])[0].items[0]
    expect(translation(d, 'de')).toBe(d.en)
    expect(translation(d, 'fr')).toBe(d.fr)
    expect(translation(d, 'ar')).toBeNull()
  })
})
