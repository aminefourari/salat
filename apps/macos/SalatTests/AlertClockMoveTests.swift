import XCTest

/// A prayer whose time moves after the fact (official Habous times arriving mid-day, a changed minute offset)
/// fires exactly once. Big jumps (another city) never replay: see AlertClockTests.testSettingsChangeDoesNotReplayPast.
final class AlertClockMoveTests: XCTestCase {
    let all: [Prayer: AlertMode] = Dictionary(uniqueKeysWithValues: Prayer.allCases.map { ($0, .adhan) })
    let d = computeDay(lat: 52.52, lon: 13.40, date: DateComponents(year: 2026, month: 11, day: 8), method: .mwl, asr: .standard)!
    let min: TimeInterval = 60

    func testLaterTimeDoesNotRefire() {
        var c = AlertClock(saved: nil, now: d.asr - 1)
        XCTAssertEqual(c.step(days: [d], modes: all, reminder: false, now: d.asr + 1).map(\.event.kind), [.start])
        let later = adjustDay(d, [.asr: 5])
        XCTAssertEqual(c.step(days: [later], modes: all, reminder: false, now: d.asr + 4 * min).count, 0)
        XCTAssertEqual(c.step(days: [later], modes: all, reminder: false, now: d.asr + 5 * min + 1).count, 0)
    }

    func testEarlierTimePastNowStillFires() {
        var c = AlertClock(saved: nil, now: d.asr - 10 * min - 1)
        XCTAssertEqual(c.step(days: [d], modes: all, reminder: false, now: d.asr - 10 * min).count, 0)
        let earlier = adjustDay(d, [.asr: -12])
        let due = c.step(days: [earlier], modes: all, reminder: false, now: d.asr - 10 * min + 1)
        XCTAssertEqual(due.map(\.event.kind), [.start])
        XCTAssertEqual(due.map(\.event.prayer), [.asr])
        XCTAssertEqual(due.first?.late, false)
        XCTAssertEqual(c.step(days: [earlier], modes: all, reminder: false, now: d.asr - 10 * min + 2).count, 0)
    }

    func testReminderMovedLaterDoesNotRefire() {
        var c = AlertClock(saved: nil, now: d.asr - 10 * min - 1)
        XCTAssertEqual(c.step(days: [d], modes: all, reminder: true, now: d.asr - 10 * min + 1).map(\.event.kind), [.reminder])
        let later = adjustDay(d, [.asr: 3])
        XCTAssertEqual(c.step(days: [later], modes: all, reminder: true, now: d.asr - 7 * min + 1).count, 0)
    }
}
