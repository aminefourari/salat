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
    /// Today's times come from the official Habous timetable (Morocco), not the calculation.
    private(set) var official = false

    var sky: Sky { today.map { skyAt($0, now) } ?? .night }

    var next: (prayer: Prayer, at: Date)? {
        guard let today, let tomorrow else { return nil }
        return nextPrayer(today: today, tomorrow: tomorrow, now: now)
    }

    private struct LocKey: Equatable { var lat, lon: Double?; var authorized, useManual: Bool; var manual: City? }
    private var locKey: LocKey?
    private var country: String?
    private var timer: Timer?
    private var clock: AlertClock
    /// Last Habous request: its place+date, when, and whether to stop asking for it (no city near).
    private var habousAsked: (key: String, at: Date, final: Bool)?

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
        let dates = (-1...1).map { dayComponents(cal.date(byAdding: .day, value: $0, to: now)!) }
        let habous = usesHabous(method: method, asr: s.asr)
        let place = habousPlace(lat: loc.lat, lon: loc.lon)
        if habous { refreshHabous(place: place, dates: dates) }
        let days = dates.map { date in
            (habous ? habousDay(s.habous, place: place, date: date) : nil)
                ?? computeDay(lat: loc.lat, lon: loc.lon, date: date, method: method, asr: s.asr)
        }
        today = days[1]; tomorrow = days[2]
        official = habous && habousDay(s.habous, place: place, date: dates[1]) != nil
        let due = clock.step(days: days.compactMap { $0 }, modes: s.modes, reminder: s.reminder, now: now)
        guard !due.isEmpty else { return }
        settings.d.lastAlertHandled = now // persisted so a relaunch doesn't replay these
        for (e, late) in due { fire(e, late: late) }
    }

    /// Asks the Worker for a whole month when today or tomorrow isn't cached yet, so it asks about once a month.
    /// Retries every 10 min on failure (Habous down, next month not published); a 404 (no Habous city
    /// within 25 km) stops it for that place and month.
    private func refreshHabous(place: String, dates: [DateComponents]) {
        guard let month = habousMonthToFetch(settings.d.habous, place: place, today: dates[1], tomorrow: dates[2]) else { return }
        let key = "\(place) \(month)"
        if let a = habousAsked, a.key == key, a.final || now.timeIntervalSince(a.at) < 600 { return }
        habousAsked = (key, now, false)
        let yesterday = isoDate(dates[0])
        Task { [weak self] in
            guard let (data, res) = try? await URLSession.shared.data(from: habousURL(place: place, month: month)),
                  let status = (res as? HTTPURLResponse)?.statusCode else { return }
            guard let self else { return }
            if status == 404 { habousAsked = (key, habousAsked?.at ?? now, true); return }
            guard status == 200, let body = try? JSONDecoder().decode([String: [String: [Double]]].self, from: data),
                  let days = body["days"] else { return }
            settings.d.habous = mergeHabous(settings.d.habous, place: place, fetched: days, keepFrom: yesterday)
            tick()
        }
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
