// Quran reader logic shared by the /quran route (pure; mirrors apps/macos/Salat/Quran/Recitations.swift).
import type { Lang } from './prayer'

/** `rub`: [ayah, rubʿ number] where one of the 240 quarters (rubʿ al-hizb) starts in this surah. */
export type Surah = { n: number; ar: string; en: string; ayahs: string[]; rub: [number, number][] }
export type AyahTiming = { ayah: number; from: number; to: number } // ms
export type Recitation = { audioUrl: string; timings: AyahTiming[] }

/** quran.com chapter reciters with per-ayah timestamps (same list as the Mac app). */
export const RECITERS = [
  { id: 7, latin: 'Mishary Rashid Alafasy', ar: 'مشاري راشد العفاسي' },
  { id: 3, latin: 'Abdur-Rahman as-Sudais', ar: 'عبد الرحمن السديس' },
  { id: 10, latin: 'Saud ash-Shuraim', ar: 'سعود الشريم' },
  { id: 6, latin: 'Mahmoud Khalil al-Husary', ar: 'محمود خليل الحصري' },
  { id: 2, latin: 'Abdul Basit Abdul Samad', ar: 'عبد الباسط عبد الصمد' },
  { id: 9, latin: 'Mohamed Siddiq al-Minshawi', ar: 'محمد صديق المنشاوي' },
  { id: 97, latin: 'Yasser ad-Dosari', ar: 'ياسر الدوسري' },
  { id: 4, latin: 'Abu Bakr ash-Shatri', ar: 'أبو بكر الشاطري' },
] as const

export const recitationApi = (reciter: number, surah: number) =>
  `https://api.quran.com/api/v4/chapter_recitations/${reciter}/${surah}?segments=true`

type Api = { audio_file: { audio_url: string; timestamps: { verse_key: string; timestamp_from: number; timestamp_to: number }[] } }

export function parseRecitation(json: Api): Recitation {
  const f = json.audio_file
  return {
    audioUrl: f.audio_url,
    timings: f.timestamps.map(t => ({ ayah: Number(t.verse_key.split(':')[1]), from: t.timestamp_from, to: t.timestamp_to })),
  }
}

/** Index of the ayah playing at `ms`: before the first → 0, past the last → last. */
export function ayahIndex(ms: number, timings: AyahTiming[]): number {
  let lo = 0, hi = timings.length - 1
  if (hi < 0) return 0
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1
    if (timings[mid].from <= ms) lo = mid
    else hi = mid - 1
  }
  return lo
}

/** Arabic-Indic digits for ayah markers. */
export const arabicDigits = (n: number) => String(n).replace(/\d/g, d => String.fromCharCode(0x0660 + Number(d)))

/** Rubʿ (1…240) → its juz (1…30), hizb (1…60) and quarter within the hizb (0 = the hizb starts here). */
export const rubInfo = (rub: number) => ({ juz: Math.ceil(rub / 8), hizb: Math.ceil(rub / 4), quarter: (rub - 1) % 4 })

/** Where each of the 60 hizbs starts. */
export const hizbStarts = (surahs: Surah[]) =>
  surahs.flatMap(s => s.rub.filter(([, r]) => r % 4 === 1).map(([ayah, r]) => ({ ...rubInfo(r), surah: s.n, ayah })))

/** A saved ayah (newest first in the list); per device, like the reading position (mirrors Swift `Bookmark`). */
export type Bookmark = { surah: number; ayah: number; at: number }
export const MAX_BOOKMARKS = 20
export const isBookmarked = (list: Bookmark[], surah: number, ayah: number) => list.some(b => b.surah === surah && b.ayah === ayah)
/** Adds the ayah at the top (keeping the newest MAX_BOOKMARKS), or removes it when it's already saved. */
export function toggleBookmark(list: Bookmark[], surah: number, ayah: number, now: number): Bookmark[] {
  if (isBookmarked(list, surah, ayah)) return list.filter(b => !(b.surah === surah && b.ayah === ayah))
  return [{ surah, ayah, at: now }, ...list].slice(0, MAX_BOOKMARKS)
}

/** quran.com tafsirs by UI language: Tafsir al-Muyassar (16), plus Ibn Kathir abridged (169) in English. */
const MUYASSAR = { id: 16, name: 'التفسير الميسر' }
export const TAFSIRS: Record<Lang, { id: number; name: string }[]> = {
  ar: [MUYASSAR], fr: [MUYASSAR], de: [MUYASSAR], nl: [MUYASSAR], es: [MUYASSAR], pt: [MUYASSAR], it: [MUYASSAR],
  en: [{ id: 169, name: 'Ibn Kathir (abridged)' }, MUYASSAR],
}
export const tafsirApi = (id: number, surah: number, ayah: number) =>
  `https://api.quran.com/api/v4/tafsirs/${id}/by_ayah/${surah}:${ayah}`

const ENTITIES: Record<string, string> = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ' }
/** quran.com tafsir HTML → plain paragraphs, so no third-party markup reaches the page. */
export function tafsirText(html: string): string[] {
  return html
    .replace(/<br\s*\/?>|<\/(p|h\d|div|li)>/gi, '\n')
    .replace(/<[^>]*>/g, '')
    .replace(/&(#\d+|[a-z]+);/gi, (m, e: string) => (e[0] === '#' ? String.fromCodePoint(Number(e.slice(1))) : ENTITIES[e.toLowerCase()] ?? m))
    .split('\n').map(x => x.trim()).filter(Boolean)
}
