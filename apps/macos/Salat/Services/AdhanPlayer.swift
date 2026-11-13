import AppKit
import AVFoundation
import Observation

@MainActor @Observable
final class AdhanPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private(set) var isPlaying = false
    var onPlay: (() -> Void)?

    func play(_ id: String) {
        stop()
        // Not downloaded yet, broken (deleted by `playable`) or a deleted custom file: the bundled adhan plays instead,
        // never silence, and a missing download is fetched for next time.
        let url = AdhanStore.shared.playable(id)
        if AdhanStore.shared.local(id) == nil, let v = AdhanVoice.find(id) { Task.detached { try? await AdhanStore.shared.download(v) } }
        guard let url, let p = try? AVAudioPlayer(contentsOf: url) else { NSSound.beep(); return }
        p.delegate = self
        player = p
        isPlaying = p.play()
        onPlay?()
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    nonisolated func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully: Bool) {
        Task { @MainActor in self.stop() }
    }
}

