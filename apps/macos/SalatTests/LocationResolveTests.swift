import CoreLocation
import XCTest

final class LocationResolveTests: XCTestCase {
    let casa = City(name: "Casablanca", lat: 33.57, lon: -7.59, cc: "MA")
    let gps = CLLocation(latitude: 53.43, longitude: 11.19)
    lazy var last = ResolvedLocation(lat: 48.85, lon: 2.35, city: nil, source: .lastKnown)

    func testDeniedFallsBackToManual() {
        let r = resolveLocation(gps: nil, authorized: false, manual: casa, useManual: false, lastKnown: nil)
        XCTAssertEqual(r?.source, .manual)
        XCTAssertEqual(r?.lat, 33.57)
    }

    func testNothingReturnsNil() {
        XCTAssertNil(resolveLocation(gps: nil, authorized: false, manual: nil, useManual: false, lastKnown: nil))
        XCTAssertNil(resolveLocation(gps: nil, authorized: false, manual: nil, useManual: true, lastKnown: nil))
    }

    func testManualOverridesGps() {
        XCTAssertEqual(resolveLocation(gps: gps, authorized: true, manual: casa, useManual: true, lastKnown: last)?.source, .manual)
    }

    func testGpsBeatsLastKnown() {
        let r = resolveLocation(gps: gps, authorized: true, manual: casa, useManual: false, lastKnown: last)
        XCTAssertEqual(r?.source, .gps)
        XCTAssertEqual(r?.city?.name, "Hagenow")
        XCTAssertEqual(resolveLocation(gps: nil, authorized: true, manual: casa, useManual: false, lastKnown: last)?.source, .lastKnown)
    }

    func testStringsExistInAllLanguages() {
        for k in L10nKey.allCases { for l in Lang.allCases { XCTAssertFalse(t(k, l).isEmpty, "\(k) \(l)") } }
        XCTAssertEqual(t(.notifStart, .fr, ["prayer": "Asr", "time": "14:05"]), "C'est l'heure de Asr — 14:05")
    }
}
