import SwiftUI

struct AdhkarView: View {
    @Bindable var settings: AppSettings
    let player: AdhkarPlayer
    @State private var selection: Int?
    @State private var query = ""

    var lang: Lang { settings.d.lang }

    var chapters: [AdhkarChapter] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return AdhkarText.chapters }
        let opts: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return AdhkarText.chapters.filter { $0.title(lang).range(of: q, options: opts) != nil || $0.ar.range(of: q, options: opts) != nil }
    }

    var body: some View {
        NavigationSplitView {
            List(chapters, selection: $selection) { c in
                Text(c.title(lang)).lineLimit(2).tag(c.id)
            }
            .searchable(text: $query, placement: .sidebar, prompt: t(.searchCategory, lang))
            .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        } detail: {
            if let id = selection, let c = AdhkarText.chapters.first(where: { $0.id == id }) {
                ChapterView(chapter: c, lang: lang, player: player).id(id)
            } else {
                Text(t(.chooseCategory, lang)).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(t(.adhkar, lang))
        .onAppear { if selection == nil { selection = settings.d.lastAdhkarChapter ?? AdhkarText.chapters.first?.id } }
        .onChange(of: selection) { _, id in if let id { settings.d.lastAdhkarChapter = id } }
        .environment(\.layoutDirection, lang.isRTL ? .rightToLeft : .leftToRight)
    }
}

private struct ChapterView: View {
    let chapter: AdhkarChapter
    let lang: Lang
    let player: AdhkarPlayer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(chapter.title(lang)).font(.title2.bold())
                if lang != .ar { Text(chapter.ar).font(.custom("Amiri", size: 20)).foregroundStyle(.secondary) }
                ForEach(chapter.items) { d in DhikrCard(d: d, lang: lang, player: player) }
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct DhikrCard: View {
    let d: Dhikr
    let lang: Lang
    let player: AdhkarPlayer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(d.ar)
                .font(.custom("Amiri", size: 24))
                .lineSpacing(10)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .rightToLeft)
            if let tr = d.translation(lang) {
                Text(tr).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                if let n = d.badge {
                    Text("×\(n.formatted(.number.locale(lang.locale)))").font(.callout.bold().monospacedDigit())
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: .capsule)
                }
                if let ref = d.ref { Text(ref).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                if let m = player.message, m.id == d.id { Text(m.text).font(.caption).foregroundStyle(.orange) }
                if d.audio != nil { playButton }
            }
        }
        .padding(16)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
    }

    @ViewBuilder var playButton: some View {
        if player.loading == d.id {
            ProgressView().controlSize(.small)
        } else if player.playing == d.id {
            Button(t(.pause, lang), systemImage: "stop.fill") { player.stop() }.labelStyle(.iconOnly)
        } else {
            Button(t(.play, lang), systemImage: "play.fill") { Task { await player.play(d, lang: lang) } }.labelStyle(.iconOnly)
        }
    }
}

/// Settings section: download / delete all adhkar audio.
struct AdhkarAudioSection: View {
    let player: AdhkarPlayer
    let lang: Lang
    @State private var refresh = 0

    var body: some View {
        let _ = refresh
        let store = player.store
        let count = player.bulk ?? store.downloadedCount()
        Section(t(.adhkarAudio, lang)) {
            HStack {
                VStack(alignment: .leading) {
                    Text("\(count)/\(store.total) · \(ByteCountFormatter.string(fromByteCount: store.size(), countStyle: .file))")
                        .font(.caption).foregroundStyle(.secondary)
                    if let e = player.bulkError {
                        Text(e == "offline" ? t(.needsInternet, lang) : e).font(.caption).foregroundStyle(.orange)
                    }
                }
                Spacer()
                if player.bulk != nil {
                    ProgressView(value: Double(count), total: Double(store.total)).frame(width: 80)
                    Button(t(.cancel, lang), systemImage: "xmark.circle") { player.cancelDownload() }.labelStyle(.iconOnly)
                } else if count < store.total {
                    Button(t(.downloadAll, lang)) { player.downloadAll() }
                }
                if count > 0 {
                    Button(t(.delete, lang), systemImage: "trash") { player.deleteAll(); refresh += 1 }.labelStyle(.iconOnly)
                }
            }
        }
    }
}
