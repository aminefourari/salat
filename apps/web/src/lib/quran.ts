// Quran reader logic shared by the /quran route (pure; mirrors apps/macos/Salat/Quran/Recitations.swift).

export type Surah = { n: number; ar: string; en: string; ayahs: string[] }
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
