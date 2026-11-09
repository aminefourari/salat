import Foundation

/// quran.com chapter reciters that publish per-ayah timestamps (needed for read-along).
struct Reciter: Identifiable, Sendable {
    let id: Int
    let latin: String
    let arabic: String
    func name(_ l: Lang) -> String { l == .ar ? arabic : latin }

    static let all = [
        Reciter(id: 7, latin: "Mishary Rashid Alafasy", arabic: "مشاري راشد العفاسي"),
        Reciter(id: 3, latin: "Abdur-Rahman as-Sudais", arabic: "عبد الرحمن السديس"),
        Reciter(id: 10, latin: "Saud ash-Shuraim", arabic: "سعود الشريم"),
        Reciter(id: 6, latin: "Mahmoud Khalil al-Husary", arabic: "محمود خليل الحصري"),
        Reciter(id: 2, latin: "Abdul Basit Abdul Samad", arabic: "عبد الباسط عبد الصمد"),
        Reciter(id: 9, latin: "Mohamed Siddiq al-Minshawi", arabic: "محمد صديق المنشاوي"),
        Reciter(id: 97, latin: "Yasser ad-Dosari", arabic: "ياسر الدوسري"),
        Reciter(id: 4, latin: "Abu Bakr ash-Shatri", arabic: "أبو بكر الشاطري"),
    ]
}

struct AyahTiming: Codable, Equatable, Sendable {
    let ayah: Int
    let from: Int // ms
    let to: Int
}

struct Recitation: Sendable {
    let audioURL: URL
    let timings: [AyahTiming]

    /// Parses `GET /api/v4/chapter_recitations/{reciter}/{surah}?segments=true`.
    static func decodeAPI(_ data: Data) throws -> Recitation {
        struct API: Decodable {
            struct File: Decodable { let audio_url: URL; let timestamps: [TS] }
            struct TS: Decodable { let verse_key: String; let timestamp_from: Int; let timestamp_to: Int }
            let audio_file: File
        }
        let f = try JSONDecoder().decode(API.self, from: data).audio_file
        let timings = f.timestamps.compactMap { ts -> AyahTiming? in
            guard let a = ts.verse_key.split(separator: ":").last.flatMap({ Int($0) }) else { return nil }
            return AyahTiming(ayah: a, from: ts.timestamp_from, to: ts.timestamp_to)
        }
        return Recitation(audioURL: f.audio_url, timings: timings)
    }
}

/// Index of the ayah playing at `ms`: before the first → 0, past the last → last.
func ayahIndex(at ms: Int, in timings: [AyahTiming]) -> Int {
    var lo = 0, hi = timings.count - 1
    guard hi >= 0 else { return 0 }
    while lo < hi { // last timing with from <= ms
        let mid = (lo + hi + 1) / 2
        if timings[mid].from <= ms { lo = mid } else { hi = mid - 1 }
    }
    return lo
}

/// Recitations downloaded once and kept on disk: `{root}/{reciter}/{surah}.mp3` + `{surah}.json` (timings).
/// A surah counts as downloaded only when both exist; the MP3 lands via an atomic move, the JSON is written last.
final class RecitationStore: Sendable {
    static let shared = RecitationStore(root: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Salat/recitations"))

    let root: URL
    private let session: URLSession

    init(root: URL, session: URLSession = .shared) {
        self.root = root
        self.session = session
    }

    private func dir(_ reciter: Int) -> URL { root.appendingPathComponent("\(reciter)") }

    func local(reciter: Int, surah: Int) -> (audio: URL, timings: [AyahTiming])? {
        let mp3 = dir(reciter).appendingPathComponent("\(surah).mp3"), json = dir(reciter).appendingPathComponent("\(surah).json")
        guard FileManager.default.fileExists(atPath: mp3.path),
              let data = try? Data(contentsOf: json),
              let t = try? JSONDecoder().decode([AyahTiming].self, from: data) else { return nil }
        return (mp3, t)
    }

    func download(reciter: Int, surah: Int, progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws {
        if local(reciter: reciter, surah: surah) != nil { return }
        let api = URL(string: "https://api.quran.com/api/v4/chapter_recitations/\(reciter)/\(surah)?segments=true")!
        let (data, resp) = try await session.data(from: api)
        try Self.check(resp)
        let rec = try Recitation.decodeAPI(data)
        let d = dir(reciter)
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        let tmp = try await downloadFile(rec.audioURL, progress: progress)
        let mp3 = d.appendingPathComponent("\(surah).mp3")
        try? FileManager.default.removeItem(at: mp3)
        try FileManager.default.moveItem(at: tmp, to: mp3)
        try JSONEncoder().encode(rec.timings).write(to: d.appendingPathComponent("\(surah).json"), options: .atomic)
    }

    /// Downloads every surah not yet on disk, one after another. `progress` gets (surahs done, 114).
    func downloadAll(reciter: Int, progress: @escaping @Sendable (Int, Int) -> Void) async throws {
        for s in 1...114 {
            try Task.checkCancellation()
            try await download(reciter: reciter, surah: s)
            progress(s, 114)
        }
    }

    func downloadedCount(reciter: Int) -> Int {
        (1...114).filter { local(reciter: reciter, surah: $0) != nil }.count
    }

    func size(reciter: Int) -> Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir(reciter), includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    func delete(reciter: Int) { try? FileManager.default.removeItem(at: dir(reciter)) }

    private static func check(_ resp: URLResponse) throws {
        if let h = resp as? HTTPURLResponse, !(200..<300).contains(h.statusCode) { throw URLError(.badServerResponse) }
    }

    /// URLSession download with progress; returns a temp file we own.
    private func downloadFile(_ url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            let ownTmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp3")
            let task = session.downloadTask(with: url) { tmp, resp, err in
                if let err { return cont.resume(throwing: err) }
                do {
                    try Self.check(resp!)
                    try FileManager.default.moveItem(at: tmp!, to: ownTmp)
                    cont.resume(returning: ownTmp)
                } catch { cont.resume(throwing: error) }
            }
            let obs = task.progress.observe(\.fractionCompleted) { p, _ in progress(p.fractionCompleted) }
            objc_setAssociatedObject(task, "obs", obs, .OBJC_ASSOCIATION_RETAIN)
            task.resume()
        }
    }
}
