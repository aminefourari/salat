import AppKit
import CoreLocation
import Observation
import UserNotifications

/// Computes today's times every second and fires the adhan / notifications. Recomputing each tick
/// (three computeDay calls) is what makes sleep, time-zone changes, midnight and settings changes "just work".
@MainActor @Observable
final class AlertEngine: NSObject, UNUserNotificationCenterDelegate {
    let settings: AppSettings
    let location: LocationService
    let player = AdhanPlayer()

    private(set) var now = Date()
    private(set) var loc: ResolvedLocation?
    private(set) var method: MethodId = .mwl
    private(set) var today: DayTimes?
    private(set) var tomorrow: DayTimes?

    var next: (prayer: Prayer, at: Date)? {
        guard let today, let tomorrow else { return nil }
        return nextPrayer(today: today, tomorrow: tomorrow, now: now)
    }

    private struct LocKey: Equatable { var lat, lon: Double?; var authorized, useManual: Bool; var manual: City? }
    private var locKey: LocKey?
    private var country: String?
    private var timer: Timer?
    private var clock: AlertClock

    init(settings: AppSettings, location: LocationService) {
        self.settings = settings
        self.location = location
        clock = AlertClock(saved: settings.d.lastAlertHandled, now: Date())
        super.init()
        location.onChange = { [weak self] in self?.tick() }
        location.requestOnce()
        setUpNotifications()
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.location.requestOnce(); self?.tick() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
        timer?.tolerance = 0.2
        tick()
    }

    func tick() {
        now = Date()
        let s = settings.d
        let gps = location.location?.coordinate
        let key = LocKey(lat: gps?.latitude, lon: gps?.longitude, authorized: location.authorized, useManual: s.useManualLocation, manual: s.manualCity)
        if key != locKey {
            locKey = key
            loc = resolveLocation(gps: location.location, authorized: location.authorized, manual: s.manualCity,
                                  useManual: s.useManualLocation, lastKnown: s.lastKnown)
            country = loc.flatMap { CountryLookup.shared.code(lat: $0.lat, lon: $0.lon) }
            if let l = loc, l.source == .gps, l != s.lastKnown { settings.d.lastKnown = l }
        }
        guard let loc else {
            today = nil; tomorrow = nil
            _ = clock.step(days: [], modes: [:], reminder: false, now: now)
            return
        }
        method = s.method ?? methodForCountry(country)
        let cal = Calendar.autoupdatingCurrent
        let days = (-1...1).map { off in
            computeDay(lat: loc.lat, lon: loc.lon, date: dayComponents(cal.date(byAdding: .day, value: off, to: now)!),
                       method: method, asr: s.asr)
        }
        today = days[1]; tomorrow = days[2]
        let due = clock.step(days: days.compactMap { $0 }, modes: s.modes, reminder: s.reminder, now: now)
        guard !due.isEmpty else { return }
        settings.d.lastAlertHandled = now // persisted so a relaunch doesn't replay these
        for (e, late) in due { fire(e, late: late) }
    }

    private func fire(_ e: AlertEvent, late: Bool) {
        let lang = settings.d.lang, name = prayerName(e.prayer, lang), time = hm(e.prayerTime)
        switch (e.kind, settings.d.modes[e.prayer] ?? .adhan, late) {
        case (.reminder, _, _):
            notify(t(.notifReminder, lang, ["prayer": name, "time": time]), sound: false)
        case (.start, .adhan, false):
            player.play(e.prayer == .fajr ? settings.d.fajrVoice : settings.d.adhanVoice)
            notify(t(.notifStart, lang, ["prayer": name, "time": time]), sound: false, stoppable: true)
        case (.start, _, true):
            notify(t(.startedAt, lang, ["prayer": name, "time": time]), sound: false)
        case (.start, _, false):
            notify(t(.notifStart, lang, ["prayer": name, "time": time]), sound: true)
        }
    }

    // MARK: notifications

    private func setUpNotifications() {
        let c = UNUserNotificationCenter.current()
        c.delegate = self
        let stop = UNNotificationAction(identifier: "STOP", title: t(.stop, settings.d.lang))
        c.setNotificationCategories([UNNotificationCategory(identifier: "ADHAN", actions: [stop], intentIdentifiers: [])])
        c.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notify(_ body: String, sound: Bool, stoppable: Bool = false) {
        let c = UNMutableNotificationContent()
        c.title = "Salat"
        c.body = body
        if sound { c.sound = .default }
        if stoppable { c.categoryIdentifier = "ADHAN" }
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }

    nonisolated func userNotificationCenter(_ c: UNUserNotificationCenter, willPresent n: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(_ c: UNUserNotificationCenter, didReceive r: UNNotificationResponse) async {
        if r.actionIdentifier == "STOP" { await MainActor.run { player.stop() } }
    }
}
