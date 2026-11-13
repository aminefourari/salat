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

/// Run by a detached `sh -c` after the app quits: $1 pid to wait for, $2 installed app, $3 new app, $4 work dir,
/// $5 command that opens an app (`open`; tests pass `true`). Never leaves $2 missing: on any failure the old app is put
/// back (a partial copy is removed first), and whatever is at $2 is reopened. Paths are arguments, never interpolated.
let updateSwapScript = """
while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
if ! mv "$2" "$4/old.app"; then "$5" "$2"; exit 1; fi
if mv "$3" "$2"; then
  rm -rf "$4"
else
  rm -rf "$2"
  mv "$4/old.app" "$2"
fi
xattr -dr com.apple.quarantine "$2" 2>/dev/null
"$5" "$2"
"""
