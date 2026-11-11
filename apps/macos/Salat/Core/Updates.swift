import Foundation

// In-app updates from our Worker's /api/update (apps/web/src/server/update.ts), which serves the latest GitHub Release.

let updateEndpoint = URL(string: "https://salat.aminethewiz18.workers.dev/api/update")!

/// The latest release: its version, the zip's SHA-256 (hex) and size, and its release notes.
struct UpdateInfo: Codable, Equatable, Sendable {
    let version: String
    let sha256: String
    let size: Int
    let notes: String

    var downloadURL: URL {
        var c = URLComponents(url: updateEndpoint, resolvingAgainstBaseURL: false)!
        c.queryItems = [.init(name: "v", value: version)]
        return c.url!
    }
}

/// "1.10.0" > "1.9.2": numeric, part by part; anything that isn't x.y.z is never newer.
func isNewer(_ candidate: String, than current: String) -> Bool {
    func parts(_ v: String) -> [Int]? {
        let p = v.split(separator: ".").map { Int($0) }
        return p.count == 3 && p.allSatisfy { $0 != nil } ? p.map { $0! } : nil
    }
    guard let a = parts(candidate), let b = parts(current) else { return false }
    return a.lexicographicallyPrecedes(b) == false && a != b
}
