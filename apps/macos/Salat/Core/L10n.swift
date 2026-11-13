import Foundation

// Strings for the in-app language picker. Shared keys are copied from apps/web/src/lib/i18n.ts.

enum Lang: String, CaseIterable, Codable, Sendable {
    case ar, en, fr, de, nl, es, pt, it
    /// The Mac's first preferred language when Salat speaks it, else English.
    static var system: Lang {
        let p = (Locale.preferredLanguages.first ?? "en").lowercased()
        return allCases.first { p.hasPrefix($0.rawValue) } ?? .en
    }
    var locale: Locale { Locale(identifier: rawValue) }
    var isRTL: Bool { self == .ar }
    var nativeName: String {
        switch self {
        case .ar: "العربية"; case .en: "English"; case .fr: "Français"; case .de: "Deutsch"
        case .nl: "Nederlands"; case .es: "Español"; case .pt: "Português"; case .it: "Italiano"
        }
    }
}

enum L10nKey: String, CaseIterable, Sendable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha
    case notifStart, notifReminder, next, inTime, today, qibla, settings, locating
    case language, method, auto, asrMethod, standard, hanafi, notifyReminder, approximate, official
    case qiblaBearing, distance, dirs, dirWords, noCompass
    case quran, quit, stop, openAtLogin, menuBarIconOnly, general, prayerTimes, alerts
    case adhanVoice, fajrVoice, alertAdhan, alertNotification, alertOff, playTest, startedAt
    case reciter, defaultReciter, download, downloadAll, delete, needsInternet, downloading, notDownloaded, retry
    case location, automatic, manualCity, searchCity, locationDenied, noLocation
    case play, pause, previous, nextAyah, chooseSurah, cancel, ayahCount
    case surahs, hizbs, juzN, hizbN, rub1, rub2, rub3, tafsir, loadFailed
    case adhkar, adhkarAudio, searchCategory, chooseCategory, stopAudio, addAdhan
    case notifAdhkarMorning, notifAdhkarEvening, notifKahf, notifJumuah, notifyAdhkar, notifyFriday
    case adjustments, adjustHint, hijriOffset, hijriAuto, days, ramadan, imsak, iftar
    case updates, version, checkForUpdates, checkAutomatically, upToDate, updateAvailable, installUpdate, installing
    case updateFailed, updateCorrupt, updateNotWritable
    case monthly, print, prevMonth, nextMonth, date
    case bookmarks, bookmark, removeBookmark, noBookmarks
}

private let en: [L10nKey: String] = [
    .fajr: "Fajr", .sunrise: "Sunrise", .dhuhr: "Dhuhr", .asr: "Asr", .maghrib: "Maghrib", .isha: "Isha",
    .notifStart: "It's time for {prayer} — {time}", .notifReminder: "{prayer} in 10 minutes — {time}",
    .next: "Next", .inTime: "in {time}", .today: "Today", .qibla: "Qibla", .settings: "Settings…", .locating: "Finding your location…",
    .language: "Language", .method: "Calculation method", .auto: "Automatic ({method})",
    .asrMethod: "Asr", .standard: "Standard (Shafiʿi, Maliki, Hanbali)", .hanafi: "Hanafi",
    .notifyReminder: "Remind me 10 minutes before",
    .approximate: "Calculated with the Habous method (Fajr 19°, Isha 17°). May differ from the official timetable by a few minutes.",
    .official: "Official Habous timetable",
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
    .surahs: "Surahs", .hizbs: "Hizbs", .juzN: "Juz {n}", .hizbN: "Hizb {n}", .rub1: "¼ Hizb {n}", .rub2: "½ Hizb {n}", .rub3: "¾ Hizb {n}",
    .tafsir: "Tafsir", .loadFailed: "Couldn't load. Check your connection.",
    .adhkar: "Adhkar", .adhkarAudio: "Adhkar audio", .searchCategory: "Search", .chooseCategory: "Choose a category", .stopAudio: "Stop", .addAdhan: "Add your own…",
    .notifAdhkarMorning: "Morning adhkar — click to read them", .notifAdhkarEvening: "Evening adhkar — click to read them",
    .notifKahf: "It's Friday: read Surat al-Kahf — click to open it", .notifJumuah: "Jumuʿah today — Dhuhr at {time}",
    .notifyAdhkar: "Morning and evening adhkar", .notifyFriday: "Friday: Surat al-Kahf and Jumuʿah",
    .adjustments: "Adjust times (minutes)", .adjustHint: "Add or remove minutes to match your mosque.",
    .hijriOffset: "Hijri date", .hijriAuto: "Automatic ({n})", .days: "{n} days",
    .ramadan: "Ramadan", .imsak: "Imsak", .iftar: "Iftar",
    .updates: "Updates", .version: "Version {v}", .checkForUpdates: "Check for updates", .checkAutomatically: "Check for updates automatically",
    .upToDate: "Salat is up to date.", .updateAvailable: "Salat {v} is available", .installUpdate: "Install and relaunch",
    .installing: "Installing…", .updateFailed: "Couldn't check for updates. Try again later.",
    .updateCorrupt: "The download was damaged, so it wasn't installed. Try again.",
    .updateNotWritable: "Salat can't replace itself in this folder. Move it to Applications, or download the update from GitHub.",
    .monthly: "Monthly timetable", .print: "Print…", .prevMonth: "Previous month", .nextMonth: "Next month", .date: "Date",
    .bookmarks: "Bookmarks", .bookmark: "Bookmark", .removeBookmark: "Remove bookmark", .noBookmarks: "No bookmarks yet. Use Bookmark under an ayah to save it.",
]

private let fr: [L10nKey: String] = [
    .fajr: "Fajr", .sunrise: "Lever du soleil", .dhuhr: "Dhuhr", .asr: "Asr", .maghrib: "Maghrib", .isha: "Isha",
    .notifStart: "C'est l'heure de {prayer} — {time}", .notifReminder: "{prayer} dans 10 minutes — {time}",
    .next: "Prochaine", .inTime: "dans {time}", .today: "Aujourd'hui", .qibla: "Qibla", .settings: "Réglages…", .locating: "Recherche de votre position…",
    .language: "Langue", .method: "Méthode de calcul", .auto: "Automatique ({method})",
    .asrMethod: "Asr", .standard: "Standard (chaféite, malikite, hanbalite)", .hanafi: "Hanafite",
    .notifyReminder: "Me rappeler 10 minutes avant",
    .approximate: "Calculé selon la méthode des Habous (Fajr 19°, Isha 17°). Peut différer de quelques minutes de l’horaire officiel.",
    .official: "Horaire officiel des Habous",
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
    .surahs: "Sourates", .hizbs: "Hizbs", .juzN: "Juz {n}", .hizbN: "Hizb {n}", .rub1: "¼ du hizb {n}", .rub2: "½ du hizb {n}", .rub3: "¾ du hizb {n}",
    .tafsir: "Tafsir", .loadFailed: "Chargement impossible. Vérifiez votre connexion.",
    .adhkar: "Adhkar", .adhkarAudio: "Audio des adhkar", .searchCategory: "Rechercher", .chooseCategory: "Choisissez une catégorie", .stopAudio: "Arrêter", .addAdhan: "Ajouter le vôtre…",
    .notifAdhkarMorning: "Adhkar du matin — cliquez pour les lire", .notifAdhkarEvening: "Adhkar du soir — cliquez pour les lire",
    .notifKahf: "C'est vendredi : lisez la sourate al-Kahf — cliquez pour l'ouvrir", .notifJumuah: "Joumouʿa aujourd'hui — Dhuhr à {time}",
    .notifyAdhkar: "Adhkar du matin et du soir", .notifyFriday: "Vendredi : sourate al-Kahf et Joumouʿa",
    .adjustments: "Ajuster les horaires (minutes)", .adjustHint: "Ajoutez ou retirez des minutes pour suivre votre mosquée.",
    .hijriOffset: "Date hégirienne", .hijriAuto: "Automatique ({n})", .days: "{n} jours",
    .ramadan: "Ramadan", .imsak: "Imsak", .iftar: "Iftar",
    .updates: "Mises à jour", .version: "Version {v}", .checkForUpdates: "Rechercher des mises à jour", .checkAutomatically: "Rechercher automatiquement les mises à jour",
    .upToDate: "Salat est à jour.", .updateAvailable: "Salat {v} est disponible", .installUpdate: "Installer et relancer",
    .installing: "Installation…", .updateFailed: "Impossible de rechercher les mises à jour. Réessayez plus tard.",
    .updateCorrupt: "Le téléchargement était endommagé : rien n’a été installé. Réessayez.",
    .updateNotWritable: "Salat ne peut pas se remplacer dans ce dossier. Placez-le dans Applications, ou téléchargez la mise à jour sur GitHub.",
    .monthly: "Horaires du mois", .print: "Imprimer…", .prevMonth: "Mois précédent", .nextMonth: "Mois suivant", .date: "Date",
    .bookmarks: "Signets", .bookmark: "Marquer", .removeBookmark: "Retirer le signet", .noBookmarks: "Aucun signet. Utilisez « Marquer » sous un verset pour l’enregistrer.",
]

private let ar: [L10nKey: String] = [
    .fajr: "الفجر", .sunrise: "الشروق", .dhuhr: "الظهر", .asr: "العصر", .maghrib: "المغرب", .isha: "العشاء",
    .notifStart: "حان الآن موعد صلاة {prayer} — {time}", .notifReminder: "صلاة {prayer} بعد 10 دقائق — {time}",
    .next: "الصلاة القادمة", .inTime: "بعد {time}", .today: "اليوم", .qibla: "القبلة", .settings: "الإعدادات…", .locating: "جارٍ تحديد موقعك…",
    .language: "اللغة", .method: "طريقة الحساب", .auto: "تلقائي ({method})",
    .asrMethod: "العصر", .standard: "الجمهور (الشافعي، المالكي، الحنبلي)", .hanafi: "الحنفي",
    .notifyReminder: "ذكّرني قبل 10 دقائق",
    .approximate: "محسوبة وفق طريقة وزارة الأوقاف (الفجر \u{2066}19°\u{2069}، العشاء \u{2066}17°\u{2069}). قد تختلف ببضع دقائق عن الجدول الرسمي.",
    .official: "الجدول الرسمي لوزارة الأوقاف",
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
    .surahs: "السور", .hizbs: "الأحزاب", .juzN: "الجزء {n}", .hizbN: "الحزب {n}", .rub1: "ربع الحزب {n}", .rub2: "نصف الحزب {n}", .rub3: "ثلاثة أرباع الحزب {n}",
    .tafsir: "التفسير", .loadFailed: "تعذّر التحميل. تحقق من اتصالك.",
    .adhkar: "الأذكار", .adhkarAudio: "صوتيات الأذكار", .searchCategory: "بحث", .chooseCategory: "اختر بابًا", .stopAudio: "إيقاف", .addAdhan: "إضافة أذان خاص…",
    .notifAdhkarMorning: "أذكار الصباح — انقر لقراءتها", .notifAdhkarEvening: "أذكار المساء — انقر لقراءتها",
    .notifKahf: "اليوم الجمعة: اقرأ سورة الكهف — انقر لفتحها", .notifJumuah: "صلاة الجمعة اليوم — الظهر الساعة {time}",
    .notifyAdhkar: "أذكار الصباح والمساء", .notifyFriday: "الجمعة: سورة الكهف وصلاة الجمعة",
    .adjustments: "تعديل المواقيت (بالدقائق)", .adjustHint: "أضف أو أنقص دقائق لتوافق مسجدك.",
    .hijriOffset: "التاريخ الهجري", .hijriAuto: "تلقائي ({n})", .days: "{n} أيام",
    .ramadan: "رمضان", .imsak: "الإمساك", .iftar: "الإفطار",
    .updates: "التحديثات", .version: "الإصدار {v}", .checkForUpdates: "البحث عن تحديثات", .checkAutomatically: "البحث عن التحديثات تلقائيًا",
    .upToDate: "Salat محدّث.", .updateAvailable: "الإصدار {v} من Salat متاح", .installUpdate: "تثبيت وإعادة التشغيل",
    .installing: "جارٍ التثبيت…", .updateFailed: "تعذّر البحث عن التحديثات. أعد المحاولة لاحقًا.",
    .updateCorrupt: "التنزيل تالف، فلم يُثبَّت. أعد المحاولة.",
    .updateNotWritable: "لا يستطيع Salat استبدال نفسه في هذا المجلد. انقله إلى مجلد التطبيقات، أو نزّل التحديث من GitHub.",
    .monthly: "مواقيت الشهر", .print: "طباعة…", .prevMonth: "الشهر السابق", .nextMonth: "الشهر التالي", .date: "التاريخ",
    .bookmarks: "العلامات", .bookmark: "حفظ", .removeBookmark: "إزالة العلامة", .noBookmarks: "لا توجد علامات بعد. استخدم «حفظ» تحت أي آية.",
]

private let de: [L10nKey: String] = [
    .fajr: "Fajr", .sunrise: "Sonnenaufgang", .dhuhr: "Dhuhr", .asr: "Asr", .maghrib: "Maghrib", .isha: "Isha",
    .notifStart: "Es ist Zeit für {prayer} — {time}", .notifReminder: "{prayer} in 10 Minuten — {time}",
    .next: "Nächstes", .inTime: "in {time}", .today: "Heute", .qibla: "Qibla", .settings: "Einstellungen…", .locating: "Standort wird ermittelt…",
    .language: "Sprache", .method: "Berechnungsmethode", .auto: "Automatisch ({method})",
    .asrMethod: "Asr", .standard: "Standard (Schafiʿi, Maliki, Hanbali)", .hanafi: "Hanafi",
    .notifyReminder: "10 Minuten vorher erinnern",
    .approximate: "Berechnet nach der Habous-Methode (Fajr 19°, Isha 17°). Kann um einige Minuten vom offiziellen Zeitplan abweichen.",
    .official: "Offizieller Habous-Zeitplan",
    .qiblaBearing: "{deg}° von Norden", .distance: "{km} km bis Mekka",
    .dirs: "N,NO,O,SO,S,SW,W,NW", .dirWords: "Norden,Nordosten,Osten,Südosten,Süden,Südwesten,Westen,Nordwesten",
    .noCompass: "Richte dich {deg}° von Norden aus ({dir}).",
    .quran: "Koran", .quit: "Salat beenden", .stop: "Adhan stoppen", .openAtLogin: "Bei der Anmeldung öffnen",
    .menuBarIconOnly: "Nur ein Symbol in der Menüleiste zeigen", .general: "Allgemein", .prayerTimes: "Gebetszeiten", .alerts: "Adhan & Hinweise",
    .adhanVoice: "Adhan", .fajrVoice: "Fajr-Adhan", .alertAdhan: "Adhan", .alertNotification: "Nur Mitteilung", .alertOff: "Aus",
    .playTest: "Abspielen", .startedAt: "{prayer} hat um {time} begonnen",
    .reciter: "Rezitator", .defaultReciter: "Standard-Rezitator", .download: "Laden", .downloadAll: "Alle laden",
    .delete: "Löschen", .needsInternet: "Diese Sure ist noch nicht geladen. Verbinde dich mit dem Internet, um sie zu laden.",
    .downloading: "Wird geladen…", .notDownloaded: "Nicht geladen", .retry: "Erneut versuchen",
    .location: "Standort", .automatic: "Automatisch (Ortungsdienste)", .manualCity: "Stadt wählen", .searchCity: "Stadt suchen",
    .locationDenied: "Standort nicht verfügbar. Erlaube Salat unter Systemeinstellungen → Datenschutz & Sicherheit → Ortungsdienste, oder wähle eine Stadt.",
    .noLocation: "Wähle in den Einstellungen eine Stadt, um die Gebetszeiten zu sehen.",
    .play: "Abspielen", .pause: "Pause", .previous: "Vorheriger Vers", .nextAyah: "Nächster Vers", .chooseSurah: "Wähle eine Sure",
    .cancel: "Abbrechen", .ayahCount: "{n} Verse",
    .surahs: "Suren", .hizbs: "Hizbs", .juzN: "Dschuz {n}", .hizbN: "Hizb {n}", .rub1: "¼ Hizb {n}", .rub2: "½ Hizb {n}", .rub3: "¾ Hizb {n}",
    .tafsir: "Tafsir", .loadFailed: "Laden fehlgeschlagen. Prüfe deine Verbindung.",
    .adhkar: "Adhkar", .adhkarAudio: "Adhkar-Audio", .searchCategory: "Suchen", .chooseCategory: "Wähle eine Kategorie", .stopAudio: "Stopp", .addAdhan: "Eigenen hinzufügen…",
    .notifAdhkarMorning: "Morgen-Adhkar — klicke, um sie zu lesen", .notifAdhkarEvening: "Abend-Adhkar — klicke, um sie zu lesen",
    .notifKahf: "Es ist Freitag: lies Sura al-Kahf — klicke, um sie zu öffnen", .notifJumuah: "Heute Dschumuʿa — Dhuhr um {time}",
    .notifyAdhkar: "Morgen- und Abend-Adhkar", .notifyFriday: "Freitag: Sura al-Kahf und Dschumuʿa",
    .adjustments: "Zeiten anpassen (Minuten)", .adjustHint: "Minuten hinzufügen oder abziehen, passend zu deiner Moschee.",
    .hijriOffset: "Hidschri-Datum", .hijriAuto: "Automatisch ({n})", .days: "{n} Tage",
    .ramadan: "Ramadan", .imsak: "Imsak", .iftar: "Iftar",
    .updates: "Updates", .version: "Version {v}", .checkForUpdates: "Nach Updates suchen", .checkAutomatically: "Automatisch nach Updates suchen",
    .upToDate: "Salat ist auf dem neuesten Stand.", .updateAvailable: "Salat {v} ist verfügbar", .installUpdate: "Installieren und neu starten",
    .installing: "Wird installiert…", .updateFailed: "Suche nach Updates fehlgeschlagen. Versuche es später erneut.",
    .updateCorrupt: "Der Download war beschädigt und wurde nicht installiert. Versuche es erneut.",
    .updateNotWritable: "Salat kann sich in diesem Ordner nicht ersetzen. Verschiebe es in „Programme“ oder lade das Update von GitHub.",
    .monthly: "Monatsplan", .print: "Drucken…", .prevMonth: "Vorheriger Monat", .nextMonth: "Nächster Monat", .date: "Datum",
    .bookmarks: "Lesezeichen", .bookmark: "Merken", .removeBookmark: "Lesezeichen entfernen", .noBookmarks: "Noch keine Lesezeichen. Nutze „Merken“ unter einem Vers.",
]

private let nl: [L10nKey: String] = [
    .fajr: "Fajr", .sunrise: "Zonsopgang", .dhuhr: "Dhuhr", .asr: "Asr", .maghrib: "Maghrib", .isha: "Isha",
    .notifStart: "Het is tijd voor {prayer} — {time}", .notifReminder: "{prayer} over 10 minuten — {time}",
    .next: "Volgende", .inTime: "over {time}", .today: "Vandaag", .qibla: "Qibla", .settings: "Instellingen…", .locating: "Je locatie wordt bepaald…",
    .language: "Taal", .method: "Berekeningsmethode", .auto: "Automatisch ({method})",
    .asrMethod: "Asr", .standard: "Standaard (Shafiʿi, Maliki, Hanbali)", .hanafi: "Hanafi",
    .notifyReminder: "Herinner me 10 minuten van tevoren",
    .approximate: "Berekend met de Habous-methode (Fajr 19°, Isha 17°). Kan enkele minuten afwijken van het officiële rooster.",
    .official: "Officieel Habous-rooster",
    .qiblaBearing: "{deg}° vanaf het noorden", .distance: "{km} km naar Mekka",
    .dirs: "N,NO,O,ZO,Z,ZW,W,NW", .dirWords: "noorden,noordoosten,oosten,zuidoosten,zuiden,zuidwesten,westen,noordwesten",
    .noCompass: "Richt je op {deg}° vanaf het noorden ({dir}).",
    .quran: "Koran", .quit: "Stop Salat", .stop: "Adhan stoppen", .openAtLogin: "Openen bij inloggen",
    .menuBarIconOnly: "Alleen een symbool in de menubalk tonen", .general: "Algemeen", .prayerTimes: "Gebedstijden", .alerts: "Adhan & meldingen",
    .adhanVoice: "Adhan", .fajrVoice: "Fajr-adhan", .alertAdhan: "Adhan", .alertNotification: "Alleen melding", .alertOff: "Uit",
    .playTest: "Afspelen", .startedAt: "{prayer} begon om {time}",
    .reciter: "Reciteur", .defaultReciter: "Standaardreciteur", .download: "Downloaden", .downloadAll: "Alles downloaden",
    .delete: "Verwijderen", .needsInternet: "Deze soera is nog niet gedownload. Maak verbinding met internet om haar te downloaden.",
    .downloading: "Downloaden…", .notDownloaded: "Niet gedownload", .retry: "Opnieuw proberen",
    .location: "Locatie", .automatic: "Automatisch (locatievoorzieningen)", .manualCity: "Kies een stad", .searchCity: "Zoek een stad",
    .locationDenied: "Locatie niet beschikbaar. Sta Salat toe in Systeeminstellingen → Privacy en beveiliging → Locatievoorzieningen, of kies een stad.",
    .noLocation: "Kies een stad in Instellingen om de gebedstijden te zien.",
    .play: "Afspelen", .pause: "Pauze", .previous: "Vorig vers", .nextAyah: "Volgend vers", .chooseSurah: "Kies een soera",
    .cancel: "Annuleren", .ayahCount: "{n} verzen",
    .surahs: "Soera’s", .hizbs: "Hizbs", .juzN: "Djoez {n}", .hizbN: "Hizb {n}", .rub1: "¼ hizb {n}", .rub2: "½ hizb {n}", .rub3: "¾ hizb {n}",
    .tafsir: "Tafsir", .loadFailed: "Laden mislukt. Controleer je verbinding.",
    .adhkar: "Adhkar", .adhkarAudio: "Adhkar-audio", .searchCategory: "Zoeken", .chooseCategory: "Kies een categorie", .stopAudio: "Stop", .addAdhan: "Eigen toevoegen…",
    .notifAdhkarMorning: "Ochtend-adhkar — klik om ze te lezen", .notifAdhkarEvening: "Avond-adhkar — klik om ze te lezen",
    .notifKahf: "Het is vrijdag: lees soera al-Kahf — klik om haar te openen", .notifJumuah: "Vandaag Djoemoeʿa — Dhuhr om {time}",
    .notifyAdhkar: "Ochtend- en avond-adhkar", .notifyFriday: "Vrijdag: soera al-Kahf en Djoemoeʿa",
    .adjustments: "Tijden aanpassen (minuten)", .adjustHint: "Tel minuten op of af zodat het klopt met je moskee.",
    .hijriOffset: "Hidjri-datum", .hijriAuto: "Automatisch ({n})", .days: "{n} dagen",
    .ramadan: "Ramadan", .imsak: "Imsak", .iftar: "Iftar",
    .updates: "Updates", .version: "Versie {v}", .checkForUpdates: "Zoek naar updates", .checkAutomatically: "Automatisch naar updates zoeken",
    .upToDate: "Salat is up-to-date.", .updateAvailable: "Salat {v} is beschikbaar", .installUpdate: "Installeren en herstarten",
    .installing: "Installeren…", .updateFailed: "Zoeken naar updates mislukt. Probeer het later opnieuw.",
    .updateCorrupt: "De download was beschadigd en is niet geïnstalleerd. Probeer het opnieuw.",
    .updateNotWritable: "Salat kan zichzelf in deze map niet vervangen. Zet het in Apps, of download de update van GitHub.",
    .monthly: "Maandrooster", .print: "Afdrukken…", .prevMonth: "Vorige maand", .nextMonth: "Volgende maand", .date: "Datum",
    .bookmarks: "Bladwijzers", .bookmark: "Bewaren", .removeBookmark: "Bladwijzer verwijderen", .noBookmarks: "Nog geen bladwijzers. Gebruik ‘Bewaren’ onder een vers.",
]

private let es: [L10nKey: String] = [
    .fajr: "Fajr", .sunrise: "Amanecer", .dhuhr: "Dhuhr", .asr: "Asr", .maghrib: "Maghrib", .isha: "Isha",
    .notifStart: "Es la hora de {prayer} — {time}", .notifReminder: "{prayer} en 10 minutos — {time}",
    .next: "Siguiente", .inTime: "en {time}", .today: "Hoy", .qibla: "Qibla", .settings: "Ajustes…", .locating: "Buscando tu ubicación…",
    .language: "Idioma", .method: "Método de cálculo", .auto: "Automático ({method})",
    .asrMethod: "Asr", .standard: "Estándar (shafiʿí, malikí, hanbalí)", .hanafi: "Hanafí",
    .notifyReminder: "Avisarme 10 minutos antes",
    .approximate: "Calculado con el método Habous (Fajr 19°, Isha 17°). Puede diferir unos minutos del horario oficial.",
    .official: "Horario oficial de Habous",
    .qiblaBearing: "{deg}° desde el norte", .distance: "{km} km hasta La Meca",
    .dirs: "N,NE,E,SE,S,SO,O,NO", .dirWords: "norte,noreste,este,sureste,sur,suroeste,oeste,noroeste",
    .noCompass: "Oriéntate a {deg}° desde el norte ({dir}).",
    .quran: "Corán", .quit: "Salir de Salat", .stop: "Detener el adhan", .openAtLogin: "Abrir al iniciar sesión",
    .menuBarIconOnly: "Mostrar solo un icono en la barra de menús", .general: "General", .prayerTimes: "Horarios de rezo", .alerts: "Adhan y avisos",
    .adhanVoice: "Adhan", .fajrVoice: "Adhan del Fajr", .alertAdhan: "Adhan", .alertNotification: "Solo notificación", .alertOff: "Desactivado",
    .playTest: "Reproducir", .startedAt: "{prayer} comenzó a las {time}",
    .reciter: "Recitador", .defaultReciter: "Recitador predeterminado", .download: "Descargar", .downloadAll: "Descargar todo",
    .delete: "Eliminar", .needsInternet: "Esta sura aún no está descargada. Conéctate a internet para descargarla.",
    .downloading: "Descargando…", .notDownloaded: "No descargada", .retry: "Reintentar",
    .location: "Ubicación", .automatic: "Automática (Localización)", .manualCity: "Elegir una ciudad", .searchCity: "Buscar una ciudad",
    .locationDenied: "Ubicación no disponible. Permite Salat en Ajustes del Sistema → Privacidad y seguridad → Localización, o elige una ciudad.",
    .noLocation: "Elige una ciudad en Ajustes para ver los horarios de rezo.",
    .play: "Reproducir", .pause: "Pausa", .previous: "Aleya anterior", .nextAyah: "Aleya siguiente", .chooseSurah: "Elige una sura",
    .cancel: "Cancelar", .ayahCount: "{n} aleyas",
    .surahs: "Suras", .hizbs: "Hizbs", .juzN: "Yuz {n}", .hizbN: "Hizb {n}", .rub1: "¼ del hizb {n}", .rub2: "½ del hizb {n}", .rub3: "¾ del hizb {n}",
    .tafsir: "Tafsir", .loadFailed: "No se pudo cargar. Comprueba tu conexión.",
    .adhkar: "Adhkar", .adhkarAudio: "Audio de los adhkar", .searchCategory: "Buscar", .chooseCategory: "Elige una categoría", .stopAudio: "Detener", .addAdhan: "Añadir uno propio…",
    .notifAdhkarMorning: "Adhkar de la mañana — haz clic para leerlos", .notifAdhkarEvening: "Adhkar de la tarde — haz clic para leerlos",
    .notifKahf: "Es viernes: lee la sura al-Kahf — haz clic para abrirla", .notifJumuah: "Hoy hay Yumuʿa — Dhuhr a las {time}",
    .notifyAdhkar: "Adhkar de la mañana y de la tarde", .notifyFriday: "Viernes: sura al-Kahf y Yumuʿa",
    .adjustments: "Ajustar horarios (minutos)", .adjustHint: "Suma o resta minutos para que coincidan con tu mezquita.",
    .hijriOffset: "Fecha de la Hégira", .hijriAuto: "Automático ({n})", .days: "{n} días",
    .ramadan: "Ramadán", .imsak: "Imsak", .iftar: "Iftar",
    .updates: "Actualizaciones", .version: "Versión {v}", .checkForUpdates: "Buscar actualizaciones", .checkAutomatically: "Buscar actualizaciones automáticamente",
    .upToDate: "Salat está actualizado.", .updateAvailable: "Salat {v} está disponible", .installUpdate: "Instalar y reiniciar",
    .installing: "Instalando…", .updateFailed: "No se pudieron buscar actualizaciones. Inténtalo más tarde.",
    .updateCorrupt: "La descarga estaba dañada y no se instaló. Vuelve a intentarlo.",
    .updateNotWritable: "Salat no puede reemplazarse en esta carpeta. Muévelo a Aplicaciones o descarga la actualización desde GitHub.",
    .monthly: "Horario mensual", .print: "Imprimir…", .prevMonth: "Mes anterior", .nextMonth: "Mes siguiente", .date: "Fecha",
    .bookmarks: "Marcadores", .bookmark: "Guardar", .removeBookmark: "Quitar marcador", .noBookmarks: "Aún no hay marcadores. Usa «Guardar» bajo una aleya.",
]

private let pt: [L10nKey: String] = [
    .fajr: "Fajr", .sunrise: "Nascer do sol", .dhuhr: "Dhuhr", .asr: "Asr", .maghrib: "Maghrib", .isha: "Isha",
    .notifStart: "É hora de {prayer} — {time}", .notifReminder: "{prayer} em 10 minutos — {time}",
    .next: "Próxima", .inTime: "em {time}", .today: "Hoje", .qibla: "Qibla", .settings: "Ajustes…", .locating: "Procurando sua localização…",
    .language: "Idioma", .method: "Método de cálculo", .auto: "Automático ({method})",
    .asrMethod: "Asr", .standard: "Padrão (shafiʿi, maliki, hanbali)", .hanafi: "Hanafi",
    .notifyReminder: "Lembrar 10 minutos antes",
    .approximate: "Calculado pelo método Habous (Fajr 19°, Isha 17°). Pode diferir alguns minutos do horário oficial.",
    .official: "Horário oficial do Habous",
    .qiblaBearing: "{deg}° a partir do norte", .distance: "{km} km até Meca",
    .dirs: "N,NE,L,SE,S,SO,O,NO", .dirWords: "norte,nordeste,leste,sudeste,sul,sudoeste,oeste,noroeste",
    .noCompass: "Vire-se para {deg}° a partir do norte ({dir}).",
    .quran: "Alcorão", .quit: "Encerrar o Salat", .stop: "Parar o adhan", .openAtLogin: "Abrir ao iniciar sessão",
    .menuBarIconOnly: "Mostrar só um ícone na barra de menus", .general: "Geral", .prayerTimes: "Horários de oração", .alerts: "Adhan e avisos",
    .adhanVoice: "Adhan", .fajrVoice: "Adhan do Fajr", .alertAdhan: "Adhan", .alertNotification: "Só notificação", .alertOff: "Desativado",
    .playTest: "Reproduzir", .startedAt: "{prayer} começou às {time}",
    .reciter: "Recitador", .defaultReciter: "Recitador padrão", .download: "Baixar", .downloadAll: "Baixar tudo",
    .delete: "Apagar", .needsInternet: "Esta surata ainda não foi baixada. Conecte-se à internet para baixá-la.",
    .downloading: "Baixando…", .notDownloaded: "Não baixada", .retry: "Tentar de novo",
    .location: "Localização", .automatic: "Automática (Serviços de Localização)", .manualCity: "Escolher uma cidade", .searchCity: "Pesquisar uma cidade",
    .locationDenied: "Localização indisponível. Permita o Salat em Ajustes do Sistema → Privacidade e Segurança → Serviços de Localização, ou escolha uma cidade.",
    .noLocation: "Escolha uma cidade nos Ajustes para ver os horários de oração.",
    .play: "Reproduzir", .pause: "Pausar", .previous: "Versículo anterior", .nextAyah: "Próximo versículo", .chooseSurah: "Escolha uma surata",
    .cancel: "Cancelar", .ayahCount: "{n} versículos",
    .surahs: "Suratas", .hizbs: "Hizbs", .juzN: "Juz {n}", .hizbN: "Hizb {n}", .rub1: "¼ do hizb {n}", .rub2: "½ do hizb {n}", .rub3: "¾ do hizb {n}",
    .tafsir: "Tafsir", .loadFailed: "Não foi possível carregar. Verifique sua conexão.",
    .adhkar: "Adhkar", .adhkarAudio: "Áudio dos adhkar", .searchCategory: "Pesquisar", .chooseCategory: "Escolha uma categoria", .stopAudio: "Parar", .addAdhan: "Adicionar o seu…",
    .notifAdhkarMorning: "Adhkar da manhã — clique para lê-los", .notifAdhkarEvening: "Adhkar da tarde — clique para lê-los",
    .notifKahf: "É sexta-feira: leia a surata al-Kahf — clique para abri-la", .notifJumuah: "Jumuʿa hoje — Dhuhr às {time}",
    .notifyAdhkar: "Adhkar da manhã e da tarde", .notifyFriday: "Sexta-feira: surata al-Kahf e Jumuʿa",
    .adjustments: "Ajustar horários (minutos)", .adjustHint: "Adicione ou tire minutos para coincidir com a sua mesquita.",
    .hijriOffset: "Data da Hégira", .hijriAuto: "Automático ({n})", .days: "{n} dias",
    .ramadan: "Ramadã", .imsak: "Imsak", .iftar: "Iftar",
    .updates: "Atualizações", .version: "Versão {v}", .checkForUpdates: "Procurar atualizações", .checkAutomatically: "Procurar atualizações automaticamente",
    .upToDate: "O Salat está atualizado.", .updateAvailable: "O Salat {v} está disponível", .installUpdate: "Instalar e reabrir",
    .installing: "Instalando…", .updateFailed: "Não foi possível procurar atualizações. Tente mais tarde.",
    .updateCorrupt: "O download estava danificado e não foi instalado. Tente de novo.",
    .updateNotWritable: "O Salat não pode se substituir nesta pasta. Mova-o para Aplicativos ou baixe a atualização no GitHub.",
    .monthly: "Horário mensal", .print: "Imprimir…", .prevMonth: "Mês anterior", .nextMonth: "Próximo mês", .date: "Data",
    .bookmarks: "Marcadores", .bookmark: "Salvar", .removeBookmark: "Remover marcador", .noBookmarks: "Ainda não há marcadores. Use “Salvar” abaixo de um versículo.",
]

private let it: [L10nKey: String] = [
    .fajr: "Fajr", .sunrise: "Alba", .dhuhr: "Dhuhr", .asr: "Asr", .maghrib: "Maghrib", .isha: "Isha",
    .notifStart: "È l’ora di {prayer} — {time}", .notifReminder: "{prayer} tra 10 minuti — {time}",
    .next: "Prossima", .inTime: "tra {time}", .today: "Oggi", .qibla: "Qibla", .settings: "Impostazioni…", .locating: "Ricerca della tua posizione…",
    .language: "Lingua", .method: "Metodo di calcolo", .auto: "Automatico ({method})",
    .asrMethod: "Asr", .standard: "Standard (sciafiʿita, malikita, hanbalita)", .hanafi: "Hanafita",
    .notifyReminder: "Avvisami 10 minuti prima",
    .approximate: "Calcolato con il metodo Habous (Fajr 19°, Isha 17°). Può differire di qualche minuto dall’orario ufficiale.",
    .official: "Orario ufficiale Habous",
    .qiblaBearing: "{deg}° da nord", .distance: "{km} km dalla Mecca",
    .dirs: "N,NE,E,SE,S,SO,O,NO", .dirWords: "nord,nord-est,est,sud-est,sud,sud-ovest,ovest,nord-ovest",
    .noCompass: "Orientati a {deg}° da nord ({dir}).",
    .quran: "Corano", .quit: "Esci da Salat", .stop: "Ferma l’adhan", .openAtLogin: "Apri al login",
    .menuBarIconOnly: "Mostra solo un’icona nella barra dei menu", .general: "Generali", .prayerTimes: "Orari di preghiera", .alerts: "Adhan e avvisi",
    .adhanVoice: "Adhan", .fajrVoice: "Adhan del Fajr", .alertAdhan: "Adhan", .alertNotification: "Solo notifica", .alertOff: "Disattivato",
    .playTest: "Riproduci", .startedAt: "{prayer} è iniziata alle {time}",
    .reciter: "Recitatore", .defaultReciter: "Recitatore predefinito", .download: "Scarica", .downloadAll: "Scarica tutto",
    .delete: "Elimina", .needsInternet: "Questa sura non è ancora scaricata. Connettiti a internet per scaricarla.",
    .downloading: "Download in corso…", .notDownloaded: "Non scaricata", .retry: "Riprova",
    .location: "Posizione", .automatic: "Automatica (Localizzazione)", .manualCity: "Scegli una città", .searchCity: "Cerca una città",
    .locationDenied: "Posizione non disponibile. Consenti Salat in Impostazioni di Sistema → Privacy e sicurezza → Localizzazione, oppure scegli una città.",
    .noLocation: "Scegli una città nelle Impostazioni per vedere gli orari di preghiera.",
    .play: "Riproduci", .pause: "Pausa", .previous: "Versetto precedente", .nextAyah: "Versetto successivo", .chooseSurah: "Scegli una sura",
    .cancel: "Annulla", .ayahCount: "{n} versetti",
    .surahs: "Sure", .hizbs: "Hizb", .juzN: "Juz {n}", .hizbN: "Hizb {n}", .rub1: "¼ dell’hizb {n}", .rub2: "½ dell’hizb {n}", .rub3: "¾ dell’hizb {n}",
    .tafsir: "Tafsir", .loadFailed: "Impossibile caricare. Controlla la connessione.",
    .adhkar: "Adhkar", .adhkarAudio: "Audio degli adhkar", .searchCategory: "Cerca", .chooseCategory: "Scegli una categoria", .stopAudio: "Ferma", .addAdhan: "Aggiungi il tuo…",
    .notifAdhkarMorning: "Adhkar del mattino — fai clic per leggerli", .notifAdhkarEvening: "Adhkar della sera — fai clic per leggerli",
    .notifKahf: "È venerdì: leggi la sura al-Kahf — fai clic per aprirla", .notifJumuah: "Oggi c’è la Jumuʿa — Dhuhr alle {time}",
    .notifyAdhkar: "Adhkar del mattino e della sera", .notifyFriday: "Venerdì: sura al-Kahf e Jumuʿa",
    .adjustments: "Regola gli orari (minuti)", .adjustHint: "Aggiungi o togli minuti per allinearti alla tua moschea.",
    .hijriOffset: "Data dell’Egira", .hijriAuto: "Automatica ({n})", .days: "{n} giorni",
    .ramadan: "Ramadan", .imsak: "Imsak", .iftar: "Iftar",
    .updates: "Aggiornamenti", .version: "Versione {v}", .checkForUpdates: "Cerca aggiornamenti", .checkAutomatically: "Cerca aggiornamenti automaticamente",
    .upToDate: "Salat è aggiornato.", .updateAvailable: "Salat {v} è disponibile", .installUpdate: "Installa e riapri",
    .installing: "Installazione…", .updateFailed: "Impossibile cercare aggiornamenti. Riprova più tardi.",
    .updateCorrupt: "Il download era danneggiato e non è stato installato. Riprova.",
    .updateNotWritable: "Salat non può sostituirsi in questa cartella. Spostalo in Applicazioni o scarica l’aggiornamento da GitHub.",
    .monthly: "Orario mensile", .print: "Stampa…", .prevMonth: "Mese precedente", .nextMonth: "Mese successivo", .date: "Data",
    .bookmarks: "Segnalibri", .bookmark: "Salva", .removeBookmark: "Rimuovi segnalibro", .noBookmarks: "Ancora nessun segnalibro. Usa «Salva» sotto un versetto.",
]

private let dict: [Lang: [L10nKey: String]] = [.en: en, .fr: fr, .ar: ar, .de: de, .nl: nl, .es: es, .pt: pt, .it: it]

/// Keys with no string in `lang` (they would show in English); the tests keep this empty.
func missingKeys(_ lang: Lang) -> [L10nKey] { L10nKey.allCases.filter { dict[lang]?[$0] == nil } }

func t(_ key: L10nKey, _ lang: Lang, _ vars: [String: String] = [:]) -> String {
    var s = dict[lang]?[key] ?? en[key] ?? key.rawValue
    for (k, v) in vars { s = s.replacingOccurrences(of: "{\(k)}", with: v) }
    return s
}

func prayerName(_ p: Prayer, _ lang: Lang) -> String { t(L10nKey(rawValue: p.rawValue)!, lang) }

func methodName(_ m: MethodId, _ lang: Lang) -> String { methodNames[lang]?[m] ?? methodNames[.en]![m]! }

/// Same names as the website's `m.*` strings.
private let methodNames: [Lang: [MethodId: String]] = [
    .en: [.aachen: "Islamic Center Aachen", .morocco: "Morocco (Habous)", .mwl: "Muslim World League", .ummalqura: "Umm al-Qura (Makkah)",
          .uoif: "UOIF (France)", .isna: "ISNA (North America)", .egyptian: "Egyptian Authority", .karachi: "Karachi", .dubai: "Dubai",
          .kuwait: "Kuwait", .qatar: "Qatar", .singapore: "Singapore / Malaysia / Indonesia", .turkey: "Diyanet (Turkey)", .tehran: "Tehran"],
    .fr: [.aachen: "Centre islamique d’Aix-la-Chapelle", .morocco: "Maroc (Habous)", .mwl: "Ligue islamique mondiale", .ummalqura: "Umm al-Qura (La Mecque)",
          .uoif: "UOIF (France)", .isna: "ISNA (Amérique du Nord)", .egyptian: "Autorité égyptienne", .karachi: "Karachi", .dubai: "Dubaï",
          .kuwait: "Koweït", .qatar: "Qatar", .singapore: "Singapour / Malaisie / Indonésie", .turkey: "Diyanet (Turquie)", .tehran: "Téhéran"],
    .ar: [.aachen: "المركز الإسلامي في آخن", .morocco: "المغرب (الأوقاف)", .mwl: "رابطة العالم الإسلامي", .ummalqura: "أم القرى (مكة)",
          .uoif: "اتحاد المنظمات الإسلامية (فرنسا)", .isna: "الجمعية الإسلامية لأمريكا الشمالية", .egyptian: "الهيئة المصرية", .karachi: "كراتشي",
          .dubai: "دبي", .kuwait: "الكويت", .qatar: "قطر", .singapore: "سنغافورة / ماليزيا / إندونيسيا", .turkey: "ديانت (تركيا)", .tehran: "طهران"],
    .de: [.aachen: "Islamisches Zentrum Aachen", .morocco: "Marokko (Habous)", .mwl: "Islamische Weltliga", .ummalqura: "Umm al-Qura (Mekka)",
          .uoif: "UOIF (Frankreich)", .isna: "ISNA (Nordamerika)", .egyptian: "Ägyptische Behörde", .karachi: "Karatschi", .dubai: "Dubai",
          .kuwait: "Kuwait", .qatar: "Katar", .singapore: "Singapur / Malaysia / Indonesien", .turkey: "Diyanet (Türkei)", .tehran: "Teheran"],
    .nl: [.aachen: "Islamitisch Centrum Aken", .morocco: "Marokko (Habous)", .mwl: "Islamitische Wereldliga", .ummalqura: "Umm al-Qura (Mekka)",
          .uoif: "UOIF (Frankrijk)", .isna: "ISNA (Noord-Amerika)", .egyptian: "Egyptische autoriteit", .karachi: "Karachi", .dubai: "Dubai",
          .kuwait: "Koeweit", .qatar: "Qatar", .singapore: "Singapore / Maleisië / Indonesië", .turkey: "Diyanet (Turkije)", .tehran: "Teheran"],
    .es: [.aachen: "Centro Islámico de Aquisgrán", .morocco: "Marruecos (Habous)", .mwl: "Liga Mundial Musulmana", .ummalqura: "Umm al-Qura (La Meca)",
          .uoif: "UOIF (Francia)", .isna: "ISNA (Norteamérica)", .egyptian: "Autoridad egipcia", .karachi: "Karachi", .dubai: "Dubái",
          .kuwait: "Kuwait", .qatar: "Catar", .singapore: "Singapur / Malasia / Indonesia", .turkey: "Diyanet (Turquía)", .tehran: "Teherán"],
    .pt: [.aachen: "Centro Islâmico de Aachen", .morocco: "Marrocos (Habous)", .mwl: "Liga Mundial Muçulmana", .ummalqura: "Umm al-Qura (Meca)",
          .uoif: "UOIF (França)", .isna: "ISNA (América do Norte)", .egyptian: "Autoridade egípcia", .karachi: "Karachi", .dubai: "Dubai",
          .kuwait: "Kuwait", .qatar: "Catar", .singapore: "Singapura / Malásia / Indonésia", .turkey: "Diyanet (Turquia)", .tehran: "Teerã"],
    .it: [.aachen: "Centro islamico di Aquisgrana", .morocco: "Marocco (Habous)", .mwl: "Lega musulmana mondiale", .ummalqura: "Umm al-Qura (La Mecca)",
          .uoif: "UOIF (Francia)", .isna: "ISNA (Nord America)", .egyptian: "Autorità egiziana", .karachi: "Karachi", .dubai: "Dubai",
          .kuwait: "Kuwait", .qatar: "Qatar", .singapore: "Singapore / Malesia / Indonesia", .turkey: "Diyanet (Turchia)", .tehran: "Teheran"],
]

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
