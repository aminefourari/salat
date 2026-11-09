import XCTest

final class AdhkarDataTests: XCTestCase {
    var all: [Dhikr] { AdhkarText.chapters.flatMap(\.items) }
    func dhikr(_ id: Int) -> Dhikr { all.first { $0.id == id }! }

    func testLoads() {
        XCTAssertEqual(AdhkarText.chapters.count, 132)
        XCTAssertEqual(all.count, 267)
        XCTAssertTrue(all.allSatisfy { !$0.ar.isEmpty })
        XCTAssertEqual(AdhkarText.chapters.map(\.id), AdhkarText.chapters.map(\.id).sorted())
    }

    func testSpotChecks() {
        XCTAssertTrue(dhikr(75).fr?.contains("Trône") == true) // Ayat al-Kursi, morning & evening
        XCTAssertNotNil(dhikr(75).ref)
        XCTAssertTrue(dhikr(1).fr?.hasPrefix("Louange à Allah qui nous a rendu la vie") == true)
        XCTAssertTrue(dhikr(1).ref?.contains("Muslim") == true)
        // After-salah Quls must not borrow the morning entry's reference.
        XCTAssertNil(dhikr(70).ref)
        XCTAssertEqual(AdhkarText.chapters.first { $0.id == 27 }?.title(.fr), "Évocations du matin et du soir")
    }

    func testBadgeHiddenWhenTextHasCount() {
        XCTAssertNil(dhikr(83).badge) // REPEAT 1 but the text says seven times
        XCTAssertNil(dhikr(96).badge) // REPEAT 100, text says (مِائَةَ مَرَّةٍ)
        XCTAssertTrue(all.allSatisfy { $0.badge == nil || !$0.countInText })
        let synthetic = Dhikr(id: 0, ar: "سبحان الله", en: nil, fr: nil, ref: nil, repeat: 33, countInText: false, audio: nil)
        XCTAssertEqual(synthetic.badge, 33)
    }

    func testTranslationByLang() {
        let d = dhikr(1)
        XCTAssertNil(d.translation(.ar))
        XCTAssertEqual(d.translation(.en), d.en)
        XCTAssertEqual(d.translation(.fr), d.fr)
    }

    func testNoLowConfidenceFrench() {
        let withFr = all.filter { $0.fr != nil }.count
        XCTAssertGreaterThan(withFr, all.count / 2)
        XCTAssertTrue(all.allSatisfy { $0.ref == nil || $0.fr != nil }) // a reference only comes with a matched entry
        for c in AdhkarText.chapters where c.items.contains(where: { $0.fr != nil }) { XCTAssertNotNil(c.fr, "\(c.id)") }
    }
}

final class AdhkarAudioStoreTests: XCTestCase {
    var root: URL!
    let d = Dhikr(id: 5, ar: "x", en: nil, fr: nil, ref: nil, repeat: 1, countInText: false, audio: URL(string: "https://stub.local/5.mp3"))
    override func setUp() {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        StubProtocol.delay = 0
        StubProtocol.mp3Requests = 0
    }
    override func tearDown() { try? FileManager.default.removeItem(at: root) }

    func testPartialNotCached() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: root.appendingPathComponent("5.mp3.part"))
        XCTAssertNil(AdhkarAudioStore(root: root).local(d))
    }

    func testDownloadAndDelete() async throws {
        let s = AdhkarAudioStore(root: root, session: StubProtocol.session()), d = self.d
        async let a: Void = s.download(d)
        async let b: Void = s.download(d)
        _ = try await (a, b)
        XCTAssertEqual(StubProtocol.mp3Requests, 1)
        XCTAssertNotNil(s.local(d))
        XCTAssertGreaterThan(s.size(), 0)
        s.delete()
        XCTAssertNil(s.local(d))
        XCTAssertEqual(s.size(), 0)
    }
}
