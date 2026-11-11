import Foundation
import Observation

/// App settings, persisted in UserDefaults as one JSON blob.
@MainActor @Observable
final class AppSettings {
    struct Data: Codable {
        var lang: Lang = .system
        var method: MethodId? = nil // nil = automatic by country
        var asr: AsrSchool = .standard
        var modes: [Prayer: AlertMode] = Dictionary(uniqueKeysWithValues: Prayer.allCases.map { ($0, .adhan) })
        var reminder = false
        var adhanVoice = AdhanVoice.defaultId
        var fajrVoice = AdhanVoice.defaultId
        var defaultReciter = 7
        var manualCity: City? = nil
        var useManualLocation = false
        var iconOnly = false
        var lastAlertHandled: Date? = nil
        var lastKnown: ResolvedLocation? = nil
        var lastSurah = 1
        var lastAyah = 1
        var openAtLoginInitialized = false
        // Fields added later are optional so older saved settings still decode.
        var loginItemPath: String? = nil
        var lastAdhkarChapter: Int? = nil
        var adhanDefaultsV2: Bool? = nil
        var habous: HabousDays? = nil // last official Moroccan times from the Worker, for offline use
        var adjust: [Prayer: Int]? = nil // minutes added per prayer (local mosque)
        var hijriOffset: Int? = nil // days added to the Hijri date; nil = automatic
        var adhkarReminder: Bool? = nil
        var fridayReminder: Bool? = nil
    }

    private static let key = "settings.v1"
    private let defaults: UserDefaults
    var d: Data { didSet { save() } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var d = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(Data.self, from: $0) } ?? Data()
        migrateAdhanDefaults(&d)
        self.d = d
        save() // didSet doesn't run in init
    }

    private func save() { defaults.set(try? JSONEncoder().encode(d), forKey: Self.key) }
}

/// The login item points at the app's path when it was registered; after moving the app (e.g. into /Applications) re-register.
func loginItemNeedsRefresh(registeredPath: String?, currentPath: String, enabled: Bool) -> Bool {
    enabled && registeredPath != currentPath
}
