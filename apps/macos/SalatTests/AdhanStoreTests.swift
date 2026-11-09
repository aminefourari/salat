import XCTest

final class AdhanStoreTests: XCTestCase {
    var root: URL!
    override func setUp() {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        StubProtocol.delay = 0
        StubProtocol.mp3Requests = 0
    }
    override func tearDown() { try? FileManager.default.removeItem(at: root) }

    func testCatalog() {
        let ids = AdhanVoice.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(AdhanVoice.defaultId, "madinah")
        XCTAssertNotNil(AdhanVoice.find("madinah")?.remote)
        XCTAssertTrue(AdhanVoice.all.filter(\.fajrOnly).map(\.id).contains("makkah_fajr"))
        XCTAssertTrue(AdhanVoice.all.filter { $0.remote != nil }.allSatisfy { $0.remote!.host == "archive.org" })
    }

    func testBundledIsLocalRemoteIsNotUntilDownloaded() async throws {
        let s = AdhanStore(root: root, session: StubProtocol.session())
        XCTAssertNotNil(s.local("hassan2"))
        XCTAssertNil(s.local("madinah"))
        let stub = AdhanVoice(id: "stubbed", names: ("x", "x", "x"), remote: URL(string: "https://stub.local/stubbed.mp3"))
        try await s.download(stub)
        XCTAssertNotNil(s.local("stubbed"))
        XCTAssertEqual(StubProtocol.mp3Requests, 1)
    }

    func testImportAndDeleteCustom() throws {
        let s = AdhanStore(root: root)
        let src = FileManager.default.temporaryDirectory.appendingPathComponent("My Adhan.mp3")
        try Data("audio".utf8).write(to: src)
        let id = try s.importFile(src)
        XCTAssertTrue(id.hasPrefix("custom-"))
        XCTAssertNotNil(s.local(id))
        XCTAssertEqual(s.customName(id), "My Adhan")
        XCTAssertTrue(s.customIds().contains(id))
        s.deleteCustom(id)
        XCTAssertNil(s.local(id))
    }

    @MainActor func testMigrationIsSaved() {
        let defaults = UserDefaults(suiteName: "salat.test.\(UUID())")!
        defaults.set(try! JSONEncoder().encode(AppSettings.Data(adhanVoice: "azan", fajrVoice: "azan")), forKey: "settings.v1")
        _ = AppSettings(defaults: defaults)
        let saved = try! JSONDecoder().decode(AppSettings.Data.self, from: defaults.data(forKey: "settings.v1")!)
        XCTAssertEqual(saved.adhanVoice, "madinah")
        XCTAssertEqual(saved.adhanDefaultsV2, true)
    }

    func testMigratesOldDefaultToMadinah() {
        var d = AppSettings.Data()
        d.adhanVoice = "azan"; d.fajrVoice = "hassan2"; d.adhanDefaultsV2 = nil
        migrateAdhanDefaults(&d)
        XCTAssertEqual(d.adhanVoice, "madinah")
        XCTAssertEqual(d.fajrVoice, "madinah")
        d.adhanVoice = "fakhry"
        migrateAdhanDefaults(&d) // runs once only
        XCTAssertEqual(d.adhanVoice, "fakhry")
    }
}
