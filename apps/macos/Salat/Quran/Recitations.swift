import Foundation
import Synchronization

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
    /// One download per surah at a time: later callers wait for the running one.
    private let inflight = Mutex<[String: Task<Void, Error>]>([:])

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
        let key = "\(reciter)/\(surah)"
        let task = inflight.withLock { running in
            if let t = running[key] { return t }
            let t = Task {
                defer { _ = self.inflight.withLock { $0.removeValue(forKey: key) } }
                try await self.fetch(reciter: reciter, surah: surah, progress: progress)
            }
            running[key] = t
            return t
        }
        try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
    }

    private func fetch(reciter: Int, surah: Int, progress: @escaping @Sendable (Double) -> Void) async throws {
        let api = URL(string: "https://api.quran.com/api/v4/chapter_recitations/\(reciter)/\(surah)?segments=true")!
        let (data, resp) = try await session.data(from: api)
        try Self.check(resp)
        let rec = try Recitation.decodeAPI(data)
        let d = dir(reciter)
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        let (tmp, resp2) = try await session.download(from: rec.audioURL, delegate: ProgressObserver(progress))
        defer { try? FileManager.default.removeItem(at: tmp) }
        try Self.check(resp2)
        let mp3 = d.appendingPathComponent("\(surah).mp3")
        try? FileManager.default.removeItem(at: mp3)
        try FileManager.default.moveItem(at: tmp, to: mp3)
        try JSONEncoder().encode(rec.timings).write(to: d.appendingPathComponent("\(surah).json"), options: .atomic)
    }

    /// Downloads every surah not yet on disk, one after another. `progress` gets (surahs on disk, 114).
    func downloadAll(reciter: Int, progress: @escaping @Sendable (Int, Int) -> Void) async throws {
        var done = downloadedCount(reciter: reciter)
        for s in 1...114 where local(reciter: reciter, surah: s) == nil {
            try Task.checkCancellation()
            try await download(reciter: reciter, surah: s)
            done += 1
            progress(done, 114)
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
}

/// Forwards a download task's progress.
private final class ProgressObserver: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let onProgress: @Sendable (Double) -> Void
    private var observation: NSKeyValueObservation?
    init(_ onProgress: @escaping @Sendable (Double) -> Void) { self.onProgress = onProgress }
    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        observation = task.progress.observe(\.fractionCompleted) { [onProgress] p, _ in onProgress(p.fractionCompleted) }
    }
}
