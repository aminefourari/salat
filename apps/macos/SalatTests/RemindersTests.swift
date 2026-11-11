import XCTest

/// Adjustments, Hijri offset and the adhkar/Friday reminders (website: lib/schedule.ts, lib/prayer.ts).
final class RemindersTests: XCTestCase {
    let berlin = TimeZone(identifier: "Europe/Berlin")!
    let all: [Prayer: AlertMode] = Dictionary(uniqueKeysWithValues: Prayer.allCases.map { ($0, .adhan) })
    func day(_ d: Int) -> DayTimes {
        computeDay(lat: 53.4319, lon: 11.1903, date: DateComponents(year: 2026, month: 11, day: d), method: .aachen, asr: .standard)!
    }

    func testAdjustDay() {
        let d = day(11)
        let a = adjustDay(d, [.fajr: -2, .maghrib: 3])
        XCTAssertEqual(a.fajr.timeIntervalSince(d.fajr), -120)
        XCTAssertEqual(a.maghrib.timeIntervalSince(d.maghrib), 180)
        XCTAssertEqual(a.sunrise, d.sunrise)
        XCTAssertEqual(a.isha, d.isha)
        XCTAssertEqual(adjustDay(d, nil), d)
    }

    func testHijri() {
        XCTAssertEqual(hijriOffset(method: .morocco, chosen: nil), -1)
        XCTAssertEqual(hijriOffset(method: .mwl, chosen: nil), 0)
        XCTAssertEqual(hijriOffset(method: .morocco, chosen: 1), 1)
        let firstRamadan = ISO8601DateFormatter().date(from: "2026-02-18T12:00:00Z")! // 1 Ramadan 1447, Umm al-Qura
        XCTAssertEqual(hijriMonth(firstRamadan, offset: 0), 9)
        XCTAssertEqual(hijriMonth(firstRamadan, offset: -1), 8)
        XCTAssertEqual(imsak(day(11)), day(11).fajr - 600)
    }

    func testAdhkarReminders() {
        let d = day(11) // Wednesday
        let ev = upcomingEvents(days: [d], modes: all.mapValues { _ in .off }, reminder: false, extras: [.adhkar, .friday],
                                after: d.fajr - 3600)
        XCTAssertEqual(ev.map(\.kind), [.adhkarMorning, .adhkarEvening])
        XCTAssertEqual(ev[0].at, d.fajr + 20 * 60)
        XCTAssertEqual(ev[1].at, d.asr + 20 * 60)
    }

    func testFriday() {
        // Dhuhr there is ~11:15 UTC: Friday in every time zone from UTC−11 to UTC+12, so the default (Mac) zone works too.
        let fri = day(13)
        XCTAssertTrue(isFriday(fri, tz: berlin))
        XCTAssertFalse(isFriday(day(12), tz: berlin))
        let ev = upcomingEvents(days: [fri], modes: all.mapValues { _ in .off }, reminder: false, extras: [.friday], after: fri.fajr)
        XCTAssertEqual(ev.map(\.kind), [.kahf, .jumuah])
        XCTAssertEqual(ev[0].at, fri.sunrise + 3600)
        XCTAssertEqual(ev[1].at, fri.dhuhr - 45 * 60)
    }

    func testLateAdhkarDroppedButNotWhenOnTime() {
        let d = day(11)
        var clock = AlertClock(saved: d.fajr, now: d.fajr)
        let off = all.mapValues { _ in AlertMode.off }
        XCTAssertEqual(clock.step(days: [d], modes: off, reminder: false, extras: [.adhkar], now: d.fajr + 20 * 60 + 5).map(\.event.kind), [.adhkarMorning])
        var asleep = AlertClock(saved: d.asr, now: d.asr)
        XCTAssertEqual(asleep.step(days: [d], modes: off, reminder: false, extras: [.adhkar], now: d.asr + 40 * 60).count, 0) // 20 min late
    }
}
