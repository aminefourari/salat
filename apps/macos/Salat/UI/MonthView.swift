import SwiftUI

/// Monthly timetable, like the website's /month: one row per day, today and Fridays marked, printable.
struct MonthView: View {
    let engine: AlertEngine
    @State private var shift = 0 // months from the current one

    var lang: Lang { engine.settings.d.lang }

    private var shown: DateComponents {
        let cal = Calendar(identifier: .gregorian)
        let d = cal.date(byAdding: .month, value: shift, to: engine.now) ?? engine.now
        return cal.dateComponents(in: .autoupdatingCurrent, from: d)
    }

    private var rows: [MonthDay] {
        guard let loc = engine.loc, let y = shown.year, let m = shown.month else { return [] }
        let s = engine.settings.d
        return monthDays(year: y, month: m, lat: loc.lat, lon: loc.lon, method: engine.method, asr: s.asr, adjust: s.adjust, habous: s.habous)
    }

    private var title: String {
        let cal = Calendar(identifier: .gregorian)
        let d = cal.date(from: DateComponents(year: shown.year, month: shown.month, day: 15)) ?? engine.now
        return d.formatted(.dateTime.month(.wide).year().locale(lang.locale))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Button { shift -= 1 } label: { Image(systemName: lang.isRTL ? "chevron.right" : "chevron.left") }
                        .help(t(.prevMonth, lang))
                    Spacer()
                    Text("\(t(.monthly, lang)) · \(title)").font(Theme.kufi(20))
                    Spacer()
                    Button { shift += 1 } label: { Image(systemName: lang.isRTL ? "chevron.left" : "chevron.right") }
                        .help(t(.nextMonth, lang))
                }
                if engine.loc == nil {
                    Text(t(.noLocation, lang)).foregroundStyle(Theme.soft)
                } else {
                    MonthTable(rows: rows, lang: lang, today: Calendar(identifier: .gregorian).dateComponents(in: .autoupdatingCurrent, from: engine.now))
                        .panel()
                    footer
                }
            }
            .frame(maxWidth: 640).padding(24).frame(maxWidth: .infinity)
        }
        .themedWindow(sky: engine.sky)
        .environment(\.layoutDirection, lang.isRTL ? .rightToLeft : .leftToRight)
        .navigationTitle(t(.monthly, lang))
    }

    @ViewBuilder private var footer: some View {
        HStack {
            if rows.contains(where: \.official) { Text(t(.official, lang)) }
            else if engine.method == .morocco { Text(t(.approximate, lang)) }
            Spacer()
            Button(t(.print, lang)) { print() }
        }
        .font(Theme.plex(12)).foregroundStyle(Theme.soft)
    }

    /// Prints the table on white (light scheme), sized to its content.
    private func print() {
        let table = MonthTable(rows: rows, lang: lang, today: nil, title: "\(t(.monthly, lang)) · \(title)")
            .padding(24).frame(width: 560).environment(\.colorScheme, .light)
            .environment(\.layoutDirection, lang.isRTL ? .rightToLeft : .leftToRight)
        let v = NSHostingView(rootView: table)
        v.setFrameSize(v.fittingSize)
        NSPrintOperation(view: v).run()
    }
}

/// The table itself, shared by the window and the printout.
struct MonthTable: View {
    let rows: [MonthDay]
    let lang: Lang
    /// Marked row; nil when printing.
    let today: DateComponents?
    var title: String? = nil

    private let cols: [L10nKey] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { Text(title).font(Theme.kufi(18)) }
            Grid(horizontalSpacing: 10, verticalSpacing: 4) {
                GridRow {
                    Text(t(.date, lang)).gridColumnAlignment(.leading)
                    ForEach(cols, id: \.self) { Text(t($0, lang)) }
                }
                .font(Theme.plex(12, semibold: true)).foregroundStyle(Theme.gold)
                Divider()
                ForEach(rows, id: \.date) { r in
                    let isToday = today.map { $0.year == r.date.year && $0.month == r.date.month && $0.day == r.date.day } ?? false
                    let friday = Calendar(identifier: .gregorian).dateComponents([.weekday], from: r.day.dhuhr).weekday == 6
                    GridRow {
                        Text(r.day.dhuhr.formatted(.dateTime.weekday(.abbreviated).day().locale(lang.locale)))
                        ForEach([r.day.fajr, r.day.sunrise, r.day.dhuhr, r.day.asr, r.day.maghrib, r.day.isha], id: \.self) { Text(hm($0)) }
                    }
                    // Text styling only: a GridRow's background would paint each cell separately.
                    .font(Theme.plex(13, semibold: isToday || friday)).monospacedDigit()
                    .foregroundStyle(isToday ? Theme.gold : friday ? Theme.ink : Theme.ink.opacity(0.8))
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
