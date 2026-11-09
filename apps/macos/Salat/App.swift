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
        if Snapshots.dir != nil {
            // Developer snapshot run: leave the login item alone.
        } else if !settings.d.openAtLoginInitialized {
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
        // Fetch the chosen Internet Archive adhans now, so the first prayer plays them (bundled fallback until then).
        for id in Set([settings.d.adhanVoice, settings.d.fajrVoice]) {
            if let v = AdhanVoice.find(id) { Task.detached { try? await AdhanStore.shared.download(v) } }
        }
        if let dir = Snapshots.dir { Snapshots.run(engine: engine, quran: quran, adhkar: adhkar, to: dir) }
        _engine = State(initialValue: engine)
        _quran = State(initialValue: quran)
        _adhkar = State(initialValue: adhkar)
    }

    var body: some Scene {
        MenuBarExtra { MenuView(engine: engine) } label: { MenuLabel(engine: engine) }
            .menuBarExtraStyle(.window)
        Window("Salat", id: "main") { MainView(engine: engine, quran: quran, adhkar: adhkar) }
            .defaultSize(width: 900, height: 700)
            .defaultLaunchBehavior(Snapshots.launch)
            .commands { SectionCommands(lang: engine.settings.d.lang) }
        Settings { SettingsView(engine: engine, quran: quran, adhkar: adhkar) }
    }
}
