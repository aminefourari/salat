import SwiftUI

// The website's look (apps/web/src/styles.css): royal green and gold, Reem Kufi titles, IBM Plex Sans Arabic text,
// a faint star lattice. Dark mode is the site; light mode is the same palette on cream (user decision: follow system).

private func dynamic(_ dark: UInt32, _ light: UInt32, _ darkAlpha: CGFloat = 1, _ lightAlpha: CGFloat = 1) -> Color {
    func ns(_ hex: UInt32, _ a: CGFloat) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: a)
    }
    return Color(nsColor: NSColor(name: nil) { ap in
        ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? ns(dark, darkAlpha) : ns(light, lightAlpha)
    })
}

enum Theme {
    static let gold = dynamic(0xe2c46e, 0xb38a2e)
    static let goldLight = Color(red: 0xf1 / 255, green: 0xda / 255, blue: 0x8e / 255)
    static let goldFill = Color(red: 0xe2 / 255, green: 0xc4 / 255, blue: 0x6e / 255)
    static let royalDeep = Color(red: 0x05 / 255, green: 0x3a / 255, blue: 0x23 / 255)
    static let ink = dynamic(0xf3f7f1, 0x053a23)
    static let soft = dynamic(0xb5cdbd, 0x4d6b5a)
    static let line = dynamic(0xffffff, 0x053a23, 0.12, 0.14)
    static let panel = dynamic(0x053a23, 0xffffff, 0.55, 0.6)
    static let panelStrong = dynamic(0x053a23, 0xfffaf0, 0.8, 0.85)

    /// Gradient stops per prayer period, as on the website (`data-sky`); light mode stays cream.
    static func gradient(_ sky: Sky, dark: Bool) -> [Color] {
        guard dark else { return [Color(red: 0.97, green: 0.94, blue: 0.87), Color(red: 0.93, green: 0.89, blue: 0.79)] }
        let hex: (UInt32, UInt32) = switch sky {
        case .night: (0x032a1a, 0x0a4a30)
        case .dawn: (0x053a26, 0x2d6a4a)
        case .day: (0x0b5d3b, 0x157049)
        case .afternoon: (0x0a5636, 0x2e7444)
        case .dusk: (0x053a23, 0x24603a)
        }
        return [rgb(hex.0), rgb(hex.1)]
    }

    /// Split out with explicit types: inline, this took >1 s to type-check and failed CI's compiler time limit.
    static func rgb(_ hex: UInt32) -> Color {
        let r: Double = Double((hex >> 16) & 0xff) / 255
        let g: Double = Double((hex >> 8) & 0xff) / 255
        let b: Double = Double(hex & 0xff) / 255
        return Color(red: r, green: g, blue: b)
    }

    static func kufi(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font { .custom("Reem Kufi", size: size).weight(weight) }
    static func plex(_ size: CGFloat, semibold: Bool = false) -> Font {
        .custom(semibold ? "IBM Plex Sans Arabic SemiBold" : "IBM Plex Sans Arabic", size: size)
    }
}

/// Royal green (or cream) gradient with the gold star lattice fading out toward the bottom.
struct ThemedBackground: View {
    var sky: Sky = .night
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            LinearGradient(colors: Theme.gradient(sky, dark: scheme == .dark), startPoint: .top, endPoint: .bottom)
            StarLattice()
                .opacity(scheme == .dark ? 0.09 : 0.14)
                .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.35),
                                             .init(color: .clear, location: 0.85)], startPoint: .top, endPoint: .bottom))
        }
        .ignoresSafeArea()
    }
}

/// The website's 64 px tile: eight-point stars (two overlapping squares) at the corners and centre, joined by short lines.
struct StarLattice: View {
    var body: some View {
        Canvas { ctx, size in
            let tile: CGFloat = 64
            var stars = Path(), lines = Path()
            for star in [CGPoint(x: 0, y: 0), CGPoint(x: 64, y: 0), CGPoint(x: 0, y: 64), CGPoint(x: 64, y: 64), CGPoint(x: 32, y: 32)] {
                let sq = CGRect(x: -9, y: -9, width: 18, height: 18)
                stars.addPath(Path(sq).applying(CGAffineTransform(translationX: star.x, y: star.y)))
                stars.addPath(Path(sq).applying(CGAffineTransform(rotationAngle: .pi / 4).concatenating(CGAffineTransform(translationX: star.x, y: star.y))))
            }
            for (a, b) in [((9, 0), (23, 0)), ((41, 0), (55, 0)), ((9, 64), (23, 64)), ((41, 64), (55, 64)), ((0, 9), (0, 23)),
                           ((0, 41), (0, 55)), ((64, 9), (64, 23)), ((64, 41), (64, 55)), ((41, 32), (55, 32)), ((9, 32), (23, 32)),
                           ((32, 9), (32, 23)), ((32, 41), (32, 55))] {
                lines.move(to: CGPoint(x: a.0, y: a.1)); lines.addLine(to: CGPoint(x: b.0, y: b.1))
            }
            for x in stride(from: 0, to: size.width, by: tile) {
                for y in stride(from: 0, to: size.height, by: tile) {
                    let t = CGAffineTransform(translationX: x, y: y)
                    ctx.stroke(stars.applying(t), with: .color(Theme.goldFill), lineWidth: 1)
                    ctx.stroke(lines.applying(t), with: .color(Theme.goldFill.opacity(0.6)), lineWidth: 1)
                }
            }
        }
    }
}

/// The mihrab arch around the next prayer (website viewBox 0 0 200 260).
struct ArchShape: Shape {
    var inner = false
    func path(in r: CGRect) -> Path {
        let sx = r.width / 200, sy = r.height / 260
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * sx, y: r.minY + y * sy) }
        var path = Path()
        if inner {
            path.move(to: p(14, 260)); path.addLine(to: p(14, 116))
            path.addCurve(to: p(100, 18), control1: p(14, 68), control2: p(56, 38))
            path.addCurve(to: p(186, 116), control1: p(144, 38), control2: p(186, 68))
            path.addLine(to: p(186, 260))
        } else {
            path.move(to: p(4, 260)); path.addLine(to: p(4, 112))
            path.addCurve(to: p(100, 4), control1: p(4, 58), control2: p(52, 26))
            path.addCurve(to: p(196, 112), control1: p(148, 26), control2: p(196, 58))
            path.addLine(to: p(196, 260)); path.closeSubpath()
        }
        return path
    }
}

extension View {
    /// The website's `.panel`: translucent deep green (white on cream) with a hairline border.
    func panel(_ radius: CGFloat = 16, padding: CGFloat = 14) -> some View {
        self.padding(padding)
            .background(Theme.panel, in: .rect(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.line, lineWidth: 1))
    }

    /// Window chrome: themed background, hidden toolbar background, gold tint, theme fonts and ink.
    func themedWindow(sky: Sky = .night) -> some View {
        self.font(Theme.plex(14))
            .foregroundStyle(Theme.ink)
            .tint(Theme.gold)
            .scrollContentBackground(.hidden)
            .background(ThemedBackground(sky: sky))
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }
}

/// `.btn-solid`: gold gradient pill with deep green text.
struct GoldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.plex(13, semibold: true))
            .foregroundStyle(Theme.royalDeep)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(LinearGradient(colors: [Theme.goldLight, Theme.goldFill], startPoint: .top, endPoint: .bottom), in: .capsule)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(.capsule)
    }
}

/// `.btn`: gold outline pill.
struct GoldOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.plex(13, semibold: true))
            .foregroundStyle(Theme.gold)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .overlay(Capsule().stroke(Theme.gold, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(.capsule)
    }
}

/// SF Symbols matching the website's prayer icons.
func prayerSymbol(_ key: String) -> String {
    switch key {
    case "fajr": "sun.horizon"
    case "sunrise": "sunrise"
    case "dhuhr": "sun.max"
    case "asr": "sun.min"
    case "maghrib": "sunset"
    default: "moon.stars"
    }
}
