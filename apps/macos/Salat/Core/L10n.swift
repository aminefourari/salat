import Foundation

// Strings for the in-app language picker. Shared keys are copied from apps/web/src/lib/i18n.ts.

enum Lang: String, CaseIterable, Codable, Sendable {
    case ar, en, fr
    static var system: Lang {
        let p = Locale.preferredLanguages.first ?? "en"
        return p.hasPrefix("ar") ? .ar : p.hasPrefix("fr") ? .fr : .en
    }
    var locale: Locale { Locale(identifier: rawValue) }
    var isRTL: Bool { self == .ar }
    var nativeName: String { switch self { case .ar: "العربية"; case .en: "English"; case .fr: "Français" } }
}

enum L10nKey: String, CaseIterable, Sendable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha
    case notifStart, notifReminder, next, inTime, today, qibla, settings, locating
    case language, method, auto, asrMethod, standard, hanafi, notifyReminder, approximate
    case qiblaBearing, distance, dirs, dirWords, noCompass
    case quran, quit, stop, openAtLogin, menuBarIconOnly, general, prayerTimes, alerts
    case adhanVoice, fajrVoice, alertAdhan, alertNotification, alertOff, playTest, startedAt
    case reciter, defaultReciter, download, downloadAll, delete, needsInternet, downloading, notDownloaded, retry
    case location, automatic, manualCity, searchCity, locationDenied, noLocation
    case play, pause, previous, nextAyah, chooseSurah, cancel, ayahCount
}

private let en: [L10nKey: String] = [
    .fajr: "Fajr", .sunrise: "Sunrise", .dhuhr: "Dhuhr", .asr: "Asr", .maghrib: "Maghrib", .isha: "Isha",
    .notifStart: "It's time for {prayer} — {time}", .notifReminder: "{prayer} in 10 minutes — {time}",
    .next: "Next", .inTime: "in {time}", .today: "Today", .qibla: "Qibla", .settings: "Settings…", .locating: "Finding your location…",
    .language: "Language", .method: "Calculation method", .auto: "Automatic ({method})",
    .asrMethod: "Asr", .standard: "Standard (Shafiʿi, Maliki, Hanbali)", .hanafi: "Hanafi",
    .notifyReminder: "Remind me 10 minutes before",
    .approximate: "Calculated with the Habous method (Fajr 19°, Isha 17°). May differ from the official timetable by a few minutes.",
    .qiblaBearing: "{deg}° from north", .distance: "{km} km to Makkah",
    .dirs: "N,NE,E,SE,S,SW,W,NW", .dirWords: "north,north-east,east,south-east,south,south-west,west,north-west",
    .noCompass: "Face {deg}° from north ({dir}).",
    .quran: "Quran", .quit: "Quit Salat", .stop: "Stop adhan", .openAtLogin: "Open at login",
    .menuBarIconOnly: "Show only an icon in the menu bar", .general: "General", .prayerTimes: "Prayer times", .alerts: "Adhan & alerts",
    .adhanVoice: "Adhan", .fajrVoice: "Fajr adhan", .alertAdhan: "Adhan", .alertNotification: "Notification only", .alertOff: "Off",
    .playTest: "Play", .startedAt: "{prayer} started at {time}",
    .reciter: "Reciter", .defaultReciter: "Default reciter", .download: "Download", .downloadAll: "Download all",
    .delete: "Delete", .needsInternet: "This surah isn't downloaded yet. Connect to the internet to download it.",
    .downloading: "Downloading…", .notDownloaded: "Not downloaded", .retry: "Retry",
    .location: "Location", .automatic: "Automatic (Location Services)", .manualCity: "Choose a city", .searchCity: "Search a city",
    .locationDenied: "Location isn't available. Allow Salat in System Settings → Privacy & Security → Location Services, or choose a city.",
    .noLocation: "Choose a city in Settings to see prayer times.",
    .play: "Play", .pause: "Pause", .previous: "Previous ayah", .nextAyah: "Next ayah", .chooseSurah: "Choose a surah",
    .cancel: "Cancel", .ayahCount: "{n} ayahs",
]

private let fr: [L10nKey: String] = [
    .fajr: "Fajr", .sunrise: "Lever du soleil", .dhuhr: "Dhuhr", .asr: "Asr", .maghrib: "Maghrib", .isha: "Isha",
    .notifStart: "C'est l'heure de {prayer} — {time}", .notifReminder: "{prayer} dans 10 minutes — {time}",
    .next: "Prochaine", .inTime: "dans {time}", .today: "Aujourd'hui", .qibla: "Qibla", .settings: "Réglages…", .locating: "Recherche de votre position…",
    .language: "Langue", .method: "Méthode de calcul", .auto: "Automatique ({method})",
    .asrMethod: "Asr", .standard: "Standard (chaféite, malikite, hanbalite)", .hanafi: "Hanafite",
    .notifyReminder: "Me rappeler 10 minutes avant",
    .approximate: "Calculé selon la méthode des Habous (Fajr 19°, Isha 17°). Peut différer de quelques minutes de l’horaire officiel.",
    .qiblaBearing: "{deg}° depuis le nord", .distance: "{km} km jusqu’à La Mecque",
    .dirs: "N,NE,E,SE,S,SO,O,NO", .dirWords: "nord,nord-est,est,sud-est,sud,sud-ouest,ouest,nord-ouest",
    .noCompass: "Orientez-vous à {deg}° depuis le nord ({dir}).",
    .quran: "Coran", .quit: "Quitter Salat", .stop: "Arrêter l’adhan", .openAtLogin: "Ouvrir à l’ouverture de session",
    .menuBarIconOnly: "Afficher seulement une icône dans la barre des menus", .general: "Général", .prayerTimes: "Horaires", .alerts: "Adhan et alertes",
    .adhanVoice: "Adhan", .fajrVoice: "Adhan du Fajr", .alertAdhan: "Adhan", .alertNotification: "Notification seule", .alertOff: "Désactivé",
    .playTest: "Écouter", .startedAt: "{prayer} a commencé à {time}",
    .reciter: "Récitateur", .defaultReciter: "Récitateur par défaut", .download: "Télécharger", .downloadAll: "Tout télécharger",
    .delete: "Supprimer", .needsInternet: "Cette sourate n’est pas encore téléchargée. Connectez-vous à Internet pour la télécharger.",
    .downloading: "Téléchargement…", .notDownloaded: "Non téléchargé", .retry: "Réessayer",
    .location: "Position", .automatic: "Automatique (service de localisation)", .manualCity: "Choisir une ville", .searchCity: "Rechercher une ville",
    .locationDenied: "Position indisponible. Autorisez Salat dans Réglages Système → Confidentialité et sécurité → Service de localisation, ou choisissez une ville.",
    .noLocation: "Choisissez une ville dans les réglages pour voir les horaires.",
    .play: "Lecture", .pause: "Pause", .previous: "Verset précédent", .nextAyah: "Verset suivant", .chooseSurah: "Choisissez une sourate",
    .cancel: "Annuler", .ayahCount: "{n} versets",
]

private let ar: [L10nKey: String] = [
    .fajr: "الفجر", .sunrise: "الشروق", .dhuhr: "الظهر", .asr: "العصر", .maghrib: "المغرب", .isha: "العشاء",
    .notifStart: "حان الآن موعد صلاة {prayer} — {time}", .notifReminder: "صلاة {prayer} بعد 10 دقائق — {time}",
    .next: "الصلاة القادمة", .inTime: "بعد {time}", .today: "اليوم", .qibla: "القبلة", .settings: "الإعدادات…", .locating: "جارٍ تحديد موقعك…",
    .language: "اللغة", .method: "طريقة الحساب", .auto: "تلقائي ({method})",
    .asrMethod: "العصر", .standard: "الجمهور (الشافعي، المالكي، الحنبلي)", .hanafi: "الحنفي",
    .notifyReminder: "ذكّرني قبل 10 دقائق",
    .approximate: "محسوبة وفق طريقة وزارة الأوقاف (الفجر \u{2066}19°\u{2069}، العشاء \u{2066}17°\u{2069}). قد تختلف ببضع دقائق عن الجدول الرسمي.",
    .qiblaBearing: "\u{2066}{deg}°\u{2069} من الشمال", .distance: "\u{2066}{km}\u{2069} كم إلى مكة",
    .dirs: "ش,ش ق,ق,ج ق,ج,ج غ,غ,ش غ", .dirWords: "الشمال,الشمال الشرقي,الشرق,الجنوب الشرقي,الجنوب,الجنوب الغربي,الغرب,الشمال الغربي",
    .noCompass: "اتجه \u{2066}{deg}°\u{2069} من الشمال ({dir}).",
    .quran: "القرآن", .quit: "إنهاء Salat", .stop: "إيقاف الأذان", .openAtLogin: "فتح عند تسجيل الدخول",
    .menuBarIconOnly: "إظهار أيقونة فقط في شريط القوائم", .general: "عام", .prayerTimes: "المواقيت", .alerts: "الأذان والتنبيهات",
    .adhanVoice: "الأذان", .fajrVoice: "أذان الفجر", .alertAdhan: "أذان", .alertNotification: "إشعار فقط", .alertOff: "إيقاف",
    .playTest: "تشغيل", .startedAt: "دخل وقت {prayer} الساعة {time}",
    .reciter: "القارئ", .defaultReciter: "القارئ الافتراضي", .download: "تنزيل", .downloadAll: "تنزيل الكل",
    .delete: "حذف", .needsInternet: "هذه السورة غير منزّلة بعد. اتصل بالإنترنت لتنزيلها.",
    .downloading: "جارٍ التنزيل…", .notDownloaded: "غير منزّل", .retry: "إعادة المحاولة",
    .location: "الموقع", .automatic: "تلقائي (خدمات الموقع)", .manualCity: "اختر مدينة", .searchCity: "ابحث عن مدينة",
    .locationDenied: "الموقع غير متاح. اسمح لـ Salat من إعدادات النظام ← الخصوصية والأمان ← خدمات الموقع، أو اختر مدينة.",
    .noLocation: "اختر مدينة من الإعدادات لعرض المواقيت.",
    .play: "تشغيل", .pause: "إيقاف مؤقت", .previous: "الآية السابقة", .nextAyah: "الآية التالية", .chooseSurah: "اختر سورة",
    .cancel: "إلغاء", .ayahCount: "{n} آية",
]

private let dict: [Lang: [L10nKey: String]] = [.en: en, .fr: fr, .ar: ar]

func t(_ key: L10nKey, _ lang: Lang, _ vars: [String: String] = [:]) -> String {
    var s = dict[lang]?[key] ?? en[key] ?? key.rawValue
    for (k, v) in vars { s = s.replacingOccurrences(of: "{\(k)}", with: v) }
    return s
}

func prayerName(_ p: Prayer, _ lang: Lang) -> String { t(L10nKey(rawValue: p.rawValue)!, lang) }

func methodName(_ m: MethodId, _ lang: Lang) -> String {
    let names: [MethodId: (String, String, String)] = [ // en, fr, ar
        .aachen: ("Islamic Center Aachen", "Centre islamique d’Aix-la-Chapelle", "المركز الإسلامي في آخن"),
        .morocco: ("Morocco (Habous)", "Maroc (Habous)", "المغرب (الأوقاف)"),
        .mwl: ("Muslim World League", "Ligue islamique mondiale", "رابطة العالم الإسلامي"),
        .ummalqura: ("Umm al-Qura (Makkah)", "Umm al-Qura (La Mecque)", "أم القرى (مكة)"),
        .uoif: ("UOIF (France)", "UOIF (France)", "اتحاد المنظمات الإسلامية (فرنسا)"),
        .isna: ("ISNA (North America)", "ISNA (Amérique du Nord)", "الجمعية الإسلامية لأمريكا الشمالية"),
        .egyptian: ("Egyptian Authority", "Autorité égyptienne", "الهيئة المصرية"),
        .karachi: ("Karachi", "Karachi", "كراتشي"), .dubai: ("Dubai", "Dubaï", "دبي"), .kuwait: ("Kuwait", "Koweït", "الكويت"),
        .qatar: ("Qatar", "Qatar", "قطر"),
        .singapore: ("Singapore / Malaysia / Indonesia", "Singapour / Malaisie / Indonésie", "سنغافورة / ماليزيا / إندونيسيا"),
        .turkey: ("Diyanet (Turkey)", "Diyanet (Turquie)", "ديانت (تركيا)"), .tehran: ("Tehran", "Téhéran", "طهران"),
    ]
    let n = names[m]!
    return lang == .fr ? n.1 : lang == .ar ? n.2 : n.0
}

/// "HH:mm" in the Mac's current time zone.
func hm(_ d: Date) -> String {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_GB"); f.dateFormat = "HH:mm"; f.timeZone = .autoupdatingCurrent
    return f.string(from: d)
}

/// Countdown "H:MM" (or "M min" under an hour).
func countdown(_ s: TimeInterval) -> String {
    let m = max(0, Int((s / 60).rounded(.up)))
    return m >= 60 ? String(format: "%d:%02d", m / 60, m % 60) : "\(m) min"
}
