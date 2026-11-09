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
        var adhanVoice = "hassan2"
        var fajrVoice = "hassan2"
        var defaultReciter = 7
        var manualCity: City? = nil
        var useManualLocation = false
        var iconOnly = false
        var lastAlertHandled: Date? = nil
        var lastKnown: ResolvedLocation? = nil
        var lastSurah = 1
        var lastAyah = 1
        var openAtLoginInitialized = false
    }

    private static let key = "settings.v1"
    private let defaults: UserDefaults
    var d: Data { didSet { save() } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        d = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(Data.self, from: $0) } ?? Data()
    }

    private func save() { defaults.set(try? JSONEncoder().encode(d), forKey: Self.key) }
}
