import SwiftUI

/// The app window's sections; persisted so the menu-bar buttons and ⌘1–3 can switch them.
enum AppSection: String, CaseIterable {
    case prayer, quran, adhkar

    var key: L10nKey { switch self { case .prayer: .prayerTimes; case .quran: .quran; case .adhkar: .adhkar } }
    var symbol: String { switch self { case .prayer: "clock"; case .quran: "book"; case .adhkar: "hands.and.sparkles" } }
}

/// One window for everything: prayer times, Quran and adhkar, switched from the toolbar.
struct MainView: View {
    let engine: AlertEngine
    let quran: QuranPlayer
    let adhkar: AdhkarPlayer
    @AppStorage("section") private var section = AppSection.prayer

    var lang: Lang { engine.settings.d.lang }

    var body: some View {
        Group {
            switch section {
            case .prayer:
                ScrollView {
                    MenuView(engine: engine)
                        .clipShape(.rect(cornerRadius: 20))
                        .frame(maxWidth: .infinity).padding(24)
                }
                .themedWindow(sky: engine.sky)
                .navigationTitle(t(.prayerTimes, lang))
            case .quran: QuranView(settings: engine.settings, player: quran)
            case .adhkar: AdhkarView(settings: engine.settings, player: adhkar)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Picker(selection: $section) {
                    ForEach(AppSection.allCases, id: \.self) { s in Label(t(s.key, lang), systemImage: s.symbol).tag(s) }
                } label: { EmptyView() }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
    }
}

/// ⌘1–3 in the View menu.
struct SectionCommands: Commands {
    @AppStorage("section") private var section = AppSection.prayer
    let lang: Lang

    var body: some Commands {
        CommandGroup(before: .sidebar) {
            ForEach(Array(AppSection.allCases.enumerated()), id: \.offset) { i, s in
                Button(t(s.key, lang)) { section = s }.keyboardShortcut(KeyEquivalent(Character(String(i + 1))))
            }
            Divider()
        }
    }
}
