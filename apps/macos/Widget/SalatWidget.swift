import SwiftUI
import WidgetKit

// Next prayer on the desktop / Notification Center. Reads the times the menu-bar app writes (WidgetData).

struct Entry: TimelineEntry {
    let date: Date
    let data: WidgetData?
}

struct Provider: TimelineProvider {
    private func load() -> WidgetData? {
        (try? Data(contentsOf: WidgetData.url)).flatMap { try? JSONDecoder().decode(WidgetData.self, from: $0) }
    }

    func placeholder(in context: Context) -> Entry { Entry(date: .now, data: nil) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(Entry(date: .now, data: load())) }

    /// One entry now and one at each coming prayer, so "next" moves on by itself; the app reloads it when times change.
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let data = load(), now = Date.now
        let times = (data?.days.flatMap { $0 } ?? []).filter { $0 > now }
        completion(Timeline(entries: [Entry(date: now, data: data)] + times.map { Entry(date: $0, data: data) }, policy: .atEnd))
    }
}

private let gold = Color(red: 0xe2 / 255, green: 0xc4 / 255, blue: 0x6e / 255)
private let soft = Color(red: 0xb5 / 255, green: 0xcd / 255, blue: 0xbd / 255)
private let green = [Color(red: 0x03 / 255, green: 0x2a / 255, blue: 0x1a / 255), Color(red: 0x0b / 255, green: 0x5d / 255, blue: 0x3b / 255)]

private func hm(_ d: Date) -> String {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_GB"); f.dateFormat = "HH:mm"
    return f.string(from: d)
}

struct SalatWidgetView: View {
    let entry: Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let data = entry.data, let next = data.upcoming(after: entry.date) {
                if family == .systemSmall { small(data, next) } else { HStack(spacing: 14) { small(data, next); list(data, next) } }
            } else {
                Text("Salat").font(.custom("Reem Kufi", size: 20).bold()).foregroundStyle(gold)
            }
        }
        .foregroundStyle(.white)
        .environment(\.layoutDirection, entry.data?.rtl == true ? .rightToLeft : .leftToRight)
        .containerBackground(for: .widget) { LinearGradient(colors: green, startPoint: .top, endPoint: .bottom) }
    }

    private func small(_ data: WidgetData, _ next: (index: Int, at: Date, day: [Date])) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(data.next).font(.caption).foregroundStyle(soft)
            Text(data.names[next.index]).font(.custom("Reem Kufi", size: 26).bold()).minimumScaleFactor(0.6).lineLimit(1)
            Text(hm(next.at)).font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(gold)
            Text(next.at, style: .relative).font(.caption).foregroundStyle(soft).monospacedDigit()
            Spacer(minLength: 0)
            if let place = data.place { Text(place).font(.caption2).foregroundStyle(soft).lineLimit(1) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func list(_ data: WidgetData, _ next: (index: Int, at: Date, day: [Date])) -> some View {
        VStack(spacing: 3) {
            ForEach(Array(next.day.enumerated()), id: \.offset) { i, at in
                HStack {
                    Text(data.names[i])
                    Spacer()
                    Text(hm(at)).monospacedDigit()
                }
                .font(.callout.weight(i == next.index ? .semibold : .regular))
                .foregroundStyle(i == next.index ? gold : at < entry.date ? soft.opacity(0.7) : .white)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

@main
struct SalatWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SalatNext", provider: Provider()) { SalatWidgetView(entry: $0) }
            .configurationDisplayName("Salat")
            .description("Next prayer and today's times.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
