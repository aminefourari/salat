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
/// `fired` and `pending` key events by day, prayer and kind, so a time that moves by up to 30 min (official Habous
/// times arriving, a changed offset) neither fires twice nor gets skipped when it moved earlier past now.
struct AlertClock {
    private(set) var watermark: Date
    /// Event key → the time it fired at.
    private var fired: [String: Date] = [:]
    /// Event key → its time, for events seen still to come at the previous step.
    private var pending: [String: Date] = [:]
    private let moveTolerance: TimeInterval = 30 * 60

    /// `saved` is the last persisted watermark: don't replay more than the late window, never trust a future one.
    init(saved: Date?, now: Date) { watermark = min(max(saved ?? now, now - lateWindow), now) }

    private static func key(_ e: AlertEvent) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents(in: .autoupdatingCurrent, from: e.prayerTime)
        return "\(isoDate(c))/\(e.prayer.rawValue)/\(e.kind.rawValue)"
    }

    /// Due events since the last step. Starts always come through (late ones say so). Other reminders are dropped
    /// when late, and the ones announcing a prayer (10 min before, Jumuʿah) also once that prayer started.
    mutating func step(days: [DayTimes], modes: [Prayer: AlertMode], reminder: Bool, extras: Extras = [], now: Date) -> [(event: AlertEvent, late: Bool)] {
        let all = events(days: days, modes: modes, reminder: reminder, extras: extras)
        let floor = now - maxBackfill
        let tolerance = moveTolerance, pending = pending, fired = fired
        let near = { (a: Date?, b: Date) in a.map { abs($0.timeIntervalSince(b)) <= tolerance } ?? false }
        let due = all
            .filter { e in
                guard e.at <= now, e.at > floor else { return false }
                let k = Self.key(e)
                // New since the last step, or seen coming and then moved earlier past the watermark.
                guard e.at > self.watermark || near(pending[k], e.at) else { return false }
                return !near(fired[k], e.at) // already fired at (about) this time
            }
            .map { ($0, now.timeIntervalSince($0.at) > lateWindow) }
            .filter { e in
                switch e.0.kind {
                case .start: true
                case .reminder, .jumuah: !e.1 && e.0.prayerTime > now
                case .adhkarMorning, .adhkarEvening, .kahf: !e.1
                }
            }
            .map { (event: $0.0, late: $0.1) }
        var nowFired = fired
        for e in due { nowFired[Self.key(e.event)] = e.event.at }
        self.fired = nowFired.filter { $0.value > now - 2 * 86_400 }
        self.pending = Dictionary(all.filter { $0.at > now }.map { (Self.key($0), $0.at) }) { a, _ in a }
            .filter { nowFired[$0.key] == nil }
        watermark = max(watermark, now)
        return due
    }
}
