import ServiceManagement
import SwiftUI

@main
struct SalatApp: App {
    @State private var engine: AlertEngine
    @State private var quran: QuranPlayer
    @State private var adhkar: AdhkarPlayer

    init() {
        let settings = AppSettings()
        let path = Bundle.main.bundlePath
        // Open at login is on by default (spec); only set it once so turning it off sticks.
        if !settings.d.openAtLoginInitialized {
            try? SMAppService.mainApp.register()
            settings.d.openAtLoginInitialized = true
            if SMAppService.mainApp.status == .enabled { settings.d.loginItemPath = path }
        } else if loginItemNeedsRefresh(registeredPath: settings.d.loginItemPath, currentPath: path,
                                         enabled: SMAppService.mainApp.status == .enabled) {
            try? SMAppService.mainApp.unregister() // the app moved (e.g. into /Applications): point the login item here
            try? SMAppService.mainApp.register()
            if SMAppService.mainApp.status == .enabled { settings.d.loginItemPath = path }
        }
        let engine = AlertEngine(settings: settings, location: LocationService())
        let quran = QuranPlayer()
        let adhkar = AdhkarPlayer()
        // One sound at a time: the adhan stops everything, a dhikr stops the Quran and vice versa.
        engine.player.onPlay = { quran.pause(); adhkar.stop() }
        adhkar.onPlay = { quran.pause(); engine.player.stop() }
        quran.onPlay = { adhkar.stop(); engine.player.stop() }
        _engine = State(initialValue: engine)
        _quran = State(initialValue: quran)
        _adhkar = State(initialValue: adhkar)
    }

    var body: some Scene {
        MenuBarExtra { MenuView(engine: engine) } label: { MenuLabel(engine: engine) }
            .menuBarExtraStyle(.window)
        Window(t(.quran, engine.settings.d.lang), id: "quran") { QuranView(settings: engine.settings, player: quran) }
            .defaultSize(width: 900, height: 700)
        Window(t(.adhkar, engine.settings.d.lang), id: "adhkar") { AdhkarView(settings: engine.settings, player: adhkar) }
            .defaultSize(width: 900, height: 700)
        Settings { SettingsView(engine: engine, quran: quran, adhkar: adhkar) }
    }
}
