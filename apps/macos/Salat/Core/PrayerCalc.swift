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
