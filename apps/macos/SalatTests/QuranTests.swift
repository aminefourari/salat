import XCTest

final class ReadAlongTests: XCTestCase {
    func testBoundaries() {
        let t = [AyahTiming(ayah: 1, from: 0, to: 6090), AyahTiming(ayah: 2, from: 6090, to: 11680), AyahTiming(ayah: 3, from: 11680, to: 15000)]
        XCTAssertEqual([0, 6089, 6090, 14999, 99999, -5].map { ayahIndex(at: $0, in: t) }, [0, 0, 1, 2, 2, 0])
        XCTAssertEqual(ayahIndex(at: 10, in: []), 0)
    }

    func testBundledText() {
        XCTAssertEqual(QuranText.surahs.count, 114)
        XCTAssertEqual(QuranText.surahs.reduce(0) { $0 + $1.ayahs.count }, 6236)
        XCTAssertEqual(QuranText.surahs[0].ar, "الفاتحة")
    }

    func testHizbs() {
        let r = [1, 240].map(RubInfo.init).map { [$0.juz, $0.hizb, $0.quarter] }
        XCTAssertEqual(r, [[1, 1, 0], [30, 60, 3]])
        let h = hizbStarts(QuranText.surahs)
        XCTAssertEqual(h.count, 60)
        XCTAssertEqual(h[2], HizbStart(hizb: 3, juz: 2, surah: 2, ayah: 142))
        XCTAssertEqual(h[59], HizbStart(hizb: 60, juz: 30, surah: 87, ayah: 1))
    }

    func testTafsirText() {
        XCTAssertEqual(tafsirText("<h2>Title</h2><p>A &amp; B<br>C &#1575;</p><p><span class=\"x\">D</span> <script>x</script></p>"),
                       ["Title", "A & B", "C ا", "D x"])
    }
}

final class RecitationStoreTests: XCTestCase {
    var root: URL!
    override func setUp() {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }
    override func tearDown() { try? FileManager.default.removeItem(at: root) }

    func put(_ name: String, _ reciter: Int = 7) throws {
        let dir = root.appendingPathComponent("\(reciter)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: dir.appendingPathComponent(name))
    }

    func testPartialDownloadNotCached() throws {
        let s = RecitationStore(root: root)
        try put("1.mp3.part")
        try JSONEncoder().encode([AyahTiming(ayah: 1, from: 0, to: 1)]).write(to: root.appendingPathComponent("7/1.json"))
        XCTAssertNil(s.local(reciter: 7, surah: 1))
        try put("1.mp3")
        XCTAssertEqual(s.local(reciter: 7, surah: 1)?.timings.count, 1)
    }

    func testSizeAndDelete() throws {
        let s = RecitationStore(root: root)
        try put("1.mp3"); try put("1.json")
        XCTAssertGreaterThan(s.size(reciter: 7), 0)
        s.delete(reciter: 7)
        XCTAssertEqual(s.size(reciter: 7), 0)
        XCTAssertNil(s.local(reciter: 7, surah: 1))
    }

    func testParsesApiTimestamps() throws {
        let url = Bundle(for: Self.self).url(forResource: "fatiha-7", withExtension: "json")!
        let r = try Recitation.decodeAPI(Data(contentsOf: url))
        XCTAssertEqual(r.timings.count, 7)
        XCTAssertEqual(r.timings[0].ayah, 1)
        XCTAssertEqual(r.timings[0].from, 0)
        XCTAssertEqual(r.timings[0].to, 6090)
        XCTAssertEqual(r.audioURL.host, "download.quranicaudio.com")
    }

    func testReciterList() {
        XCTAssertEqual(Reciter.all.map(\.id), [7, 3, 10, 6, 2, 9, 97, 4])
    }
}

/// Hits quran.com for real; run with TEST_RUNNER_SALAT_LIVE=1 npm run mac:test (xcodebuild strips the prefix).
final class LiveDownloadTests: XCTestCase {
    func testDownloadsFatiha() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SALAT_LIVE"] != nil)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let s = RecitationStore(root: root)
        try await s.download(reciter: 7, surah: 1)
        let l = try XCTUnwrap(s.local(reciter: 7, surah: 1))
        XCTAssertEqual(l.timings.count, 7)
        XCTAssertGreaterThan(s.size(reciter: 7), 500_000)
    }
}
