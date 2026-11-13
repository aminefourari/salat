import XCTest

/// Checks the Swift port against fixtures/parity.json, which the web test suite generates from the web code.
final class ParityTests: XCTestCase {
    struct Fixture: Decodable {
        struct PrayerCase: Decodable {
            let lat, lon: Double; let date, tz: String; let method: MethodId; let asr: AsrSchool
            let times: [String: Int] // unix minutes
        }
        struct CountryCase: Decodable { let lat, lon: Double; let cc: String? }
        struct EventCase: Decodable { let kind, prayer: String; let at: Int }
        struct ScheduleCase: Decodable { let lat, lon: Double; let date: String; let method: MethodId; let asr: AsrSchool; let adjust: [String: Int]; let events: [EventCase] }
        struct HijriCase: Decodable { let ms: Double; let month: Int }
        let prayer: [PrayerCase]; let country: [CountryCase]; let schedule: [ScheduleCase]; let hijri: [HijriCase]
    }

    static let fixture: Fixture = {
        let url = Bundle(for: ParityTests.self).url(forResource: "parity", withExtension: "json")!
        return try! JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }()

    func testPrayerParity() {
        var failures = 0
        for c in Self.fixture.prayer {
            let p = c.date.split(separator: "-").map { Int($0)! }
            guard let d = computeDay(lat: c.lat, lon: c.lon, date: DateComponents(year: p[0], month: p[1], day: p[2]),
                                     method: c.method, asr: c.asr) else { XCTFail("nil for \(c)"); continue }
            for (k, want) in c.times {
                let got = Int((k == "sunrise" ? d.sunrise : d[Prayer(rawValue: k)!]).timeIntervalSince1970 / 60)
                if got != want, failures < 20 {
                    failures += 1
                    XCTFail("\(c.method) \(c.asr) \(c.lat),\(c.lon) \(c.date) \(k): got \(got) want \(want)")
                }
            }
        }
        XCTAssertGreaterThan(Self.fixture.prayer.count, 800)
    }

    /// Reminder kinds, their offsets and the user's minute adjustments agree with the website's push schedule.
    func testScheduleParity() {
        let modes = Dictionary(uniqueKeysWithValues: Prayer.allCases.map { ($0, AlertMode.adhan) })
        for c in Self.fixture.schedule {
            let p = c.date.split(separator: "-").map { Int($0)! }
            guard let raw = computeDay(lat: c.lat, lon: c.lon, date: DateComponents(year: p[0], month: p[1], day: p[2]), method: c.method, asr: c.asr)
            else { XCTFail("nil for \(c.date)"); continue }
            let adjust = Dictionary(uniqueKeysWithValues: c.adjust.map { (Prayer(rawValue: $0.key)!, $0.value) })
            let got = upcomingEvents(days: [adjustDay(raw, adjust)], modes: modes, reminder: true, extras: [.adhkar, .friday], after: .distantPast)
                .map { "\(Int($0.at.timeIntervalSince1970 / 60)) \($0.kind.rawValue) \($0.prayer.rawValue)" }.sorted()
            let want = c.events.map { "\($0.at) \($0.kind) \($0.prayer)" }.sorted()
            XCTAssertEqual(got, want, "\(c.lat),\(c.lon) \(c.date) \(c.adjust)")
        }
        XCTAssertEqual(Self.fixture.schedule.count, 18)
    }

    /// Foundation's Umm al-Qura calendar agrees with the browser's (Intl) on the Hijri month (Ramadan line).
    func testHijriParity() {
        for c in Self.fixture.hijri {
            XCTAssertEqual(hijriMonth(Date(timeIntervalSince1970: c.ms / 1000), offset: 0), c.month, "\(c.ms)")
        }
        XCTAssertEqual(Self.fixture.hijri.count, 146)
    }

    func testCountryParity() {
        for c in Self.fixture.country {
            XCTAssertEqual(CountryLookup.shared.code(lat: c.lat, lon: c.lon), c.cc, "\(c.lat),\(c.lon)")
        }
    }

    func testAutoMethod() {
        XCTAssertEqual(methodForCountry(CountryLookup.shared.code(lat: 53.4319, lon: 11.1903)), .aachen)
        XCTAssertEqual(methodForCountry(CountryLookup.shared.code(lat: 33.5731, lon: -7.5898)), .morocco)
        XCTAssertEqual(methodForCountry(nil), .mwl)
    }

    func testNearestCity() {
        XCTAssertEqual(CityIndex.shared.nearest(lat: 53.4319, lon: 11.1903)?.name, "Hagenow")
        XCTAssertEqual(CityIndex.shared.nearest(lat: 33.5731, lon: -7.5898)?.cc, "MA")
        XCTAssertEqual(CityIndex.shared.nearest(lat: -18.07, lon: -179.9, maxKm: 200)?.name, "Levuka")
        XCTAssertNil(CityIndex.shared.nearest(lat: 0, lon: -140))
        XCTAssertTrue(CityIndex.shared.search("casab").prefix(5).contains { $0.name == "Casablanca" })
        XCTAssertTrue(CityIndex.shared.search("dusseldorf").contains { $0.name == "Düsseldorf" })
    }

    func testQibla() {
        XCTAssertEqual(qiblaBearing(lat: 53.4319, lon: 11.1903), 134.5, accuracy: 0.5)
        XCTAssertEqual((kaabaDistanceKm(lat: 53.4319, lon: 11.1903) / 10).rounded() * 10, 4310)
        XCTAssertEqual([0, 44, 135, 180, 300, 359].map(compass8), [0, 1, 3, 4, 7, 0])
        XCTAssertEqual(flag("DE"), "🇩🇪")
    }
}
