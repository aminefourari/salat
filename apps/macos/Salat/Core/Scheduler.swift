import Foundation

enum AlertMode: String, Codable, CaseIterable, Sendable { case adhan, notification, off }

struct AlertEvent: Equatable, Sendable {
    /// Same kinds as the website's push (`lib/schedule.ts`). `prayer` is the prayer the event hangs off.
    enum Kind: String, Sendable { case reminder, start, adhkarMorning, adhkarEvening, kahf, jumuah }
    let prayer: Prayer
    let kind: Kind
    let at: Date
    let prayerTime: Date
}

/// Optional reminders besides the prayers themselves.
struct Extras: OptionSet, Sendable {
    let rawValue: Int
    /// Morning adhkar after Fajr, evening adhkar after Asr.
    static let adhkar = Extras(rawValue: 1)
    /// Friday: Surat al-Kahf after sunrise, Jumuʿah before Dhuhr.
    static let friday = Extras(rawValue: 2)
}

let reminderLead: TimeInterval = 10 * 60
let adhkarAfter: TimeInterval = 20 * 60
let kahfAfterSunrise: TimeInterval = 60 * 60
let jumuahLead: TimeInterval = 45 * 60
/// Same as the web cron's MAX_LATE: within this, a missed start still plays the adhan.
let lateWindow: TimeInterval = 5 * 60
private let maxBackfill: TimeInterval = 6 * 3600

func isFriday(_ d: DayTimes, tz: TimeZone = .autoupdatingCurrent) -> Bool {
    var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
    return cal.component(.weekday, from: d.dhuhr) == 6
}

private func events(days: [DayTimes], modes: [Prayer: AlertMode], reminder: Bool, extras: Extras) -> [AlertEvent] {
    days.flatMap { d in
        var out = Prayer.allCases.flatMap { p -> [AlertEvent] in
            guard (modes[p] ?? .adhan) != .off else { return [] }
            let start = AlertEvent(prayer: p, kind: .start, at: d[p], prayerTime: d[p])
            return reminder ? [AlertEvent(prayer: p, kind: .reminder, at: d[p] - reminderLead, prayerTime: d[p]), start] : [start]
        }
        if extras.contains(.adhkar) {
            out.append(AlertEvent(prayer: .fajr, kind: .adhkarMorning, at: d.fajr + adhkarAfter, prayerTime: d.fajr))
            out.append(AlertEvent(prayer: .asr, kind: .adhkarEvening, at: d.asr + adhkarAfter, prayerTime: d.asr))
        }
        if extras.contains(.friday), isFriday(d) {
            out.append(AlertEvent(prayer: .dhuhr, kind: .kahf, at: d.sunrise + kahfAfterSunrise, prayerTime: d.dhuhr))
            out.append(AlertEvent(prayer: .dhuhr, kind: .jumuah, at: d.dhuhr - jumuahLead, prayerTime: d.dhuhr))
        }
        return out
    }.sorted { $0.at < $1.at }
}

/// Events strictly after `after`, soonest first.
func upcomingEvents(days: [DayTimes], modes: [Prayer: AlertMode], reminder: Bool, extras: Extras = [], after: Date) -> [AlertEvent] {
    events(days: days, modes: modes, reminder: reminder, extras: extras).filter { $0.at > after }
}

/// Events in (lastHandled, now], ignoring anything older than 6 h. `late` = more than 5 min past.
func dueEvents(days: [DayTimes], modes: [Prayer: AlertMode], reminder: Bool, extras: Extras = [], lastHandled: Date, now: Date) -> [(event: AlertEvent, late: Bool)] {
    let from = max(lastHandled, now - maxBackfill)
    return events(days: days, modes: modes, reminder: reminder, extras: extras)
        .filter { $0.at > from && $0.at <= now }
        .map { ($0, now.timeIntervalSince($0.at) > lateWindow) }
}

/// What the alert loop has handled. The watermark moves to `now` on every step, so changing settings or location
/// never replays the past; only time without steps (Mac asleep) is caught up, within the 6 h cap.
struct AlertClock {
    private(set) var watermark: Date

    /// `saved` is the last persisted watermark: don't replay more than the late window, never trust a future one.
    init(saved: Date?, now: Date) { watermark = min(max(saved ?? now, now - lateWindow), now) }

    /// Due events since the last step. Starts always come through (late ones say so). Other reminders are dropped
    /// when late, and the ones announcing a prayer (10 min before, Jumuʿah) also once that prayer started.
    mutating func step(days: [DayTimes], modes: [Prayer: AlertMode], reminder: Bool, extras: Extras = [], now: Date) -> [(event: AlertEvent, late: Bool)] {
        let due = dueEvents(days: days, modes: modes, reminder: reminder, extras: extras, lastHandled: watermark, now: now)
            .filter { e in
                switch e.event.kind {
                case .start: true
                case .reminder, .jumuah: !e.late && e.event.prayerTime > now
                case .adhkarMorning, .adhkarEvening, .kahf: !e.late
                }
            }
        watermark = max(watermark, now)
        return due
    }
}
