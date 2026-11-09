import SwiftUI

/// Developer tool: `Salat.app/Contents/MacOS/Salat -snapshot DIR` renders the main views in dark and light
/// to PNGs (used for README screenshots and checking the theme without clicking through the UI), then quits.
@MainActor
enum Snapshots {
    static var dir: URL? {
        let a = ProcessInfo.processInfo.arguments
        return a.firstIndex(of: "-snapshot").flatMap { a.indices.contains($0 + 1) ? URL(fileURLWithPath: a[$0 + 1]) : nil }
    }

    /// In snapshot mode the main window opens at launch so they can be captured.
    static var launch: SceneLaunchBehavior { dir == nil ? .automatic : .presented }

    static func run(engine: AlertEngine, quran: QuranPlayer, adhkar: AdhkarPlayer, to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        engine.settings.d.lastAdhkarChapter = 27
        engine.settings.d.lastSurah = 1
        func pass(_ dark: Bool, then next: @escaping @MainActor () -> Void) {
            NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                let name = dark ? "dark" : "light"
                save(MenuView(engine: engine), dark ? .dark : .light, dir.appendingPathComponent("menu-\(name).png"))
                // Each section of the main window, one second apart so it can render.
                @MainActor func shoot(_ kinds: ArraySlice<AppSection>) {
                    guard let kind = kinds.first else { return next() }
                    UserDefaults.standard.set(kind.rawValue, forKey: "section")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        for w in NSApp.windows where w.isVisible && (w.identifier?.rawValue ?? "").contains("main") {
                            capture(w, dir.appendingPathComponent("\(kind == .prayer ? "times" : kind.rawValue)-\(name).png"))
                        }
                        shoot(kinds.dropFirst())
                    }
                }
                shoot(AppSection.allCases[...])
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { // let location and the first tick settle
            pass(true) { pass(false) { NSApp.terminate(nil) } }
        }
    }

    /// A real window screenshot (sidebars and materials included); needs Screen Recording permission for the caller.
    private static func capture(_ w: NSWindow, _ url: URL) {
        w.orderFrontRegardless()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-x", "-o", "-l", "\(w.windowNumber)", url.path]
        try? p.run()
        p.waitUntilExit()
    }

    private static func save(_ view: some View, _ scheme: ColorScheme, _ url: URL) {
        let r = ImageRenderer(content: view.environment(\.colorScheme, scheme))
        r.scale = 2
        guard let cg = r.cgImage, let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }
}
