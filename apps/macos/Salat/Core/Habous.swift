import Foundation

// Official Moroccan timetable (Ministry of Habous), served by our Worker's /api/habous
// (apps/web/src/server/habous.ts). The calculation (Fajr 19°, Isha 17°) is the fallback.

let habousEndpoint = URL(string: "https://salat.aminethewiz18.workers.dev/api/habous")!

/// Morocco with the standard Asr uses the official timetable, like the website's `usesHabous`.
func usesHabous(method: MethodId, asr: AsrSchool) -> Bool { method == .morocco && asr == .standard }

/// Official days for one place, fetched a month at a time from the Worker and kept:
/// date (YYYY-MM-DD) → Fajr, sunrise, Dhuhr, Asr, Maghrib, Isha in epoch ms.
struct HabousDays: Codable, Equatable, Sendable {
    var place: String
    var days: [String: [Double]]
}

/// Cache key for a location, rounded like the website's request (≈100 m).
func habousPlace(lat: Double, lon: Double) -> String { String(format: "%.3f,%.3f", lat, lon) }

func isoDate(_ c: DateComponents) -> String { String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0) }

func habousURL(place: String, month: String) -> URL {
    let ll = place.split(separator: ",")
    var c = URLComponents(url: habousEndpoint, resolvingAgainstBaseURL: false)!
    c.queryItems = [.init(name: "lat", value: String(ll[0])), .init(name: "lon", value: String(ll[1])), .init(name: "month", value: month)]
    return c.url!
}

/// Official times for `date`, when the cache is for `place` and has that day.
func habousDay(_ h: HabousDays?, place: String, date: DateComponents) -> DayTimes? {
    guard let h, h.place == place, let ms = h.days[isoDate(date)], ms.count == 6 else { return nil }
    let d = ms.map { Date(timeIntervalSince1970: $0 / 1000) }
    return DayTimes(fajr: d[0], sunrise: d[1], dhuhr: d[2], asr: d[3], maghrib: d[4], isha: d[5])
}

/// The month (YYYY-MM) to fetch so that today and tomorrow are official, or nil when the cache has both.
func habousMonthToFetch(_ h: HabousDays?, place: String, today: DateComponents, tomorrow: DateComponents) -> String? {
    for d in [today, tomorrow] where habousDay(h, place: place, date: d) == nil { return String(isoDate(d).prefix(7)) }
    return nil
}

/// Adds a fetched month: same place keeps the days from `keepFrom` on (so yesterday stays for late alerts), another place replaces.
func mergeHabous(_ old: HabousDays?, place: String, fetched: [String: [Double]], keepFrom: String) -> HabousDays {
    var days = old?.place == place ? old!.days.filter { $0.key >= keepFrom } : [:]
    days.merge(fetched) { _, new in new }
    return HabousDays(place: place, days: days)
}
