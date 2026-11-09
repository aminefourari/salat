import Foundation

/// Offline country lookup over the web's own country-coder borders (exported to borders.json by apps/web/test/mac-data.test.ts).
final class CountryLookup: Sendable {
    static let shared = CountryLookup()

    private struct Poly: Sendable { let cc: String?; let rings: [[SIMD2<Double>]]; let minX, minY, maxX, maxY: Double }
    private let polys: [Poly]

    init(bundle: Bundle = .main) {
        struct Entry: Decodable { let cc: String?; let polys: [[[[Double]]]] }
        let url = bundle.url(forResource: "borders", withExtension: "json")!
        let entries = try! JSONDecoder().decode([Entry].self, from: Data(contentsOf: url))
        polys = entries.flatMap { e in
            e.polys.map { p in
                let rings = p.map { $0.map { SIMD2($0[0], $0[1]) } }
                let outer = rings[0]
                return Poly(cc: e.cc, rings: rings,
                            minX: outer.map(\.x).min()!, minY: outer.map(\.y).min()!,
                            maxX: outer.map(\.x).max()!, maxY: outer.map(\.y).max()!)
            }
        }
    }

    func code(lat: Double, lon: Double) -> String? {
        let pt = SIMD2(lon, lat)
        for p in polys where lon >= p.minX && lon <= p.maxX && lat >= p.minY && lat <= p.maxY {
            if Self.inside(pt, p.rings[0]) && !p.rings.dropFirst().contains(where: { Self.inside(pt, $0) }) { return p.cc }
        }
        return nil
    }

    /// Even-odd ray casting.
    private static func inside(_ p: SIMD2<Double>, _ ring: [SIMD2<Double>]) -> Bool {
        var c = false
        var j = ring.count - 1
        for i in 0..<ring.count {
            let a = ring[i], b = ring[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { c.toggle() }
            j = i
        }
        return c
    }
}

struct City: Codable, Hashable, Sendable { let name: String; let lat, lon: Double; let cc: String }

/// GeoNames towns ≥ 5000 people (same list the Worker uses), bundled as cities.txt: `name|lat|lon|cc` per line.
final class CityIndex: Sendable {
    static let shared = CityIndex()
    private let cities: [City]
    private let folded: [String]

    init(bundle: Bundle = .main) {
        let text = try! String(contentsOf: bundle.url(forResource: "cities", withExtension: "txt")!, encoding: .utf8)
        cities = text.split(separator: "\n").compactMap { l in
            let f = l.split(separator: "|", omittingEmptySubsequences: false)
            guard f.count == 4, let lat = Double(f[1]), let lon = Double(f[2]) else { return nil }
            return City(name: String(f[0]), lat: lat, lon: lon, cc: String(f[3]))
        }
        folded = cities.map { Self.fold($0.name) }
    }

    private static func fold(_ s: String) -> String { s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }

    /// Nearest town within `maxKm`, or nil. Port of nearestCity in apps/web/src/server/cities.ts.
    // ponytail: linear scan of 70k rows (~1 ms), add a grid index if it ever shows up.
    func nearest(lat: Double, lon: Double, maxKm: Double = 50) -> City? {
        let k = cos(lat * .pi / 180)
        var best = -1, bestD = Double.infinity
        for (i, c) in cities.enumerated() {
            let dLat = c.lat - lat
            var dLon = abs(c.lon - lon)
            if dLon > 180 { dLon = 360 - dLon }
            let d = dLat * dLat + dLon * k * (dLon * k)
            if d < bestD { bestD = d; best = i }
        }
        return best < 0 || bestD.squareRoot() * 111.2 > maxKm ? nil : cities[best]
    }

    /// Case- and accent-insensitive prefix search, shortest names first.
    func search(_ q: String, limit: Int = 20) -> [City] {
        let q = Self.fold(q.trimmingCharacters(in: .whitespaces))
        guard !q.isEmpty else { return [] }
        return folded.indices.filter { folded[$0].hasPrefix(q) }
            .sorted { (folded[$0].count, folded[$0]) < (folded[$1].count, folded[$1]) }
            .prefix(limit).map { cities[$0] }
    }
}
