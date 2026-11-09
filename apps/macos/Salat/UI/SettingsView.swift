import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let engine: AlertEngine
    let quran: QuranPlayer
    let adhkar: AdhkarPlayer
    var settings: AppSettings { engine.settings }
    var lang: Lang { settings.d.lang }

    var body: some View {
        TabView {
            Tab(t(.general, lang), systemImage: "gearshape") { GeneralTab(settings: settings) }
            Tab(t(.prayerTimes, lang), systemImage: "clock") { PrayerTab(engine: engine) }
            Tab(t(.alerts, lang), systemImage: "speaker.wave.2") { AlertsTab(engine: engine) }
            Tab(t(.quran, lang), systemImage: "book") { QuranSettingsTab(settings: settings, player: quran, adhkar: adhkar) }
            Tab(t(.qibla, lang), systemImage: "location.north.line") { QiblaTab(engine: engine) }
        }
        .frame(width: 560, height: 480)
        .themedWindow()
        .environment(\.layoutDirection, lang.isRTL ? .rightToLeft : .leftToRight)
    }
}

private struct GeneralTab: View {
    @Bindable var settings: AppSettings
    @State private var atLogin = SMAppService.mainApp.status == .enabled
    var lang: Lang { settings.d.lang }

    var body: some View {
        Form {
            Picker(t(.language, lang), selection: $settings.d.lang) {
                ForEach(Lang.allCases, id: \.self) { Text($0.nativeName) }
            }
            Toggle(t(.openAtLogin, lang), isOn: $atLogin)
                .onChange(of: atLogin) { _, on in
                    try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    if on { settings.d.loginItemPath = Bundle.main.bundlePath }
                    atLogin = SMAppService.mainApp.status == .enabled
                }
            Toggle(t(.menuBarIconOnly, lang), isOn: $settings.d.iconOnly)
        }
        .formStyle(.grouped)
    }
}

private struct PrayerTab: View {
    let engine: AlertEngine
    @State private var query = ""
    var settings: AppSettings { engine.settings }
    var lang: Lang { settings.d.lang }

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section(t(.location, lang)) {
                Picker(t(.location, lang), selection: $settings.d.useManualLocation) {
                    Text(t(.automatic, lang)).tag(false)
                    Text(t(.manualCity, lang)).tag(true)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                if !settings.d.useManualLocation, !engine.location.authorized, engine.location.status != .notDetermined {
                    Text(t(.locationDenied, lang)).font(.caption).foregroundStyle(.orange)
                }
                if let c = engine.loc?.city { LabeledContent("", value: "\(flag(c.cc)) \(c.name)") }
                if settings.d.useManualLocation || !engine.location.authorized {
                    TextField(t(.searchCity, lang), text: $query)
                    ForEach(CityIndex.shared.search(query, limit: 8), id: \.self) { c in
                        Button("\(flag(c.cc)) \(c.name)") {
                            settings.d.manualCity = c
                            settings.d.useManualLocation = true
                            query = ""
                        }
                        .buttonStyle(.link)
                    }
                }
            }
            Section {
                Picker(t(.method, lang), selection: $settings.d.method) {
                    Text(t(.auto, lang, ["method": methodName(settings.d.method == nil ? engine.method : autoMethod, lang)])).tag(MethodId?.none)
                    Divider()
                    ForEach(MethodId.allCases, id: \.self) { Text(methodName($0, lang)).tag(Optional($0)) }
                }
                Picker(t(.asrMethod, lang), selection: $settings.d.asr) {
                    Text(t(.standard, lang)).tag(AsrSchool.standard)
                    Text(t(.hanafi, lang)).tag(AsrSchool.hanafi)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var autoMethod: MethodId {
        methodForCountry(engine.loc.flatMap { CountryLookup.shared.code(lat: $0.lat, lon: $0.lon) })
    }
}

private struct AlertsTab: View {
    let engine: AlertEngine
    @State private var loading: String?
    @State private var failed: String?
    @State private var custom = AdhanStore.shared.customIds()
    var lang: Lang { engine.settings.d.lang }

    var body: some View {
        @Bindable var settings = engine.settings
        Form {
            Section {
                voice(t(.adhanVoice, lang), $settings.d.adhanVoice, fajr: false)
                voice(t(.fajrVoice, lang), $settings.d.fajrVoice, fajr: true)
                HStack {
                    Button(t(.addAdhan, lang), systemImage: "plus") { addOwn() }
                    Spacer()
                    if engine.player.isPlaying {
                        Button(t(.stop, lang), systemImage: "stop.fill") { engine.player.stop() }.buttonStyle(GoldButtonStyle())
                    }
                }
                if let f = failed { Text(f).font(.caption).foregroundStyle(Theme.gold) }
            }
            Section {
                ForEach(Prayer.allCases, id: \.self) { p in
                    Picker(prayerName(p, lang), selection: Binding(
                        get: { settings.d.modes[p] ?? .adhan },
                        set: { settings.d.modes[p] = $0 })) {
                        Text(t(.alertAdhan, lang)).tag(AlertMode.adhan)
                        Text(t(.alertNotification, lang)).tag(AlertMode.notification)
                        Text(t(.alertOff, lang)).tag(AlertMode.off)
                    }
                }
                Toggle(t(.notifyReminder, lang), isOn: $settings.d.reminder)
            }
        }
        .formStyle(.grouped)
    }

    private func label(_ id: String) -> String {
        if let n = AdhanStore.shared.customName(id) { return n }
        guard let v = AdhanVoice.find(id) else { return id }
        return v.name(lang) + (v.remote != nil && AdhanStore.shared.local(id) == nil ? " ↓" : "")
    }

    private func voice(_ title: String, _ sel: Binding<String>, fajr: Bool) -> some View {
        HStack {
            Picker(title, selection: Binding(get: { sel.wrappedValue }, set: { id in sel.wrappedValue = id; fetch(id, thenPlay: false) })) {
                ForEach(AdhanVoice.all.filter { fajr || !$0.fajrOnly }) { Text(label($0.id)).tag($0.id) }
                if !custom.isEmpty {
                    Divider()
                    ForEach(custom, id: \.self) { Text(label($0)).tag($0) }
                }
            }
            if loading == sel.wrappedValue {
                ProgressView().controlSize(.small)
            } else {
                Button(t(.playTest, lang), systemImage: "play.fill") { fetch(sel.wrappedValue, thenPlay: true) }
                    .labelStyle(.iconOnly).buttonStyle(GoldOutlineButtonStyle())
            }
            if AdhanStore.shared.customName(sel.wrappedValue) != nil {
                Button(t(.delete, lang), systemImage: "trash") {
                    AdhanStore.shared.deleteCustom(sel.wrappedValue)
                    sel.wrappedValue = AdhanVoice.defaultId
                    custom = AdhanStore.shared.customIds()
                }.labelStyle(.iconOnly)
            }
        }
    }

    /// Downloads an Internet Archive voice the first time it's picked or played.
    private func fetch(_ id: String, thenPlay: Bool) {
        failed = nil
        guard let v = AdhanVoice.find(id), v.remote != nil, AdhanStore.shared.local(id) == nil else {
            if thenPlay { engine.player.play(id) }
            return
        }
        loading = id
        Task {
            do { try await AdhanStore.shared.download(v); if thenPlay { engine.player.play(id) } }
            catch { failed = QuranPlayer.isOffline(error) ? t(.needsInternet, lang) : error.localizedDescription }
            loading = nil
        }
    }

    private func addOwn() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let id = try AdhanStore.shared.importFile(url)
            custom = AdhanStore.shared.customIds()
            engine.settings.d.adhanVoice = id
        } catch { failed = error.localizedDescription }
    }
}

private struct QiblaTab: View {
    let engine: AlertEngine
    var lang: Lang { engine.settings.d.lang }

    var body: some View {
        VStack(spacing: 16) {
            if let l = engine.loc {
                let deg = qiblaBearing(lat: l.lat, lon: l.lon)
                let i = compass8(deg)
                Image(systemName: "location.north.fill")
                    .font(.system(size: 64))
                    .rotationEffect(.degrees(deg))
                    .foregroundStyle(Color.accentColor)
                Text(t(.qiblaBearing, lang, ["deg": String(Int(deg.rounded()))])).font(.title2.bold())
                Text(t(.noCompass, lang, ["deg": String(Int(deg.rounded())), "dir": t(.dirWords, lang).split(separator: ",")[i].description]))
                Text(t(.distance, lang, ["km": Int(kaabaDistanceKm(lat: l.lat, lon: l.lon)).formatted(.number.locale(lang.locale))]))
                    .foregroundStyle(.secondary)
            } else {
                Text(t(.noLocation, lang))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
