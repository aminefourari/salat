import Foundation

/// One dhikr of Hisn al-Muslim (bundled adhkar.json, built by scripts/fetch-adhkar.py).
struct Dhikr: Codable, Identifiable, Sendable {
    let id: Int
    let ar: String
    let en: String?
    let fr: String?
    let ref: String?
    let `repeat`: Int
    let countInText: Bool
    let audio: URL?

    enum CodingKeys: String, CodingKey { case id, ar, en, fr, ref, `repeat`, countInText = "count_in_text", audio }

    /// Translation in the UI language; none in Arabic. Hisn al-Muslim is translated into English and French only,
    /// so the other languages read the English one (same as the website).
    func translation(_ l: Lang) -> String? { l == .ar ? nil : l == .fr ? fr : en }

    /// "×N" only when the Arabic doesn't already state the count (the text wins over the feed's REPEAT field).
    var badge: Int? { `repeat` > 1 && !countInText ? `repeat` : nil }
}

struct AdhkarChapter: Codable, Identifiable, Sendable {
    let id: Int
    let ar: String
    let en: String
    let fr: String?
    let items: [Dhikr]

    func title(_ l: Lang) -> String { l == .ar ? ar : l == .fr ? (fr ?? en) : en }
}

enum AdhkarText {
    private final class Anchor {}
    static let chapters: [AdhkarChapter] = {
        let url = Bundle(for: Anchor.self).url(forResource: "adhkar", withExtension: "json")!
        return try! JSONDecoder().decode([AdhkarChapter].self, from: Data(contentsOf: url))
    }()
}

/// Per-dhikr recitations from hisnmuslim.com, downloaded on first play and kept: `{root}/{id}.mp3`.
final class AdhkarAudioStore: Sendable {
    static let shared = AdhkarAudioStore(root: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Salat/adhkar"))

    let root: URL
    private let session: URLSession
    private let downloads = SharedDownloads()

    init(root: URL, session: URLSession = .shared) {
        self.root = root
        self.session = session
    }

    private func file(_ d: Dhikr) -> URL { root.appendingPathComponent("\(d.id).mp3") }

    func local(_ d: Dhikr) -> URL? { FileManager.default.fileExists(atPath: file(d).path) ? file(d) : nil }

    func download(_ d: Dhikr) async throws {
        guard local(d) == nil, let url = d.audio else { return }
        try await downloads.run("\(d.id)") {
            try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
            try await self.session.downloadAtomically(url, to: self.file(d))
        }
    }

    var total: Int { AdhkarText.chapters.reduce(0) { $0 + $1.items.filter { $0.audio != nil }.count } }
    func downloadedCount() -> Int { AdhkarText.chapters.reduce(0) { $0 + $1.items.filter { local($0) != nil }.count } }

    func downloadAll(progress: @escaping @Sendable (Int, Int) -> Void) async throws {
        var done = downloadedCount()
        for d in AdhkarText.chapters.flatMap(\.items) where d.audio != nil && local(d) == nil {
            try Task.checkCancellation()
            try await download(d)
            done += 1
            progress(done, total)
        }
    }

    func size() -> Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    func delete() { try? FileManager.default.removeItem(at: root) }
}
