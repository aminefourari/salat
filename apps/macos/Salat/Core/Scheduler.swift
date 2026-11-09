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
