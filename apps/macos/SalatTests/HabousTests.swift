import XCTest

final class HabousTests: XCTestCase {
    // The Worker's /api/habous answer for Casablanca, 2026-11-11 (checked against the Habous file).
    let body = #"{"days":{"2026-11-11":[1794374880000,1794380100000,1794399600000,1794409800000,1794418500000,1794423060000],"2026-11-12":[1794461280000,1794466560000,1794486000000,1794496140000,1794504840000,1794509460000]}}"#
    let place = habousPlace(lat: 33.57312, lon: -7.58981)

    func testDecodesAndLooksUpOfficialDays() throws {
        let days = try XCTUnwrap(JSONDecoder().decode([String: [String: [Double]]].self, from: Data(body.utf8))["days"])
        let h = mergeHabous(nil, place: place, fetched: days, keepFrom: "2026-11-10")
        let d = try XCTUnwrap(habousDay(h, place: place, date: DateComponents(year: 2026, month: 11, day: 11)))
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Africa/Casablanca")!
        XCTAssertEqual(cal.dateComponents([.hour, .minute], from: d.fajr), DateComponents(hour: 6, minute: 28))
        XCTAssertEqual(cal.dateComponents([.hour, .minute], from: d.isha), DateComponents(hour: 19, minute: 51))
        XCTAssertNil(habousDay(h, place: place, date: DateComponents(year: 2026, month: 11, day: 13)))
        XCTAssertNil(habousDay(h, place: "34.020,-6.840", date: DateComponents(year: 2026, month: 11, day: 11)))
        // Close to the 19°/17° fallback, so the GMT → instant conversion is right.
        let calc = try XCTUnwrap(computeDay(lat: 33.5731, lon: -7.5898, date: DateComponents(year: 2026, month: 11, day: 11), method: .morocco, asr: .standard))
        for p in Prayer.allCases { XCTAssertLessThan(abs(d[p].timeIntervalSince(calc[p])), 600, "\(p)") }
    }

    func testMergeKeepsRecentDaysForTheSamePlaceOnly() {
        let old = HabousDays(place: place, days: ["2026-11-09": [1], "2026-11-10": [2], "2026-11-11": [3]])
        XCTAssertEqual(mergeHabous(old, place: place, fetched: ["2026-11-12": [4]], keepFrom: "2026-11-10").days.keys.sorted(),
                       ["2026-11-10", "2026-11-11", "2026-11-12"])
        XCTAssertEqual(mergeHabous(old, place: "1.000,2.000", fetched: ["2026-11-12": [4]], keepFrom: "2026-11-10").days.keys.sorted(),
                       ["2026-11-12"])
        XCTAssertTrue(usesHabous(method: .morocco, asr: .standard))
        XCTAssertFalse(usesHabous(method: .morocco, asr: .hanafi))
        XCTAssertEqual(habousURL(place: place, date: "2026-11-11").absoluteString,
                       "https://salat.aminethewiz18.workers.dev/api/habous?lat=33.573&lon=-7.590&date=2026-11-11")
    }
}
