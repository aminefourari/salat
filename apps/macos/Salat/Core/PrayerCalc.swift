import Adhan
import Foundation

// Port of apps/web/src/lib/prayer.ts.

enum Prayer: String, CaseIterable, Codable, Sendable { case fajr, dhuhr, asr, maghrib, isha }

struct DayTimes: Equatable, Sendable {
    let fajr, sunrise, dhuhr, asr, maghrib, isha: Date
    subscript(p: Prayer) -> Date {
        switch p { case .fajr: fajr; case .dhuhr: dhuhr; case .asr: asr; case .maghrib: maghrib; case .isha: isha }
    }
}

/// Prayer times for calendar day `date` (year/month/day) at lat/lon. nil where the sun math has no answer (polar).
func computeDay(lat: Double, lon: Double, date: DateComponents, method: MethodId, asr: AsrSchool) -> DayTimes? {
    let d = DateComponents(calendar: Calendar(identifier: .gregorian), year: date.year, month: date.month, day: date.day)
    var p = params(for: method, asr: asr)
    let rounding = p.rounding
    p.rounding = .none // round below the way adhan-js does, so both apps agree to the minute
    guard let pt = PrayerTimes(coordinates: Coordinates(latitude: lat, longitude: lon), date: d,
                               calculationParameters: p) else { return nil }
    let r = { (t: Date) in jsRoundedMinute(t, rounding) }
    return DayTimes(fajr: r(pt.fajr), sunrise: r(pt.sunrise), dhuhr: r(pt.dhuhr), asr: r(pt.asr), maghrib: r(pt.maghrib), isha: r(pt.isha))
}

/// Per-prayer offsets are limited to ±30 min (like the website's MAX_ADJUST).
let maxAdjust = 30

/// `d` with the user's per-prayer minute offsets (local mosque) on top of the calculation or the Habous timetable.
func adjustDay(_ d: DayTimes, _ adjust: [Prayer: Int]?) -> DayTimes {
    guard let a = adjust, !a.isEmpty else { return d }
    func m(_ p: Prayer) -> Date { d[p] + Double(a[p] ?? 0) * 60 }
    return DayTimes(fajr: m(.fajr), sunrise: d.sunrise, dhuhr: m(.dhuhr), asr: m(.asr), maghrib: m(.maghrib), isha: m(.isha))
}

/// Days added to the Umm al-Qura date: the user's choice, else −1 in Morocco (sighting usually a day after Makkah).
func hijriOffset(method: MethodId, chosen: Int?) -> Int { chosen ?? (method == .morocco ? -1 : 0) }

/// Hijri month (9 = Ramadan) of `d` shifted by `offset` days.
func hijriMonth(_ d: Date, offset: Int) -> Int {
    var cal = Calendar(identifier: .islamicUmmAlQura); cal.timeZone = .autoupdatingCurrent
    return cal.component(.month, from: d + Double(offset) * 86_400)
}

/// Imsak: the customary 10 minutes before Fajr, when suhoor stops.
func imsak(_ d: DayTimes) -> Date { d.fajr - 600 }

/// adhan-js `roundedMinute`: `.up` always adds (60 − seconds), so an exact :00 still moves to the next minute.
func jsRoundedMinute(_ t: Date, _ rounding: Rounding) -> Date {
    let sec = Int(t.timeIntervalSince1970.rounded(.down)) % 60
    switch rounding {
    case .nearest: return t.addingTimeInterval(Double(sec >= 30 ? 60 - sec : -sec))
    case .up: return t.addingTimeInterval(Double(60 - sec))
    case .none: return t
    }
}

/// Calendar day of `d` in `tz`, as year/month/day.
func dayComponents(_ d: Date, in tz: TimeZone = .autoupdatingCurrent) -> DateComponents {
    var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
    return cal.dateComponents([.year, .month, .day], from: d)
}

/// The next prayer after `now`: today's if any remain, else tomorrow's Fajr.
func nextPrayer(today: DayTimes, tomorrow: DayTimes, now: Date) -> (prayer: Prayer, at: Date) {
    if let p = Prayer.allCases.first(where: { today[$0] > now }) { return (p, today[p]) }
    return (.fajr, tomorrow.fajr)
}

func qiblaBearing(lat: Double, lon: Double) -> Double { Qibla(coordinates: Coordinates(latitude: lat, longitude: lon)).direction }

/// Great-circle distance to the Kaaba in km.
func kaabaDistanceKm(lat: Double, lon: Double) -> Double {
    let r = Double.pi / 180, kLat = 21.4225, kLon = 39.8262
    let dLat = (kLat - lat) * r, dLon = (kLon - lon) * r
    let h = pow(sin(dLat / 2), 2) + cos(lat * r) * cos(kLat * r) * pow(sin(dLon / 2), 2)
    return 12742 * asin(h.squareRoot())
}

/// 0..7 index into N, NE, E, SE, S, SW, W, NW.
func compass8(_ deg: Double) -> Int { Int(((deg.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 45).rounded()) % 8 }

func flag(_ cc: String) -> String {
    String(String.UnicodeScalarView(cc.uppercased().unicodeScalars.compactMap { Unicode.Scalar(127397 + $0.value) }))
}

/// Port of skyAt in prayer.ts: the period that tints the background.
enum Sky: Sendable { case night, dawn, day, afternoon, dusk }

func skyAt(_ d: DayTimes, _ now: Date) -> Sky {
    if now < d.fajr || now >= d.isha { return .night }
    if now < d.sunrise { return .dawn }
    if now < d.asr { return .day }
    if now < d.maghrib { return .afternoon }
    return .dusk
}

/// Fraction of the wait elapsed between the previous prayer and the next one (website's hero progress bar).
func waitProgress(today: DayTimes, nextAt: Date, now: Date) -> Double {
    let prev = Prayer.allCases.map { today[$0] }.filter { $0 <= now }.last ?? today.isha - 86_400
    return min(1, max(0, now.timeIntervalSince(prev) / nextAt.timeIntervalSince(prev)))
}
