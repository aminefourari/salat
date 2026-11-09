import XCTest

final class SchedulerTests: XCTestCase {
    let lat = 53.4319, lon = 11.1903
    func day(_ y: Int, _ m: Int, _ d: Int) -> DayTimes {
        computeDay(lat: lat, lon: lon, date: DateComponents(year: y, month: m, day: d), method: .aachen, asr: .standard)!
    }
    let all: [Prayer: AlertMode] = Dictionary(uniqueKeysWithValues: Prayer.allCases.map { ($0, .adhan) })

    func testUpcomingOrder() {
        let today = day(2026, 11, 8)
        var modes = all; modes[.dhuhr] = .off
        let ev = upcomingEvents(days: [today], modes: modes, reminder: true, after: today.fajr.addingTimeInterval(-3600))
        XCTAssertEqual(ev.first?.kind, .reminder)
        XCTAssertEqual(ev.first?.prayer, .fajr)
        XCTAssertEqual(ev[1].kind, .start)
        XCTAssertEqual(ev[1].at, today.fajr)
        XCTAssertFalse(ev.contains { $0.prayer == .dhuhr })
        XCTAssertEqual(ev.count, 8)
        XCTAssertEqual(ev.map(\.at), ev.map(\.at).sorted())
    }

    func testLateWindow() {
        let today = day(2026, 11, 8)
        let onTime = dueEvents(days: [today], modes: all, reminder: false, lastHandled: today.asr.addingTimeInterval(-60), now: today.asr.addingTimeInterval(240))
        XCTAssertEqual(onTime.map(\.event.prayer), [.asr])
        XCTAssertEqual(onTime.first?.late, false)
        let late = dueEvents(days: [today], modes: all, reminder: false, lastHandled: today.asr.addingTimeInterval(-60), now: today.asr.addingTimeInterval(360))
        XCTAssertEqual(late.first?.late, true)
    }

    func testNoDoubleFire() {
        let today = day(2026, 11, 8)
        let now = today.asr.addingTimeInterval(1)
        XCTAssertEqual(dueEvents(days: [today], modes: all, reminder: false, lastHandled: today.asr.addingTimeInterval(-1), now: now).count, 1)
        XCTAssertEqual(dueEvents(days: [today], modes: all, reminder: false, lastHandled: now, now: now.addingTimeInterval(1)).count, 0)
    }

    func testDropsVeryOldEvents() {
        let today = day(2026, 11, 8)
        // Mac asleep all day: only the last 6 h are reported (as late), not every prayer since Fajr.
        let ev = dueEvents(days: [today], modes: all, reminder: false, lastHandled: today.fajr.addingTimeInterval(-60), now: today.isha.addingTimeInterval(60))
        XCTAssertFalse(ev.contains { $0.event.prayer == .fajr })
        XCTAssertTrue(ev.allSatisfy { $0.late || $0.event.prayer == .isha })
    }

    func testAfterIshaNextIsTomorrowFajr() {
        let today = day(2026, 11, 8), tomorrow = day(2026, 11, 9)
        let ev = upcomingEvents(days: [today, tomorrow], modes: all, reminder: false, after: today.isha.addingTimeInterval(60))
        XCTAssertEqual(ev.first?.prayer, .fajr)
        XCTAssertEqual(ev.first?.at, tomorrow.fajr)
    }

    func testTimeZoneChange() {
        // Same instant, different zone: the local date changes, so the days to look at change, but instants stay absolute.
        let now = ISO8601DateFormatter().date(from: "2026-11-08T22:30:00Z")!
        for tz in ["Europe/Berlin", "Asia/Riyadh"] {
            let zone = TimeZone(identifier: tz)!
            let d0 = dayComponents(now, in: zone)
            let d1 = dayComponents(now.addingTimeInterval(86_400), in: zone)
            let days = [d0, d1].map { computeDay(lat: 21.4225, lon: 39.8262, date: $0, method: .ummalqura, asr: .standard)! }
            let next = upcomingEvents(days: days, modes: all, reminder: false, after: now).first!
            let fajr9 = computeDay(lat: 21.4225, lon: 39.8262, date: DateComponents(year: 2026, month: 11, day: 9), method: .ummalqura, asr: .standard)!.fajr
            XCTAssertEqual(next.at, fajr9, tz)
        }
    }
}
