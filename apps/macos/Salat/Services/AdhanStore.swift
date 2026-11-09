import Foundation

/// An adhan recording: bundled (free licenses), downloaded on first use (Internet Archive, not redistributed by us),
/// or added by the user ("custom-…" files).
struct AdhanVoice: Identifiable, Sendable {
    let id: String
    let names: (en: String, fr: String, ar: String)
    var remote: URL? = nil
    /// Fajr recordings include "as-salātu khayrun min an-nawm": only offered for Fajr.
    var fajrOnly = false
    func name(_ l: Lang) -> String { l == .fr ? names.fr : l == .ar ? names.ar : names.en }

    static let defaultId = "madinah"

    private static func archive(_ item: String, _ file: String) -> URL {
        URL(string: "https://archive.org/download/\(item)/\(file.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)")!
    }

    static let all = [
        AdhanVoice(id: "madinah", names: ("Madinah: Sheikh Essam Bukhari", "Médine : Cheikh Essam Bukhari", "المدينة: الشيخ عصام بخاري"),
                   remote: archive("SheikhEssamBukhari", "1433.mp3")),
        AdhanVoice(id: "mishary", names: ("Mishary Rashid Alafasy", "Mishary Rashid Alafasy", "مشاري راشد العفاسي"),
                   remote: archive("VeryBeautifulAdhaanByMisharyAlAfasy", "Very Beautiful Adhaan by Mishary Al-Afasy.mp3")),
        AdhanVoice(id: "aqsa", names: ("Al-Aqsa, Jerusalem", "Al-Aqsa, Jérusalem", "المسجد الأقصى، القدس"),
                   remote: archive("AzanMagribDomeOfRockFri11.4.14", "Azan Magrib Dome of Rock Fri 11.4.14.mp3")),
        AdhanVoice(id: "abdulbasit", names: ("Abdul Basit Abdul Samad", "Abdul Basit Abdul Samad", "عبد الباسط عبد الصمد"),
                   remote: archive("adhans_sunnah", "adhan_abdul_baset.mp3")),
        AdhanVoice(id: "makkah_fajr", names: ("Makkah Fajr: Sheikh Ali Ahmed Mulla", "La Mecque, Fajr : Cheikh Ali Ahmed Mulla", "الفجر من مكة: الشيخ علي أحمد ملا"),
                   remote: archive("MakkahFajrAdhan6913SheikhAliMullah", "Makkah Fajr Adhan 6-9-13 Sheikh Ali Mullah.mp3"), fajrOnly: true),
        AdhanVoice(id: "mishary_fajr", names: ("Mishary Alafasy (Fajr)", "Mishary Alafasy (Fajr)", "العفاسي (الفجر)"),
                   remote: archive("adhans_sunnah", "adhan_morning_mishari.mp3"), fajrOnly: true),
        AdhanVoice(id: "hassan2", names: ("Hassan II Mosque, Casablanca", "Mosquée Hassan II, Casablanca", "مسجد الحسن الثاني، الدار البيضاء")),
        AdhanVoice(id: "fakhry", names: ("Sabah Fakhri", "Sabah Fakhri", "صباح فخري")),
        AdhanVoice(id: "beautiful", names: ("Adhan (calm)", "Adhan (calme)", "أذان هادئ")),
        AdhanVoice(id: "azan", names: ("Adhan (classic)", "Adhan (classique)", "أذان تقليدي")),
    ]

    static func find(_ id: String) -> AdhanVoice? { all.first { $0.id == id } }
}

/// Where adhan audio lives: bundled files, then `{root}/{id}.mp3` (downloaded) or `{root}/custom-….{ext}` (user's own).
final class AdhanStore: Sendable {
    static let shared = AdhanStore(root: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Salat/adhans"))

    let root: URL
    private let session: URLSession
    private let downloads = SharedDownloads()

    init(root: URL, session: URLSession = .shared) {
        self.root = root
        self.session = session
    }

    private func files() -> [URL] { (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [] }

    func local(_ id: String) -> URL? {
        if let b = Bundle(for: AdhanStore.self).url(forResource: id, withExtension: "m4a") { return b }
        return files().first { $0.deletingPathExtension().lastPathComponent == id }
    }

    func download(_ v: AdhanVoice) async throws {
        guard local(v.id) == nil, let url = v.remote else { return }
        try await downloads.run(v.id) {
            try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
            try await self.session.downloadAtomically(url, to: self.root.appendingPathComponent("\(v.id).mp3"))
        }
    }

    /// Copies a user's audio file in; returns its id. The display name is kept in the file name.
    func importFile(_ src: URL) throws -> String {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let name = src.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "~", with: "-")
        let id = "custom-\(UUID().uuidString.prefix(8))~\(name)"
        try FileManager.default.copyItem(at: src, to: root.appendingPathComponent(id).appendingPathExtension(src.pathExtension.lowercased()))
        return id
    }

    func customIds() -> [String] {
        files().map { $0.deletingPathExtension().lastPathComponent }.filter { $0.hasPrefix("custom-") }.sorted()
    }

    func customName(_ id: String) -> String? {
        id.hasPrefix("custom-") ? id.split(separator: "~", maxSplits: 1).last.map(String.init) : nil
    }

    func deleteCustom(_ id: String) {
        guard id.hasPrefix("custom-"), let f = local(id) else { return }
        try? FileManager.default.removeItem(at: f)
    }
}

/// One-time switch of both adhans to Madinah when the Muslim Pro voices arrived (user decision, 2026-11-09).
/// Later choices stick.
func migrateAdhanDefaults(_ d: inout AppSettings.Data) {
    guard d.adhanDefaultsV2 == nil else { return }
    d.adhanVoice = AdhanVoice.defaultId
    d.fajrVoice = AdhanVoice.defaultId
    d.adhanDefaultsV2 = true
}
