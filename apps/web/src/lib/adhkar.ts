// Hisn al-Muslim adhkar (data/adhkar.json, built by apps/macos/scripts/fetch-adhkar.py).
import type { Lang } from './prayer'

export type Dhikr = {
  id: number; ar: string; en: string | null; fr: string | null; ref: string | null
  repeat: number; count_in_text: boolean; audio: string | null
}
export type Chapter = { id: number; ar: string; en: string; fr: string | null; items: Dhikr[] }

/** Language of the translation shown in `lang`: French has its own, the other languages read the English one. */
export const translationLang = (lang: Lang): 'en' | 'fr' | null => (lang === 'ar' ? null : lang === 'fr' ? 'fr' : 'en')

/** Translation shown in the UI language; none in Arabic (Hisn al-Muslim is translated into English and French only). */
export const translation = (d: Dhikr, lang: Lang) => {
  const l = translationLang(lang)
  return l === 'fr' ? d.fr : l === 'en' ? d.en : null
}

/** "×N" only when the Arabic doesn't already state the count. */
export const badge = (d: Dhikr) => (d.repeat > 1 && !d.count_in_text ? d.repeat : null)

export const chapterTitle = (c: Chapter, lang: Lang) => (lang === 'ar' ? c.ar : lang === 'fr' ? c.fr ?? c.en : c.en)
