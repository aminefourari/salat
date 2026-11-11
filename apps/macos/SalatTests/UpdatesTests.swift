import XCTest

final class UpdatesTests: XCTestCase {
    func testIsNewer() {
        XCTAssertTrue(isNewer("1.1.0", than: "1.0.0"))
        XCTAssertTrue(isNewer("1.10.0", than: "1.9.2"))
        XCTAssertTrue(isNewer("2.0.0", than: "1.99.99"))
        XCTAssertFalse(isNewer("1.0.0", than: "1.0.0"))
        XCTAssertFalse(isNewer("1.0.0", than: "1.0.1"))
        XCTAssertFalse(isNewer("1.1", than: "1.0.0"))
        XCTAssertFalse(isNewer("v1.2.0", than: "1.0.0"))
    }

    func testDecodesWorkerResponse() throws {
        let json = #"{"version":"1.2.0","sha256":"\#(String(repeating: "a", count: 64))","size":11065932,"notes":"n"}"#
        let info = try JSONDecoder().decode(UpdateInfo.self, from: Data(json.utf8))
        XCTAssertEqual(info.version, "1.2.0")
        XCTAssertEqual(info.downloadURL.absoluteString, "https://salat.aminethewiz18.workers.dev/api/update?v=1.2.0")
    }
}
