import AVFoundation
import MediaPlayer
import Observation

@MainActor @Observable
final class QuranPlayer {
    enum State: Equatable { case idle, downloading(Double), needsInternet, error(String), ready }

    private(set) var surah: Int?
    private(set) var reciter = 7
    private(set) var timings: [AyahTiming] = []
    private(set) var currentAyah: Int?
    private(set) var isPlaying = false
    private(set) var state: State = .idle
    /// Whole-reciter downloads in progress: reciter → surahs done.
    private(set) var bulk: [Int: Int] = [:]
    private(set) var bulkError: [Int: String] = [:]

    let store = RecitationStore.shared
    private let player = AVPlayer()
    private var request = 0
    private var bulkTasks: [Int: Task<Void, Never>] = [:]

    init() {
        player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 10), queue: .main) { [weak self] t in
            MainActor.assumeIsolated { self?.update(t) }
        }
        NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isPlaying = false; self?.publishNowPlaying() }
        }
        let rc = MPRemoteCommandCenter.shared()
        rc.playCommand.addTarget { [weak self] _ in MainActor.assumeIsolated { self?.resume() }; return .success }
        rc.pauseCommand.addTarget { [weak self] _ in MainActor.assumeIsolated { self?.pause() }; return .success }
        rc.togglePlayPauseCommand.addTarget { [weak self] _ in MainActor.assumeIsolated { self?.toggle() }; return .success }
        rc.nextTrackCommand.addTarget { [weak self] _ in MainActor.assumeIsolated { self?.next() }; return .success }
        rc.previousTrackCommand.addTarget { [weak self] _ in MainActor.assumeIsolated { self?.previous() }; return .success }
    }

    /// Plays `surah` with `reciter` from `fromAyah`, downloading it first if needed.
    func play(surah: Int, reciter: Int, fromAyah: Int = 1) async {
        if self.surah == surah, self.reciter == reciter, state == .ready {
            seek(toAyah: fromAyah); resume(); return
        }
        request += 1
        let req = request
        pause()
        self.surah = surah; self.reciter = reciter; timings = []; currentAyah = nil
        if store.local(reciter: reciter, surah: surah) == nil {
            state = .downloading(0)
            do {
                try await store.download(reciter: reciter, surah: surah) { p in
                    Task { @MainActor in if self.request == req, case .downloading = self.state { self.state = .downloading(p) } }
                }
            } catch {
                guard request == req else { return }
                state = Self.isOffline(error) ? .needsInternet : .error(error.localizedDescription)
                return
            }
        }
        guard request == req, let local = store.local(reciter: reciter, surah: surah) else { return }
        player.replaceCurrentItem(with: AVPlayerItem(url: local.audio))
        timings = local.timings
        state = .ready
        seek(toAyah: fromAyah)
        resume()
    }

    func resume() { guard state == .ready else { return }; player.play(); isPlaying = true; publishNowPlaying() }
    func pause() { player.pause(); isPlaying = false; publishNowPlaying() }
    func toggle() { isPlaying ? pause() : resume() }
    func next() { if let a = currentAyah, a < timings.count { seek(toAyah: a + 1) } }
    func previous() { if let a = currentAyah, a > 1 { seek(toAyah: a - 1) } }

    func seek(toAyah a: Int) {
        guard let t = timings.first(where: { $0.ayah == a }) else { return }
        currentAyah = a
        player.seek(to: CMTime(value: CMTimeValue(t.from), timescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func update(_ t: CMTime) {
        guard !timings.isEmpty, t.isNumeric else { return }
        let a = timings[ayahIndex(at: Int(t.seconds * 1000), in: timings)].ayah
        if a != currentAyah { currentAyah = a }
    }

    // MARK: whole-reciter downloads

    func downloadAll(reciter: Int) {
        guard bulkTasks[reciter] == nil else { return }
        bulk[reciter] = store.downloadedCount(reciter: reciter)
        bulkError[reciter] = nil
        bulkTasks[reciter] = Task {
            do {
                try await store.downloadAll(reciter: reciter) { done, _ in Task { @MainActor in self.bulk[reciter] = done } }
            } catch {
                bulkError[reciter] = Self.isOffline(error) ? "offline" : error.localizedDescription
            }
            bulk[reciter] = nil
            bulkTasks[reciter] = nil
        }
    }

    func cancelDownload(reciter: Int) { bulkTasks[reciter]?.cancel() }

    func delete(reciter: Int) {
        cancelDownload(reciter: reciter)
        if self.reciter == reciter { player.replaceCurrentItem(with: nil); state = .idle; isPlaying = false; surah = nil }
        store.delete(reciter: reciter)
    }

    static func isOffline(_ e: Error) -> Bool {
        [.notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .timedOut, .dataNotAllowed]
            .contains((e as? URLError)?.code)
    }

    private func publishNowPlaying() {
        guard let s = surah else { MPNowPlayingInfoCenter.default().nowPlayingInfo = nil; return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "\(QuranText.surahs[s - 1].ar) — \(QuranText.surahs[s - 1].en)",
            MPMediaItemPropertyArtist: Reciter.all.first { $0.id == reciter }?.latin ?? "",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime().seconds,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }
}
