import AVFoundation
import Observation

@MainActor @Observable
final class AdhkarPlayer: NSObject, AVAudioPlayerDelegate {
    let store: AdhkarAudioStore
    private(set) var playing: Int?
    private(set) var loading: Int?
    private(set) var message: (id: Int, text: String)?
    /// Whole-collection download: audio files on disk while it runs, nil otherwise.
    private(set) var bulk: Int?
    private(set) var bulkError: String?
    var onPlay: (() -> Void)?
    private var player: AVAudioPlayer?
    private var request = 0
    private var bulkTask: Task<Void, Never>?

    init(store: AdhkarAudioStore = .shared) { self.store = store }

    func play(_ d: Dhikr, lang: Lang) async {
        stop()
        request += 1
        let req = request
        message = nil
        if store.local(d) == nil {
            loading = d.id
            do { try await store.download(d) } catch {
                guard req == request else { return }
                loading = nil
                if !QuranPlayer.isCancel(error) {
                    message = (d.id, QuranPlayer.isOffline(error) ? t(.needsInternet, lang) : error.localizedDescription)
                }
                return
            }
            guard req == request else { return }
            loading = nil
        }
        guard let url = store.local(d), let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.delegate = self
        player = p
        if p.play() { playing = d.id; onPlay?() }
    }

    func stop() {
        request += 1
        player?.stop()
        player = nil
        playing = nil
        loading = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully: Bool) {
        let finished = ObjectIdentifier(p)
        Task { @MainActor in if self.player.map(ObjectIdentifier.init) == finished { self.player = nil; self.playing = nil } }
    }

    func downloadAll() {
        guard bulkTask == nil else { return }
        bulk = store.downloadedCount()
        bulkError = nil
        bulkTask = Task {
            do {
                try await store.downloadAll { done, _ in Task { @MainActor in if self.bulkTask != nil { self.bulk = done } } }
            } catch where !QuranPlayer.isCancel(error) {
                bulkError = QuranPlayer.isOffline(error) ? "offline" : error.localizedDescription
            } catch {}
            bulk = nil
            bulkTask = nil
        }
    }

    func cancelDownload() { bulkTask?.cancel() }

    func deleteAll() {
        cancelDownload()
        stop()
        store.delete()
    }
}
