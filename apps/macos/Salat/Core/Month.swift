import Foundation

/// One row of the monthly timetable (the website's /month).
struct MonthDay: Equatable, Sendable {
    let date: DateComponents
    let day: DayTimes
    /// From the official Habous timetable (only the months the app has fetched).
    let official: Bool
}

/// Every day of `month` (year + month): official Habous times when cached, calculated otherwise, then the user's
/// minute offsets: the same path `AlertEngine` takes for today, so the table matches the menu.
func monthDays(year: Int, month: Int, lat: Double, lon: Double, method: MethodId, asr: AsrSchool,
               adjust: [Prayer: Int]?, habous: HabousDays?) -> [MonthDay] {
    let cal = Calendar(identifier: .gregorian)
    guard let first = cal.date(from: DateComponents(year: year, month: month, day: 1)),
          let days = cal.range(of: .day, in: .month, for: first) else { return [] }
    let official = usesHabous(method: method, asr: asr)
    let place = habousPlace(lat: lat, lon: lon)
    return days.compactMap { d in
        let date = DateComponents(year: year, month: month, day: d)
        let h = official ? habousDay(habous, place: place, date: date) : nil
        guard let day = h ?? computeDay(lat: lat, lon: lon, date: date, method: method, asr: asr) else { return nil }
        return MonthDay(date: date, day: adjustDay(day, adjust), official: h != nil)
    }
}
