import CoreLocation
import XCTest

// Regression tests for the final-review findings.

final class AlertClockTests: XCTestCase {
    let all: [Prayer: AlertMode] = Dictionary(uniqueKeysWithValues: Prayer.allCases.map { ($0, .adhan) })
    func day(_ lat: Double, _ lon: Double) -> DayTimes {
        computeDay(lat: lat, lon: lon, date: DateComponents(year: 2026, month: 11, day: 8), method: .mwl, asr: .standard)!
    }

    func testSettingsChangeDoesNotReplayPast() {
        let berlin = day(52.52, 13.40), dubai = day(25.2, 55.27) // Dubai prayers are hours earlier in absolute time
        let now = berlin.asr.addingTimeInterval(-60)
        var c = AlertClock(saved: berlin.dhuhr, now: berlin.dhuhr.addingTimeInterval(1))
        _ = c.step(days: [berlin], modes: all, reminder: false, now: now.addingTimeInterval(-1)) // ticks kept running
        XCTAssertEqual(c.step(days: [dubai], modes: all, reminder: false, now: now).count, 0)
    }

    func testLateOrStartedRemindersAreSkipped() {
        let d = day(52.52, 13.40)
        var slept = AlertClock(saved: d.asr.addingTimeInterval(-3600), now: d.asr.addingTimeInterval(-3600))
        let woke = slept.step(days: [d], modes: all, reminder: true, now: d.asr.addingTimeInterval(120))
        XCTAssertEqual(woke.map(\.event.kind), [.start])
        var onTime = AlertClock(saved: d.asr.addingTimeInterval(-700), now: d.asr.addingTimeInterval(-700))
        XCTAssertEqual(onTime.step(days: [d], modes: all, reminder: true, now: d.asr.addingTimeInterval(-590)).map(\.event.kind), [.reminder])
    }

    func testWatermarkNeverInFuture() {
        let now = Date()
        XCTAssertEqual(AlertClock(saved: now.addingTimeInterval(86_400), now: now).watermark, now)
        XCTAssertEqual(AlertClock(saved: now.addingTimeInterval(-86_400), now: now).watermark, now - lateWindow)
        XCTAssertEqual(AlertClock(saved: nil, now: now).watermark, now)
    }
}

/// Serves the quran.com API and MP3s locally; counts MP3 requests.
final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var mp3Requests = 0
    nonisolated(unsafe) static var delay: TimeInterval = 0.3
    private var cancelled = false
    override class func canInit(with r: URLRequest) -> Bool { true }
    override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }
    override func startLoading() {
        let url = request.url!
        let isMP3 = url.pathExtension == "mp3"
        if isMP3 { Self.mp3Requests += 1 }
        let surah = isMP3 ? url.deletingPathExtension().lastPathComponent : url.lastPathComponent
        let body: Data = isMP3 ? Data(repeating: 1, count: 10_000) : Data("""
            {"audio_file":{"audio_url":"https://stub.local/\(surah).mp3","timestamps":[{"verse_key":"\(surah):1","timestamp_from":0,"timestamp_to":1000}]}}
            """.utf8)
        DispatchQueue.global().asyncAfter(deadline: .now() + (isMP3 ? Self.delay : 0)) { [self] in
            guard !cancelled else { return }
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() { cancelled = true }

    static func session() -> URLSession {
        let c = URLSessionConfiguration.ephemeral
        c.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: c)
    }
}

final class DownloadFixTests: XCTestCase {
    var root: URL!
    override func setUp() {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        StubProtocol.mp3Requests = 0
        StubProtocol.delay = 0.3
    }
    override func tearDown() { try? FileManager.default.removeItem(at: root) }

    func testConcurrentDownloadsOfSameSurahShareOne() async throws {
        let s = RecitationStore(root: root, session: StubProtocol.session())
        async let a: Void = s.download(reciter: 7, surah: 1)
        async let b: Void = s.download(reciter: 7, surah: 1)
        _ = try await (a, b)
        XCTAssertEqual(StubProtocol.mp3Requests, 1)
        XCTAssertNotNil(s.local(reciter: 7, surah: 1))
    }

    func testCancelStopsQuickly() async throws {
        StubProtocol.delay = 5
        let s = RecitationStore(root: root, session: StubProtocol.session())
        let t = Task { try await s.download(reciter: 7, surah: 2) }
        try await Task.sleep(for: .milliseconds(200))
        let start = Date()
        t.cancel()
        _ = await t.result
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
        XCTAssertNil(s.local(reciter: 7, surah: 2))
    }

    func testBulkProgressCountsDownloadedSurahs() async throws {
        StubProtocol.delay = 0
        let s = RecitationStore(root: root, session: StubProtocol.session())
        for n in 1...3 { try await s.download(reciter: 7, surah: n) }
        let seen = Seen()
        try await s.downloadAll(reciter: 7) { done, _ in seen.add(done) }
        let v = seen.values
        XCTAssertGreaterThanOrEqual(v.first ?? 0, 4)
        XCTAssertEqual(v, v.sorted())
        XCTAssertEqual(v.last, 114)
    }

    final class Seen: @unchecked Sendable {
        private let lock = NSLock(); private var v: [Int] = []
        func add(_ x: Int) { lock.withLock { v.append(x) } }
        var values: [Int] { lock.withLock { v } }
    }
}

@MainActor
final class QuranPlayerFixTests: XCTestCase {
    func testCancelledBulkDownloadIsNotAnError() async throws {
        StubProtocol.delay = 5
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let p = QuranPlayer(store: RecitationStore(root: root, session: StubProtocol.session()))
        p.downloadAll(reciter: 7)
        try await Task.sleep(for: .milliseconds(200))
        p.cancelDownload(reciter: 7)
        for _ in 0..<40 where p.bulk[7] != nil { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertNil(p.bulk[7])
        XCTAssertNil(p.bulkError[7])
    }

    func testDeleteDuringPlayDownloadLeavesNoError() async throws {
        StubProtocol.delay = 0.5
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let p = QuranPlayer(store: RecitationStore(root: root, session: StubProtocol.session()))
        let play = Task { await p.play(surah: 1, reciter: 7) }
        try await Task.sleep(for: .milliseconds(150))
        p.delete(reciter: 7)
        await play.value
        XCTAssertEqual(p.state, .idle)
    }
}

@MainActor
final class LocationFailureTests: XCTestCase {
    func testFailureIsReported() async throws {
        let l = LocationService()
        XCTAssertFalse(l.failed)
        l.locationManager(CLLocationManager(), didFailWithError: CLError(.locationUnknown))
        for _ in 0..<20 where !l.failed { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertTrue(l.failed)
    }
}
