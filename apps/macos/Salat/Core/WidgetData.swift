import Foundation

/// What the menu-bar app hands the widget: the coming prayer times (offsets and Habous already applied) and the
/// labels in the app's language. The widget is sandboxed and computes nothing; it reads this file through a
/// read-only exception for ~/Library/Application Support/Salat (an unsigned app can't use an App Group).
struct WidgetData: Codable, Equatable, Sendable {
    /// Prayer names, Fajr…Isha.
    var names: [String]
    var next: String
    var place: String?
    var rtl: Bool
    /// One entry per day, each Fajr…Isha.
    var days: [[Date]]

    static let fileName = "widget.json"

    /// ~/Library/Application Support/Salat/widget.json, the real home even inside the widget's sandbox.
    static var url: URL {
        let home = getpwuid(getuid()).flatMap { $0.pointee.pw_dir.map { String(cString: $0) } } ?? NSHomeDirectory()
        return URL(fileURLWithPath: home).appendingPathComponent("Library/Application Support/Salat/\(fileName)")
    }

    /// The next prayer after `now` and the day it belongs to (for the medium widget's list).
    func upcoming(after now: Date) -> (index: Int, at: Date, day: [Date])? {
        for day in days { if let i = day.firstIndex(where: { $0 > now }) { return (i, day[i], day) } }
        return nil
    }
}
