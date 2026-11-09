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
                    StarBadge(text: s.n.formatted(.number.locale(lang.locale)))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(s.ar).font(.custom(quranFont, size: 19))
                        Text(lang == .ar ? t(.ayahCount, lang, ["n": s.ayahs.count.formatted(.number.locale(lang.locale))])
                                         : "\(s.en) · \(t(.ayahCount, lang, ["n": String(s.ayahs.count)]))")
                            .font(Theme.plex(11)).foregroundStyle(Theme.soft)
                    }
                    Spacer()
                    if player.surah == s.n, player.isPlaying { Image(systemName: "speaker.wave.2.fill").foregroundStyle(Theme.gold) }
                }
                .padding(.vertical, 2)
                .tag(s.n)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.panelStrong)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if let n = selection {
                SurahView(surah: QuranText.surahs[n - 1], settings: settings, player: player, reciter: reciter)
                    .id(n)
            } else {
                Text(t(.chooseSurah, lang)).font(Theme.kufi(22)).foregroundStyle(Theme.soft)
            }
        }
        .themedWindow()
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
            .frame(width: 170)
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

struct SurahView: View {
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
                    LazyVStack(alignment: .leading, spacing: 8) {
                        header
                        if surah.n != 1 && surah.n != 9 {
                            Text(bismillah).font(.custom(quranFont, size: 28)).foregroundStyle(Theme.gold)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                        }
                        ForEach(Array(surah.ayahs.enumerated()), id: \.offset) { i, text in
                            let a = i + 1
                            let playing = isCurrent && player.currentAyah == a
                            (Text(text).foregroundStyle(Theme.ink) + Text(" \u{FD3F}\(arabicDigits(a))\u{FD3E}").foregroundStyle(Theme.gold))
                                .font(.custom(quranFont, size: 28))
                                .lineSpacing(14)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10).padding(.horizontal, 16)
                                .background(playing ? Theme.gold.opacity(0.14) : .clear, in: .rect(cornerRadius: 14))
                                .overlay { if playing { RoundedRectangle(cornerRadius: 14).stroke(Theme.gold.opacity(0.7), lineWidth: 1) } }
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
                    .frame(maxWidth: 860)
                    .frame(maxWidth: .infinity)
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

    /// Surah title card under a small arch.
    var header: some View {
        VStack(spacing: 4) {
            Text(surah.ar).font(.custom(quranFont, size: 40)).foregroundStyle(Theme.gold)
            if lang != .ar { Text(surah.en).font(Theme.kufi(20)) }
            Text(t(.ayahCount, lang, ["n": surah.ayahs.count.formatted(.number.locale(lang.locale))]))
                .font(Theme.plex(12)).foregroundStyle(Theme.soft)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 34).padding(.bottom, 16)
        .background(alignment: .top) {
            ZStack {
                ArchShape().fill(Theme.panel)
                ArchShape().stroke(Theme.gold, lineWidth: 1.4)
                ArchShape(inner: true).stroke(Theme.gold.opacity(0.35), lineWidth: 1)
            }
            .frame(width: 300)
        }
        .padding(.bottom, 6)
    }

    @ViewBuilder var status: some View {
        switch player.state {
        case .downloading(let p):
            HStack { Text(t(.downloading, lang)).foregroundStyle(Theme.soft); ProgressView(value: p).tint(Theme.gold) }
                .padding(.horizontal, 16).padding(.vertical, 10)
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
            Label(text, systemImage: icon).foregroundStyle(Theme.gold)
            Spacer()
            Button(t(.retry, lang)) { Task { await player.play(surah: surah.n, reciter: reciter) } }.buttonStyle(GoldOutlineButtonStyle())
        }
        .panel(14, padding: 12)
        .padding(.horizontal, 16).padding(.top, 10)
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

/// Number inside a gold eight-point star (two overlapping squares), like the website's lattice.
struct StarBadge: View {
    let text: String
    var body: some View {
        ZStack {
            Rectangle().stroke(Theme.gold, lineWidth: 1).frame(width: 22, height: 22)
            Rectangle().stroke(Theme.gold, lineWidth: 1).frame(width: 22, height: 22).rotationEffect(.degrees(45))
            Text(text).font(Theme.plex(10, semibold: true)).monospacedDigit().foregroundStyle(Theme.ink)
        }
        .frame(width: 32, height: 32)
    }
}
