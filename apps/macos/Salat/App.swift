import ServiceManagement
import SwiftUI

@main
struct SalatApp: App {
    @State private var engine: AlertEngine
    @State private var quran: QuranPlayer

    init() {
        let settings = AppSettings()
        // Open at login is on by default (spec); only set it once so turning it off sticks.
        if !settings.d.openAtLoginInitialized {
            try? SMAppService.mainApp.register()
            settings.d.openAtLoginInitialized = true
        }
        let engine = AlertEngine(settings: settings, location: LocationService())
        let quran = QuranPlayer()
        engine.player.onPlay = { quran.pause() } // the adhan interrupts recitation
        _engine = State(initialValue: engine)
        _quran = State(initialValue: quran)
    }

    var body: some Scene {
        MenuBarExtra { MenuView(engine: engine) } label: { MenuLabel(engine: engine) }
            .menuBarExtraStyle(.window)
        Window(t(.quran, engine.settings.d.lang), id: "quran") { QuranView(settings: engine.settings, player: quran) }
            .defaultSize(width: 900, height: 700)
        Settings { SettingsView(engine: engine, quran: quran) }
    }
}
