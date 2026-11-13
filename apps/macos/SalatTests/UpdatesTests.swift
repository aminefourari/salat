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

    private func runSwap(old: URL, new: URL, work: URL) throws {
        let done = Process(); done.executableURL = URL(fileURLWithPath: "/usr/bin/true"); try done.run(); done.waitUntilExit()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", updateSwapScript, "test", String(done.processIdentifier), old.path, new.path, work.path, "/usr/bin/true"]
        try p.run(); p.waitUntilExit()
    }

    func testSwapReplacesTheApp() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let old = dir.appendingPathComponent("Salat.app"), work = dir.appendingPathComponent("work"), new = work.appendingPathComponent("Salat.app")
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: new, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: old.appendingPathComponent("v")); try Data("new".utf8).write(to: new.appendingPathComponent("v"))
        try runSwap(old: old, new: new, work: work)
        XCTAssertEqual(try String(contentsOf: old.appendingPathComponent("v"), encoding: .utf8), "new")
        XCTAssertFalse(FileManager.default.fileExists(atPath: work.path))
    }

    func testSwapRestoresTheOldAppWhenTheNewOneCannotMove() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let old = dir.appendingPathComponent("Salat.app"), work = dir.appendingPathComponent("work")
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: old.appendingPathComponent("v"))
        try runSwap(old: old, new: work.appendingPathComponent("missing.app"), work: work)
        XCTAssertEqual(try String(contentsOf: old.appendingPathComponent("v"), encoding: .utf8), "old")
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.appendingPathComponent("old.app").path))
    }
}
