import ServiceManagement
import SwiftUI

@main
struct SalatApp: App {
    @State private var engine: AlertEngine

    init() {
        let settings = AppSettings()
        // Open at login is on by default (spec); only set it once so turning it off sticks.
        if !settings.d.openAtLoginInitialized {
            try? SMAppService.mainApp.register()
            settings.d.openAtLoginInitialized = true
        }
        _engine = State(initialValue: AlertEngine(settings: settings, location: LocationService()))
    }

    var body: some Scene {
        MenuBarExtra { MenuView(engine: engine) } label: { MenuLabel(engine: engine) }
            .menuBarExtraStyle(.window)
        Window(t(.quran, engine.settings.d.lang), id: "quran") { QuranView(settings: engine.settings) }
            .defaultSize(width: 900, height: 700)
        Settings { SettingsView(engine: engine) }
    }
}
