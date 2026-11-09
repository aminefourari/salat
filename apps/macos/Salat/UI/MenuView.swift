import SwiftUI

struct MenuLabel: View {
    let engine: AlertEngine
    var body: some View {
        if engine.settings.d.iconOnly || engine.next == nil {
            Image(systemName: "moon.stars")
        } else if let n = engine.next {
            Text("\(prayerName(n.prayer, engine.settings.d.lang)) · \(countdown(n.at.timeIntervalSince(engine.now)))")
        }
    }
}

struct MenuView: View {
    let engine: AlertEngine
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var lang: Lang { engine.settings.d.lang }

    var body: some View {
        VStack(spacing: 12) {
            dates
            if let today = engine.today, let next = engine.next {
                hero(today, next)
                VStack(spacing: 5) {
                    ForEach(rows(today), id: \.0) { key, name, time in row(key, name, time, next) }
                }
                VStack(spacing: 2) {
                    if let city = engine.loc?.city { Text("\(flag(city.cc)) \(city.name)") }
                    Text(methodName(engine.method, lang))
                    if engine.method == .morocco { Text(t(.approximate, lang)).fixedSize(horizontal: false, vertical: true) }
                }
                .font(Theme.plex(11)).foregroundStyle(Theme.soft).multilineTextAlignment(.center)
            } else {
                let waiting = (engine.location.authorized || engine.location.status == .notDetermined) && !engine.location.failed
                Text(waiting ? t(.locating, lang) : t(.noLocation, lang))
                    .foregroundStyle(Theme.soft).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true).padding(.vertical, 30)
            }
            if engine.player.isPlaying {
                Button(t(.stop, lang), systemImage: "stop.fill") { engine.player.stop() }.buttonStyle(GoldButtonStyle())
            }
            HStack(spacing: 8) {
                Button(t(.quran, lang), systemImage: "book") { show { openWindow(id: "quran") } }.buttonStyle(GoldButtonStyle()).fixedSize()
                Button(t(.adhkar, lang), systemImage: "hands.and.sparkles") { show { openWindow(id: "adhkar") } }.buttonStyle(GoldButtonStyle()).fixedSize()
                Spacer()
                Button(t(.settings, lang), systemImage: "slider.horizontal.3") { show { openSettings() } }
                    .labelStyle(.iconOnly).buttonStyle(GoldOutlineButtonStyle()).help(t(.settings, lang))
                Button(t(.quit, lang), systemImage: "power") { NSApp.terminate(nil) }
                    .labelStyle(.iconOnly).buttonStyle(GoldOutlineButtonStyle()).help(t(.quit, lang))
            }
        }
        .padding(16)
        .frame(width: 320)
        .font(Theme.plex(14))
        .foregroundStyle(Theme.ink)
        .background(ThemedBackground(sky: engine.sky))
        .environment(\.layoutDirection, lang.isRTL ? .rightToLeft : .leftToRight)
    }

    private var dates: some View {
        let greg = engine.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(lang.locale))
        var hijriFmt = Date.FormatStyle(date: .long, time: .omitted, locale: lang.locale, calendar: Calendar(identifier: .islamicUmmAlQura))
        hijriFmt.timeZone = .autoupdatingCurrent
        return VStack(spacing: 1) {
            Text(greg).foregroundStyle(Theme.soft)
            Text(engine.now.formatted(hijriFmt)).foregroundStyle(Theme.gold)
        }
        .font(Theme.plex(12))
    }

    /// Next prayer inside the mihrab arch: the one loud element (website `.hero`).
    private func hero(_ today: DayTimes, _ next: (prayer: Prayer, at: Date)) -> some View {
        ZStack(alignment: .bottom) {
            ArchShape().fill(Theme.panel)
            ArchShape().stroke(Theme.gold, lineWidth: 1.6)
            ArchShape(inner: true).stroke(Theme.gold.opacity(0.35), lineWidth: 1)
            VStack(spacing: 2) {
                Text(t(.next, lang)).font(Theme.plex(12)).foregroundStyle(Theme.soft)
                Text(prayerName(next.prayer, lang)).font(Theme.kufi(40))
                if lang != .ar { Text(prayerName(next.prayer, .ar)).font(Theme.kufi(18, .medium)).foregroundStyle(Theme.gold) }
                Text(hm(next.at)).font(Theme.plex(22, semibold: true)).monospacedDigit().padding(.top, 4)
                Text(t(.inTime, lang, ["time": clock(next.at.timeIntervalSince(engine.now))]))
                    .font(Theme.plex(12)).foregroundStyle(Theme.soft).monospacedDigit()
                ProgressBar(value: waitProgress(today: today, nextAt: next.at, now: engine.now))
                    .frame(width: 140, height: 4).padding(.top, 8)
            }
            .padding(.bottom, 18)
        }
        .frame(width: 220, height: 245)
    }

    private func row(_ key: String, _ name: String, _ time: Date, _ next: (prayer: Prayer, at: Date)) -> some View {
        let isNext = key == next.prayer.rawValue && time == next.at
        let minor = key == "sunrise"
        let past = !isNext && time < engine.now
        return HStack(spacing: 10) {
            Image(systemName: prayerSymbol(key)).foregroundStyle(minor ? Theme.soft : Theme.gold).frame(width: 18)
            Text(name).font(Theme.plex(14, semibold: !minor))
            if lang != .ar { Text(keyName(key, .ar)).font(Theme.kufi(13, .medium)).foregroundStyle(Theme.soft) }
            Spacer()
            Text(hm(time)).font(Theme.plex(15, semibold: isNext)).monospacedDigit().foregroundStyle(isNext ? Theme.gold : Theme.ink)
        }
        .padding(.horizontal, 12).padding(.vertical, minor ? 4 : 8)
        .background {
            if isNext {
                RoundedRectangle(cornerRadius: 14).fill(LinearGradient(colors: [Theme.gold.opacity(0.18), Theme.panel],
                                                                       startPoint: .leading, endPoint: .trailing))
            } else if !minor {
                RoundedRectangle(cornerRadius: 14).fill(Theme.panel)
            }
        }
        .overlay { if isNext { RoundedRectangle(cornerRadius: 14).stroke(Theme.gold.opacity(0.7), lineWidth: 1) } }
        .foregroundStyle(minor ? Theme.soft : Theme.ink)
        .opacity(past ? 0.55 : 1)
    }

    private func rows(_ d: DayTimes) -> [(String, String, Date)] {
        [(Prayer.fajr.rawValue, prayerName(.fajr, lang), d.fajr), ("sunrise", t(.sunrise, lang), d.sunrise)]
            + Prayer.allCases.dropFirst().map { ($0.rawValue, prayerName($0, lang), d[$0]) }
    }

    private func keyName(_ key: String, _ l: Lang) -> String { t(L10nKey(rawValue: key)!, l) }

    /// "H:MM:SS" like the website's countdown.
    private func clock(_ s: TimeInterval) -> String {
        let s = max(0, Int(s))
        return String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
    }

    /// A menu-bar-only app must activate itself, or the opened window stays behind others.
    private func show(_ open: () -> Void) {
        NSApp.activate()
        open()
    }
}

/// Gold gradient progress bar (website `.hero-progress`).
struct ProgressBar: View {
    let value: Double
    @Environment(\.layoutDirection) private var dir
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.line)
                Capsule().fill(LinearGradient(colors: [Color(red: 0xb3 / 255, green: 0x8a / 255, blue: 0x2e / 255), Theme.goldFill],
                                              startPoint: .leading, endPoint: .trailing))
                    .frame(width: g.size.width * value)
            }
        }
    }
}
