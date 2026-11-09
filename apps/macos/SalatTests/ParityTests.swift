import XCTest
@testable import Salat

/// Checks the Swift port against fixtures/parity.json, which the web test suite generates from the web code.
final class ParityTests: XCTestCase {
    struct Fixture: Decodable {
        struct PrayerCase: Decodable {
            let lat, lon: Double; let date, tz: String; let method: MethodId; let asr: AsrSchool
            let times: [String: Int] // unix minutes
        }
        struct CountryCase: Decodable { let lat, lon: Double; let cc: String? }
        let prayer: [PrayerCase]; let country: [CountryCase]
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
