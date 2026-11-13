import XCTest

final class MonthTests: XCTestCase {
    func testCalculatedMonthMatchesTheDayPath() {
        let rows = monthDays(year: 2026, month: 11, lat: 53.4319, lon: 11.1903, method: .aachen, asr: .standard, adjust: [.maghrib: 3], habous: nil)
        XCTAssertEqual(rows.count, 30)
        let d8 = computeDay(lat: 53.4319, lon: 11.1903, date: DateComponents(year: 2026, month: 11, day: 8), method: .aachen, asr: .standard)!
        XCTAssertEqual(rows[7].day, adjustDay(d8, [.maghrib: 3]))
        XCTAssertFalse(rows.contains { $0.official })
        XCTAssertEqual(monthDays(year: 2028, month: 2, lat: 0, lon: 0, method: .mwl, asr: .standard, adjust: nil, habous: nil).count, 29)
    }

    func testUsesCachedHabousDaysInMorocco() {
        let place = habousPlace(lat: 33.5731, lon: -7.5898)
        let ms: [Double] = [1794374880000, 1794380100000, 1794399600000, 1794409800000, 1794418500000, 1794423060000]
        let h = HabousDays(place: place, days: ["2026-11-11": ms])
        let rows = monthDays(year: 2026, month: 11, lat: 33.5731, lon: -7.5898, method: .morocco, asr: .standard, adjust: nil, habous: h)
        XCTAssertEqual(rows.filter(\.official).map { $0.date.day }, [11])
        XCTAssertEqual(rows[10].day.fajr, Date(timeIntervalSince1970: ms[0] / 1000))
        // Hanafi Asr in Morocco: no official table.
        XCTAssertFalse(monthDays(year: 2026, month: 11, lat: 33.5731, lon: -7.5898, method: .morocco, asr: .hanafi, adjust: nil, habous: h).contains { $0.official })
    }
}
