import SwiftUI

private let quranFont = "Amiri Quran"
private let bismillah = "بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ"

private func arabicDigits(_ n: Int) -> String {
    String(String(n).compactMap { $0.wholeNumberValue.map { Character(UnicodeScalar(0x0660 + $0)!) } })
}

struct QuranView: View {
    @Bindable var settings: AppSettings
    let player: QuranPlayer
    @State private var selection: Int?
    /// Reciter for this listen only; nil = the default from Settings.
    @State private var listenReciter: Int?

    var lang: Lang { settings.d.lang }
    var reciter: Int { listenReciter ?? settings.d.defaultReciter }

    var body: some View {
        NavigationSplitView {
            List(QuranText.surahs, selection: $selection) { s in
                HStack(spacing: 10) {
                    Text(s.n.formatted(.number.locale(lang.locale))).monospacedDigit().foregroundStyle(.secondary).frame(width: 30)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(s.ar).font(.custom(quranFont, size: 18))
                        Text(lang == .ar ? t(.ayahCount, lang, ["n": s.ayahs.count.formatted(.number.locale(lang.locale))])
                                         : "\(s.en) · \(t(.ayahCount, lang, ["n": String(s.ayahs.count)]))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if player.surah == s.n, player.isPlaying { Image(systemName: "speaker.wave.2.fill").foregroundStyle(.tint) }
                }
                .tag(s.n)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            if let n = selection {
                SurahView(surah: QuranText.surahs[n - 1], settings: settings, player: player, reciter: reciter)
                    .id(n)
            } else {
                Text(t(.chooseSurah, lang)).foregroundStyle(.secondary)
            }
        }
        .toolbar { toolbar }
        .navigationTitle(selection.map { QuranText.surahs[$0 - 1].ar } ?? t(.quran, lang))
        .onAppear { if selection == nil { selection = player.surah ?? settings.d.lastSurah } }
        .onChange(of: selection) { _, n in
            listenReciter = nil // a per-surah reciter choice doesn't stick
            if let n { settings.d.lastSurah = n }
        }
        .environment(\.layoutDirection, lang.isRTL ? .rightToLeft : .leftToRight)
    }

    var selectedIsLoaded: Bool { player.surah == selection && player.reciter == reciter && player.state == .ready }

    @ToolbarContentBuilder var toolbar: some ToolbarContent {
        ToolbarItem {
            Picker(t(.reciter, lang), selection: Binding(get: { reciter }, set: { listenReciter = $0 })) {
                ForEach(Reciter.all) { Text($0.name(lang)).tag($0.id) }
            }
            .frame(width: 220)
        }
        ToolbarItemGroup {
            Button(t(.previous, lang), systemImage: "backward.fill") { player.previous() }.disabled(!selectedIsLoaded)
            Button(player.isPlaying && selectedIsLoaded ? t(.pause, lang) : t(.play, lang),
                   systemImage: player.isPlaying && selectedIsLoaded ? "pause.fill" : "play.fill") {
                guard let s = selection else { return }
                if selectedIsLoaded { player.toggle() } else { Task { await player.play(surah: s, reciter: reciter) } }
            }
            .disabled(selection == nil)
            Button(t(.nextAyah, lang), systemImage: "forward.fill") { player.next() }.disabled(!selectedIsLoaded)
        }
    }
}

private struct SurahView: View {
    let surah: Surah
    let settings: AppSettings
    let player: QuranPlayer
    let reciter: Int

    var lang: Lang { settings.d.lang }
    var isCurrent: Bool { player.surah == surah.n && player.reciter == reciter }

    var body: some View {
        VStack(spacing: 0) {
            if isCurrent { status }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        if surah.n != 1 && surah.n != 9 {
                            Text(bismillah).font(.custom(quranFont, size: 26)).frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                        ForEach(Array(surah.ayahs.enumerated()), id: \.offset) { i, text in
                            let a = i + 1
                            let playing = isCurrent && player.currentAyah == a
                            Text("\(text) \u{FD3F}\(arabicDigits(a))\u{FD3E}")
                                .font(.custom(quranFont, size: 28))
                                .lineSpacing(14)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8).padding(.horizontal, 12)
                                .background(playing ? Color.accentColor.opacity(0.16) : .clear, in: .rect(cornerRadius: 8))
                                .contentShape(.rect)
                                .onTapGesture {
                                    settings.d.lastAyah = a
                                    if player.state == .ready && isCurrent { player.seek(toAyah: a); player.resume() }
                                    else { Task { await player.play(surah: surah.n, reciter: reciter, fromAyah: a) } }
                                }
                                .id(a)
                        }
                    }
                    .padding(24)
                    .environment(\.layoutDirection, .rightToLeft)
                }
                .onAppear { if settings.d.lastSurah == surah.n, settings.d.lastAyah > 1 { proxy.scrollTo(settings.d.lastAyah, anchor: .top) } }
                .onChange(of: player.currentAyah) { _, a in
                    guard isCurrent, let a else { return }
                    settings.d.lastAyah = a
                    withAnimation { proxy.scrollTo(a, anchor: .center) }
                }
            }
        }
    }

    @ViewBuilder var status: some View {
        switch player.state {
        case .downloading(let p):
            HStack { Text(t(.downloading, lang)); ProgressView(value: p) }.padding(10)
        case .needsInternet:
            banner(t(.needsInternet, lang), "wifi.slash")
        case .error(let msg):
            banner(msg, "exclamationmark.triangle")
        case .idle, .ready:
            EmptyView()
        }
    }

    func banner(_ text: String, _ icon: String) -> some View {
        HStack {
            Label(text, systemImage: icon)
            Spacer()
            Button(t(.retry, lang)) { Task { await player.play(surah: surah.n, reciter: reciter) } }
        }
        .padding(10)
        .background(.orange.opacity(0.15))
    }
}

struct QuranSettingsTab: View {
    @Bindable var settings: AppSettings
    let player: QuranPlayer
    let adhkar: AdhkarPlayer
    @State private var refresh = 0
    var lang: Lang { settings.d.lang }

    var body: some View {
        Form {
            Picker(t(.defaultReciter, lang), selection: $settings.d.defaultReciter) {
                ForEach(Reciter.all) { Text($0.name(lang)).tag($0.id) }
            }
            Section {
                ForEach(Reciter.all) { r in
                    let _ = refresh
                    let count = player.bulk[r.id] ?? player.store.downloadedCount(reciter: r.id)
                    HStack {
                        VStack(alignment: .leading) {
                            Text(r.name(lang))
                            Text("\(count)/114 · \(ByteCountFormatter.string(fromByteCount: player.store.size(reciter: r.id), countStyle: .file))")
                                .font(.caption).foregroundStyle(.secondary)
                            if let e = player.bulkError[r.id] {
                                Text(e == "offline" ? t(.needsInternet, lang) : e).font(.caption).foregroundStyle(.orange)
                            }
                        }
                        Spacer()
                        if player.bulk[r.id] != nil {
                            ProgressView(value: Double(count), total: 114).frame(width: 80)
                            Button(t(.cancel, lang), systemImage: "xmark.circle") { player.cancelDownload(reciter: r.id) }.labelStyle(.iconOnly)
                        } else if count < 114 {
                            Button(t(.downloadAll, lang)) { player.downloadAll(reciter: r.id) }
                        }
                        if count > 0 {
                            Button(t(.delete, lang), systemImage: "trash") { player.delete(reciter: r.id); refresh += 1 }.labelStyle(.iconOnly)
                        }
                    }
                }
            }
            AdhkarAudioSection(player: adhkar, lang: lang)
        }
        .formStyle(.grouped)
    }
}
