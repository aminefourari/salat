import { describe, expect, it } from 'vitest'
import quran from '../../../data/quran.json'
import adhkar from '../../../data/adhkar.json'
import { ayahIndex, parseRecitation, RECITERS, recitationApi } from '../src/lib/quran'
import { badge, chapterTitle, translation, type Chapter } from '../src/lib/adhkar'

describe('quran', () => {
  it('bundled text is complete', () => {
    expect(quran.length).toBe(114)
    expect(quran.reduce((n, s) => n + s.ayahs.length, 0)).toBe(6236)
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
