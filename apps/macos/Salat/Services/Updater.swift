import AppKit
import CryptoKit
import Observation

/// Checks our Worker for a newer release (at launch, then daily), downloads the zip, checks its SHA-256 and code
/// signature, and replaces this Salat.app once it has quit, then relaunches it.
@MainActor @Observable
final class Updater {
    enum State: Equatable {
        case idle, checking, upToDate, failed(String)
        case available(UpdateInfo)
        case downloading(UpdateInfo, Double)
        case installing
    }

    private(set) var state = State.idle
    let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    private let settings: AppSettings
    private var timer: Timer?

    var available: UpdateInfo? {
        switch state { case .available(let i), .downloading(let i, _): i; default: nil }
    }

    init(settings: AppSettings) {
        self.settings = settings
        guard Snapshots.dir == nil else { return }
        // Daily, plus a first check shortly after launch (let location and alerts settle first).
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.autoCheck() }
        }
        Task { try? await Task.sleep(for: .seconds(10)); autoCheck() }
    }

    private func autoCheck() {
        guard settings.d.autoUpdateCheck != false else { return }
        switch state { case .idle, .upToDate, .failed: Task { await check() }; default: break }
    }

    func check() async {
        state = .checking
        do {
            let (data, res) = try await URLSession.shared.data(from: updateEndpoint)
            guard (res as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.server }
            let info = try JSONDecoder().decode(UpdateInfo.self, from: data)
            state = isNewer(info.version, than: current) ? .available(info) : .upToDate
        } catch {
            state = .failed(QuranPlayer.isOffline(error) ? t(.needsInternet, settings.d.lang) : t(.updateFailed, settings.d.lang))
        }
    }

    func install() {
        guard case .available(let info) = state else { return }
        Task { await install(info) }
    }

    private func install(_ info: UpdateInfo) async {
        state = .downloading(info, 0)
        do {
            let app = Bundle.main.bundleURL
            guard FileManager.default.isWritableFile(atPath: app.deletingLastPathComponent().path) else { throw UpdateError.notWritable }
            let work = FileManager.default.temporaryDirectory.appendingPathComponent("salat-update-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            let zip = try await download(info, to: work.appendingPathComponent("Salat.zip"))
            // Integrity: the digest GitHub computed for the release asset.
            let digest = SHA256.hash(data: try Data(contentsOf: zip, options: .mappedIfSafe)).map { String(format: "%02x", $0) }.joined()
            guard digest == info.sha256.lowercased() else { throw UpdateError.checksum }
            state = .installing
            try run("/usr/bin/ditto", ["-x", "-k", zip.path, work.path])
            let new = work.appendingPathComponent("Salat.app")
            // The new app must be intact (signature seals every file) and really be this app at that version.
            try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", new.path])
            let plist = Bundle(url: new)?.infoDictionary
            guard plist?["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
                  plist?["CFBundleShortVersionString"] as? String == info.version else { throw UpdateError.wrongApp }
            try swapAndRelaunch(old: app, new: new, work: work)
            NSApp.terminate(nil)
        } catch {
            state = .failed((error as? UpdateError).map { t($0.key, settings.d.lang) }
                ?? (QuranPlayer.isOffline(error) ? t(.needsInternet, settings.d.lang) : t(.updateFailed, settings.d.lang)))
        }
    }

    private func download(_ info: UpdateInfo, to dest: URL) async throws -> URL {
        let (bytes, res) = try await URLSession.shared.bytes(from: info.downloadURL)
        guard (res as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.server }
        let total = max(Int(res.expectedContentLength), info.size, 1)
        var data = Data(); data.reserveCapacity(total)
        var buf = [UInt8](); buf.reserveCapacity(1 << 16)
        for try await b in bytes {
            buf.append(b)
            if buf.count == 1 << 16 { data.append(contentsOf: buf); buf.removeAll(keepingCapacity: true); state = .downloading(info, Double(data.count) / Double(total)) }
        }
        data.append(contentsOf: buf)
        try data.write(to: dest)
        return dest
    }

    /// A detached shell waits for this process to quit, swaps the bundles (restoring the old one if the move
    /// fails), clears quarantine and opens the new app. The login item points at the same path, so it keeps working.
    private func swapAndRelaunch(old: URL, new: URL, work: URL) throws {
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        mv "$2" "$4/old.app" || exit 1
        if mv "$3" "$2"; then rm -rf "$4"; else mv "$4/old.app" "$2"; fi
        xattr -dr com.apple.quarantine "$2" 2>/dev/null
        open "$2"
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", script, "salat-update", String(ProcessInfo.processInfo.processIdentifier), old.path, new.path, work.path]
        try p.run()
    }

    private func run(_ tool: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw UpdateError.wrongApp }
    }
}

enum UpdateError: Error {
    case server, checksum, wrongApp, notWritable
    var key: L10nKey {
        switch self {
        case .server: .updateFailed
        case .checksum, .wrongApp: .updateCorrupt
        case .notWritable: .updateNotWritable
        }
    }
}
