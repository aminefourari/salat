import AppKit
import AVFoundation
import Observation

struct AdhanVoice: Identifiable, Sendable {
    let id: String
    let names: (en: String, fr: String, ar: String)
    func name(_ l: Lang) -> String { l == .fr ? names.fr : l == .ar ? names.ar : names.en }

    static let all = [
        AdhanVoice(id: "hassan2", names: ("Hassan II Mosque, Casablanca", "Mosquée Hassan II, Casablanca", "مسجد الحسن الثاني، الدار البيضاء")),
        AdhanVoice(id: "fakhry", names: ("Sabah Fakhri", "Sabah Fakhri", "صباح فخري")),
        AdhanVoice(id: "beautiful", names: ("Adhan (calm)", "Adhan (calme)", "أذان هادئ")),
        AdhanVoice(id: "azan", names: ("Adhan (classic)", "Adhan (classique)", "أذان تقليدي")),
    ]
}

@MainActor @Observable
final class AdhanPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private(set) var isPlaying = false
    var onPlay: (() -> Void)?

    func play(_ id: String) {
        stop()
        guard let url = Bundle.main.url(forResource: id, withExtension: "m4a") ?? Bundle.main.url(forResource: "hassan2", withExtension: "m4a"),
              let p = try? AVAudioPlayer(contentsOf: url) else { NSSound.beep(); return }
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

