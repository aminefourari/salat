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
        VStack(alignment: .leading, spacing: 10) {
            if let today = engine.today, let next = engine.next {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t(.next, lang)).font(.caption).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline) {
                        Text(prayerName(next.prayer, lang)).font(.title2.bold())
                        Spacer()
                        Text(t(.inTime, lang, ["time": countdown(next.at.timeIntervalSince(engine.now))])).monospacedDigit()
                    }
                }
                Divider()
                VStack(spacing: 4) {
                    ForEach(rows(today), id: \.0) { key, name, time in
                        let isNext = key == next.prayer.rawValue && Calendar.current.isDate(next.at, inSameDayAs: engine.now)
                        HStack {
                            Text(name)
                            Spacer()
                            Text(hm(time)).monospacedDigit()
                        }
                        .font(key == "sunrise" ? .callout : .body)
                        .foregroundStyle(key == "sunrise" ? .secondary : .primary)
                        .padding(.vertical, 3).padding(.horizontal, 8)
                        .background(isNext ? Color.accentColor.opacity(0.18) : .clear, in: .rect(cornerRadius: 6))
                    }
                }
                if let city = engine.loc?.city {
                    Text("\(flag(city.cc)) \(city.name)").font(.caption).foregroundStyle(.secondary)
                }
                Text(methodName(engine.method, lang)).font(.caption2).foregroundStyle(.tertiary)
                if engine.method == .morocco {
                    Text(t(.approximate, lang)).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                let waiting = (engine.location.authorized || engine.location.status == .notDetermined) && !engine.location.failed
                Text(waiting ? t(.locating, lang) : t(.noLocation, lang))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if engine.player.isPlaying {
                Button(t(.stop, lang), systemImage: "stop.fill") { engine.player.stop() }
                    .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
            }
            Divider()
            HStack {
                Button(t(.quran, lang), systemImage: "book") { show { openWindow(id: "quran") } }
                Button(t(.adhkar, lang), systemImage: "hands.and.sparkles") { show { openWindow(id: "adhkar") } }
                Spacer()
                Button(t(.settings, lang)) { show { openSettings() } }
                Button(t(.quit, lang), systemImage: "power") { NSApp.terminate(nil) }.labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 280)
        .environment(\.layoutDirection, lang.isRTL ? .rightToLeft : .leftToRight)
    }

    private func rows(_ d: DayTimes) -> [(String, String, Date)] {
        [(Prayer.fajr.rawValue, prayerName(.fajr, lang), d.fajr), ("sunrise", t(.sunrise, lang), d.sunrise)]
            + Prayer.allCases.dropFirst().map { ($0.rawValue, prayerName($0, lang), d[$0]) }
    }

    /// A menu-bar-only app must activate itself, or the opened window stays behind others.
    private func show(_ open: () -> Void) {
        NSApp.activate()
        open()
    }
}
