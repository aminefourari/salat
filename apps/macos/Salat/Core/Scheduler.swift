import Foundation

enum AlertMode: String, Codable, CaseIterable, Sendable { case adhan, notification, off }

struct AlertEvent: Equatable, Sendable {
    enum Kind: String, Sendable { case reminder, start }
    let prayer: Prayer
    let kind: Kind
    let at: Date
    let prayerTime: Date
}

let reminderLead: TimeInterval = 10 * 60
/// Same as the web cron's MAX_LATE: within this, a missed start still plays the adhan.
let lateWindow: TimeInterval = 5 * 60
private let maxBackfill: TimeInterval = 6 * 3600

private func events(days: [DayTimes], modes: [Prayer: AlertMode], reminder: Bool) -> [AlertEvent] {
    days.flatMap { d in
        Prayer.allCases.flatMap { p -> [AlertEvent] in
            guard (modes[p] ?? .adhan) != .off else { return [] }
            let start = AlertEvent(prayer: p, kind: .start, at: d[p], prayerTime: d[p])
            return reminder ? [AlertEvent(prayer: p, kind: .reminder, at: d[p] - reminderLead, prayerTime: d[p]), start] : [start]
        }
    }.sorted { $0.at < $1.at }
}

/// Events strictly after `after`, soonest first.
func upcomingEvents(days: [DayTimes], modes: [Prayer: AlertMode], reminder: Bool, after: Date) -> [AlertEvent] {
    events(days: days, modes: modes, reminder: reminder).filter { $0.at > after }
}

/// Events in (lastHandled, now], ignoring anything older than 6 h. `late` = more than 5 min past.
func dueEvents(days: [DayTimes], modes: [Prayer: AlertMode], reminder: Bool, lastHandled: Date, now: Date) -> [(event: AlertEvent, late: Bool)] {
    let from = max(lastHandled, now - maxBackfill)
    return events(days: days, modes: modes, reminder: reminder)
        .filter { $0.at > from && $0.at <= now }
        .map { ($0, now.timeIntervalSince($0.at) > lateWindow) }
}

/// What the alert loop has handled. The watermark moves to `now` on every step, so changing settings or location
/// never replays the past; only time without steps (Mac asleep) is caught up, within the 6 h cap.
struct AlertClock {
    private(set) var watermark: Date

    /// `saved` is the last persisted watermark: don't replay more than the late window, never trust a future one.
    init(saved: Date?, now: Date) { watermark = min(max(saved ?? now, now - lateWindow), now) }

    /// Due events since the last step. Reminders that are late, or whose prayer already started, are dropped.
    mutating func step(days: [DayTimes], modes: [Prayer: AlertMode], reminder: Bool, now: Date) -> [(event: AlertEvent, late: Bool)] {
        let due = dueEvents(days: days, modes: modes, reminder: reminder, lastHandled: watermark, now: now)
            .filter { $0.event.kind == .start || (!$0.late && $0.event.prayerTime > now) }
        watermark = max(watermark, now)
        return due
    }
}
