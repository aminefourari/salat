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
    /// Ayah to open the selected surah at (from the hizb list).
    @State private var jump: Int?
    @State private var listMode = ListMode.surahs
    enum ListMode { case surahs, hizbs, bookmarks }
    /// Reciter for this listen only; nil = the default from Settings.
    @State private var listenReciter: Int?

    var lang: Lang { settings.d.lang }
    var reciter: Int { listenReciter ?? settings.d.defaultReciter }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                Picker("", selection: $listMode) {
                    Text(t(.surahs, lang)).tag(ListMode.surahs)
                    Text(t(.hizbs, lang)).tag(ListMode.hizbs)
                    Text(t(.bookmarks, lang)).tag(ListMode.bookmarks)
                }
                .pickerStyle(.segmented).labelsHidden().padding(8)
                switch listMode {
                case .surahs: surahList
                case .hizbs: hizbList
                case .bookmarks: bookmarkList
                }
            }
            .background(Theme.panelStrong)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if let n = selection {
                SurahView(surah: QuranText.surahs[n - 1], settings: settings, player: player, reciter: reciter, startAyah: jump)
                    .id("\(n):\(jump ?? 0)")
            } else {
                Text(t(.chooseSurah, lang)).font(Theme.kufi(22)).foregroundStyle(Theme.soft)
            }
        }
        .themedWindow()
        .toolbar { toolbar }
        .navigationTitle(selection.map { QuranText.surahs[$0 - 1].ar } ?? t(.quran, lang))
        .onAppear { if selection == nil { selection = player.surah ?? settings.d.lastSurah } }
        .onReceive(NotificationCenter.default.publisher(for: .salatOpenSection)) { _ in jump = nil; selection = settings.d.lastSurah }
        .onChange(of: selection) { _, n in
            listenReciter = nil // a per-surah reciter choice doesn't stick
            if let n { settings.d.lastSurah = n }
        }
        .environment(\.layoutDirection, lang.isRTL ? .rightToLeft : .leftToRight)
    }

    var surahList: some View {
            List(QuranText.surahs, selection: Binding(get: { selection }, set: { jump = nil; selection = $0 })) { s in
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
    }

    var hizbList: some View {
        List(hizbStarts(QuranText.surahs), id: \.hizb) { h in
            let s = QuranText.surahs[h.surah - 1]
            let fmt = { (n: Int) in n.formatted(.number.locale(lang.locale)) }
            Button { jump = h.ayah; selection = h.surah } label: {
                HStack(spacing: 10) {
                    StarBadge(text: fmt(h.hizb))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(t(.hizbN, lang, ["n": fmt(h.hizb)])).font(Theme.plex(13, semibold: true))
                        Text("\(t(.juzN, lang, ["n": fmt(h.juz)])) · \(lang == .ar ? s.ar : s.en) \(fmt(h.ayah))")
                            .font(Theme.plex(11)).foregroundStyle(Theme.soft)
                    }
                    Spacer()
                }
                .padding(.vertical, 2)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder var bookmarkList: some View {
        let list = settings.d.bookmarks ?? []
        if list.isEmpty {
            Text(t(.noBookmarks, lang)).font(Theme.plex(12)).foregroundStyle(Theme.soft).padding().frame(maxHeight: .infinity, alignment: .top)
        } else {
            List(list, id: \.at) { b in
                let s = QuranText.surahs[b.surah - 1]
                Button { jump = b.ayah; selection = b.surah } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bookmark.fill").foregroundStyle(Theme.gold)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(lang == .ar ? s.ar : s.en) \(b.ayah.formatted(.number.locale(lang.locale)))").font(Theme.plex(13, semibold: true))
                            Text(b.at.formatted(.dateTime.day().month(.abbreviated).year().locale(lang.locale)))
                                .font(Theme.plex(11)).foregroundStyle(Theme.soft)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(t(.removeBookmark, lang)) { settings.d.bookmarks = toggleBookmark(list, surah: b.surah, ayah: b.ayah, now: Date()) }
                }
            }
            .scrollContentBackground(.hidden)
        }
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
    var startAyah: Int?
    @State private var tafsirAyah: TafsirAyah?

    var lang: Lang { settings.d.lang }
    var isCurrent: Bool { player.surah == surah.n && player.reciter == reciter }
    var rubAt: [Int: Int] { Dictionary(uniqueKeysWithValues: surah.rub.map { ($0[0], $0[1]) }) }

    /// Juz/hizb/quarter marker shown above the ayah where a rubʿ starts (same wording as the website).
    func rubLabel(_ rub: Int) -> String {
        let r = RubInfo(rub), fmt = { (n: Int) in n.formatted(.number.locale(lang.locale)) }
        let n = ["n": fmt(r.hizb)]
        switch r.quarter {
        case 1: return t(.rub1, lang, n)
        case 2: return t(.rub2, lang, n)
        case 3: return t(.rub3, lang, n)
        default: return (rub % 8 == 1 ? t(.juzN, lang, ["n": fmt(r.juz)]) + " · " : "") + t(.hizbN, lang, n)
        }
    }

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
                        let rubs = rubAt
                        ForEach(Array(surah.ayahs.enumerated()), id: \.offset) { i, text in
                            let a = i + 1
                            let playing = isCurrent && player.currentAyah == a
                            VStack(alignment: .leading, spacing: 2) {
                                if let rub = rubs[a] {
                                    HStack(spacing: 10) {
                                        Rectangle().fill(Theme.gold.opacity(0.35)).frame(height: 1)
                                        Text(rubLabel(rub)).font(Theme.plex(12, semibold: true)).foregroundStyle(Theme.gold).fixedSize()
                                        Rectangle().fill(Theme.gold.opacity(0.35)).frame(height: 1)
                                    }
                                    .environment(\.layoutDirection, lang.isRTL ? .rightToLeft : .leftToRight)
                                    .padding(.top, 10)
                                }
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
                            HStack(spacing: 14) {
                                Button(t(.tafsir, lang), systemImage: "book") { tafsirAyah = TafsirAyah(surah: surah.n, ayah: a) }
                                let saved = isBookmarked(settings.d.bookmarks ?? [], surah: surah.n, ayah: a)
                                Button(t(saved ? .removeBookmark : .bookmark, lang), systemImage: saved ? "bookmark.fill" : "bookmark") {
                                    settings.d.bookmarks = toggleBookmark(settings.d.bookmarks ?? [], surah: surah.n, ayah: a, now: Date())
                                }
                                .foregroundStyle(saved ? Theme.gold : Theme.soft)
                            }
                            .buttonStyle(.borderless).font(Theme.plex(11)).foregroundStyle(Theme.soft)
                            .padding(.horizontal, 16)
                            }
                            .id(a)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 860)
                    .frame(maxWidth: .infinity)
                    .environment(\.layoutDirection, .rightToLeft)
                }
                .onAppear {
                    let start = startAyah ?? (settings.d.lastSurah == surah.n ? settings.d.lastAyah : 1)
                    if let startAyah { settings.d.lastAyah = startAyah }
                    if start > 1 { proxy.scrollTo(start, anchor: .top) }
                }
                .onChange(of: player.currentAyah) { _, a in
                    guard isCurrent, let a else { return }
                    settings.d.lastAyah = a
                    withAnimation { proxy.scrollTo(a, anchor: .center) }
                }
            }
        }
        .sheet(item: $tafsirAyah) { TafsirSheet(item: $0, lang: lang) }
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

struct TafsirAyah: Identifiable { let surah, ayah: Int; var id: Int { surah * 1000 + ayah } }

/// Tafsir of one ayah, fetched from quran.com (URLCache keeps it per the API's cache headers).
struct TafsirSheet: View {
    let item: TafsirAyah
    let lang: Lang
    @Environment(\.dismiss) private var dismiss
    @State private var texts: [[String]]?
    @State private var failed = false
    var sources: [TafsirSource] { TafsirSource.forLang(lang) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(t(.tafsir, lang)) · \(QuranText.surahs[item.surah - 1].ar) \(arabicDigits(item.ayah))").font(Theme.kufi(18))
                Spacer()
                Button(t(.cancel, lang), systemImage: "xmark.circle.fill") { dismiss() }.labelStyle(.iconOnly).buttonStyle(.borderless)
                    .keyboardShortcut(.cancelAction)
            }
            if failed {
                Label(t(.loadFailed, lang), systemImage: "wifi.slash").foregroundStyle(Theme.gold)
                Button(t(.retry, lang)) { Task { await load() } }.buttonStyle(GoldOutlineButtonStyle())
            } else if let texts {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(sources.enumerated()), id: \.offset) { i, src in
                            VStack(alignment: .leading, spacing: 8) {
                                if sources.count > 1 { Text(src.name).font(Theme.plex(13, semibold: true)).foregroundStyle(Theme.gold) }
                                ForEach(Array(texts[i].enumerated()), id: \.offset) { _, p in
                                    Text(p).font(src.isArabic ? .custom("Amiri", size: 18) : Theme.plex(14)).lineSpacing(src.isArabic ? 8 : 3)
                                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .environment(\.layoutDirection, src.isArabic ? .rightToLeft : .leftToRight)
                        }
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .frame(width: 560, height: 520, alignment: .top)
        .environment(\.layoutDirection, lang.isRTL ? .rightToLeft : .leftToRight)
        .task { await load() }
    }

    func load() async {
        failed = false
        struct API: Decodable { struct T: Decodable { let text: String }; let tafsir: T }
        do {
            var out: [[String]] = []
            for src in sources {
                let (data, _) = try await URLSession.shared.data(from: src.url(surah: item.surah, ayah: item.ayah))
                out.append(tafsirText(try JSONDecoder().decode(API.self, from: data).tafsir.text))
            }
            texts = out
        } catch { failed = true }
    }
}
