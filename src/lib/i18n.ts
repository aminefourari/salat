import type { MethodId } from './methods'
import type { Lang } from './prayer'

const en = {
  fajr: 'Fajr', sunrise: 'Sunrise', dhuhr: 'Dhuhr', asr: 'Asr', maghrib: 'Maghrib', isha: 'Isha',
  'notif.start': "It's time for {prayer} — {time}",
  'notif.reminder': '{prayer} in 10 minutes — {time}',
  next: 'Next', inTime: 'in {time}', today: 'Today', times: 'Times', qibla: 'Qibla', settings: 'Settings',
  locating: 'Finding your location…',
  locationDenied: "Location isn't available. Allow location access for this site, then retry.",
  retry: 'Retry', lastLocation: 'Location: {place} · updated {when}',
  language: 'Language', method: 'Calculation method', auto: 'Automatic ({method})',
  asrMethod: 'Asr', standard: 'Standard (Shafiʿi, Maliki, Hanbali)', hanafi: 'Hanafi',
  notifications: 'Notifications', enable: 'Enable notifications on this device', disable: 'Turn off on this device',
  enabled: 'Notifications are on for this device.', notifyStart: 'At prayer time', notifyReminder: '10 minutes before',
  denied: 'Notifications are blocked. Allow them in your browser or system settings.',
  unsupported: "This browser can't receive notifications.",
  installHint: 'On iPhone: tap Share → “Add to Home Screen”, then open Salat from your Home Screen to enable notifications.',
  approximate: 'Approximate (official timetable unavailable)', official: 'Official Habous timetable',
  qiblaBearing: '{deg}° from north', useCompass: 'Use compass', compassHint: 'Hold your phone flat. The arrow points to the Kaaba.',
  noCompass: 'No compass on this device. Face {deg}° from north.',
  'm.aachen': 'Islamic Center Aachen', 'm.morocco': 'Morocco (Habous)', 'm.mwl': 'Muslim World League',
  'm.ummalqura': 'Umm al-Qura (Makkah)', 'm.uoif': 'UOIF (France)', 'm.isna': 'ISNA (North America)',
  'm.egyptian': 'Egyptian Authority', 'm.karachi': 'Karachi', 'm.dubai': 'Dubai', 'm.kuwait': 'Kuwait',
  'm.qatar': 'Qatar', 'm.singapore': 'Singapore / Malaysia / Indonesia', 'm.turkey': 'Diyanet (Turkey)', 'm.tehran': 'Tehran',
}
type Key = keyof typeof en

const fr: Record<Key, string> = {
  fajr: 'Fajr', sunrise: 'Lever du soleil', dhuhr: 'Dhuhr', asr: 'Asr', maghrib: 'Maghrib', isha: 'Isha',
  'notif.start': "C'est l'heure de {prayer} — {time}",
  'notif.reminder': '{prayer} dans 10 minutes — {time}',
  next: 'Prochaine', inTime: 'dans {time}', today: "Aujourd'hui", times: 'Horaires', qibla: 'Qibla', settings: 'Réglages',
  locating: 'Recherche de votre position…',
  locationDenied: "Position indisponible. Autorisez l'accès à la position pour ce site, puis réessayez.",
  retry: 'Réessayer', lastLocation: 'Position : {place} · mise à jour {when}',
  language: 'Langue', method: 'Méthode de calcul', auto: 'Automatique ({method})',
  asrMethod: 'Asr', standard: 'Standard (chaféite, malikite, hanbalite)', hanafi: 'Hanafite',
  notifications: 'Notifications', enable: 'Activer les notifications sur cet appareil', disable: 'Désactiver sur cet appareil',
  enabled: 'Les notifications sont activées sur cet appareil.', notifyStart: "À l'heure de la prière", notifyReminder: '10 minutes avant',
  denied: 'Les notifications sont bloquées. Autorisez-les dans les réglages du navigateur ou du système.',
  unsupported: 'Ce navigateur ne peut pas recevoir de notifications.',
  installHint: 'Sur iPhone : touchez Partager → « Sur l’écran d’accueil », puis ouvrez Salat depuis l’écran d’accueil pour activer les notifications.',
  approximate: 'Approximatif (horaire officiel indisponible)', official: 'Horaire officiel des Habous',
  qiblaBearing: '{deg}° depuis le nord', useCompass: 'Utiliser la boussole', compassHint: 'Tenez le téléphone à plat. La flèche indique la Kaaba.',
  noCompass: 'Pas de boussole sur cet appareil. Orientez-vous à {deg}° depuis le nord.',
  'm.aachen': 'Centre islamique d’Aix-la-Chapelle', 'm.morocco': 'Maroc (Habous)', 'm.mwl': 'Ligue islamique mondiale',
  'm.ummalqura': 'Umm al-Qura (La Mecque)', 'm.uoif': 'UOIF (France)', 'm.isna': 'ISNA (Amérique du Nord)',
  'm.egyptian': 'Autorité égyptienne', 'm.karachi': 'Karachi', 'm.dubai': 'Dubaï', 'm.kuwait': 'Koweït',
  'm.qatar': 'Qatar', 'm.singapore': 'Singapour / Malaisie / Indonésie', 'm.turkey': 'Diyanet (Turquie)', 'm.tehran': 'Téhéran',
}

const ar: Record<Key, string> = {
  fajr: 'الفجر', sunrise: 'الشروق', dhuhr: 'الظهر', asr: 'العصر', maghrib: 'المغرب', isha: 'العشاء',
  'notif.start': 'حان الآن موعد صلاة {prayer} — {time}',
  'notif.reminder': 'صلاة {prayer} بعد 10 دقائق — {time}',
  next: 'الصلاة القادمة', inTime: 'بعد {time}', today: 'اليوم', times: 'المواقيت', qibla: 'القبلة', settings: 'الإعدادات',
  locating: 'جارٍ تحديد موقعك…',
  locationDenied: 'الموقع غير متاح. اسمح لهذا الموقع بالوصول إلى موقعك ثم أعد المحاولة.',
  retry: 'إعادة المحاولة', lastLocation: 'الموقع: {place} · آخر تحديث {when}',
  language: 'اللغة', method: 'طريقة الحساب', auto: 'تلقائي ({method})',
  asrMethod: 'العصر', standard: 'الجمهور (الشافعي، المالكي، الحنبلي)', hanafi: 'الحنفي',
  notifications: 'الإشعارات', enable: 'تفعيل الإشعارات على هذا الجهاز', disable: 'إيقاف على هذا الجهاز',
  enabled: 'الإشعارات مفعّلة على هذا الجهاز.', notifyStart: 'عند دخول الوقت', notifyReminder: 'قبل 10 دقائق',
  denied: 'الإشعارات محظورة. اسمح بها من إعدادات المتصفح أو النظام.',
  unsupported: 'هذا المتصفح لا يدعم الإشعارات.',
  installHint: 'على الآيفون: اضغط مشاركة ← «إضافة إلى الشاشة الرئيسية»، ثم افتح Salat من الشاشة الرئيسية لتفعيل الإشعارات.',
  approximate: 'تقريبي (الجدول الرسمي غير متاح)', official: 'الجدول الرسمي لوزارة الأوقاف',
  qiblaBearing: '{deg}° من الشمال', useCompass: 'استخدام البوصلة', compassHint: 'ضع الهاتف بشكل مستوٍ. السهم يشير إلى الكعبة.',
  noCompass: 'لا توجد بوصلة في هذا الجهاز. اتجه {deg}° من الشمال.',
  'm.aachen': 'المركز الإسلامي في آخن', 'm.morocco': 'المغرب (الأوقاف)', 'm.mwl': 'رابطة العالم الإسلامي',
  'm.ummalqura': 'أم القرى (مكة)', 'm.uoif': 'اتحاد المنظمات الإسلامية (فرنسا)', 'm.isna': 'الجمعية الإسلامية لأمريكا الشمالية',
  'm.egyptian': 'الهيئة المصرية', 'm.karachi': 'كراتشي', 'm.dubai': 'دبي', 'm.kuwait': 'الكويت',
  'm.qatar': 'قطر', 'm.singapore': 'سنغافورة / ماليزيا / إندونيسيا', 'm.turkey': 'ديانت (تركيا)', 'm.tehran': 'طهران',
}

const DICT: Record<Lang, Record<Key, string>> = { en, fr, ar }
export type I18nKey = Key | `m.${MethodId}`

export function t(lang: Lang, key: I18nKey, vars: Record<string, string | number> = {}): string {
  return (DICT[lang] ?? en)[key as Key].replace(/\{(\w+)\}/g, (_, k) => String(vars[k] ?? ''))
}

export const detectLang = (nav: string | undefined): Lang =>
  nav?.startsWith('ar') ? 'ar' : nav?.startsWith('fr') ? 'fr' : 'en'
