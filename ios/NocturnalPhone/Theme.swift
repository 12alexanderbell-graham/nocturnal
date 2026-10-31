import SwiftUI

/// Nocturnal's look, shared by every screen. The rules it follows (from the design book):
/// - The state is the material: the whole screen is green while the computer keeps working, night while it sleeps.
/// - One ink: white, at full strength. No grey text, no low-opacity controls.
/// - Fixed places: the head at the top, the keep-awake band at the bottom, the main circle bottom right. Nothing that
///   appears ever moves what is already on the screen.
/// - Nothing fades: things rise into place, roll, or grow out of what opened them and go back into it.
/// - Corners nest: a sheet 8 in from the screen's 62 pt corner has a 54 pt corner.
enum Theme {
    static let side: CGFloat = 20               // head and bottom stand on the same two side lines
    static let bottom: CGFloat = 20
    static let head: CGFloat = 44               // head circles
    static let band: CGFloat = 56               // the keep-awake band and the main circle
    static let gap: CGFloat = 8
    /// The widest the content gets: on a wider screen (iPhone Duo open or turned) it's a column in the middle.
    static let column: CGFloat = 500
    /// From this width (iPhone Duo open and turned, iPad) the screens use two columns side by side, this far apart.
    static let wide: CGFloat = 760
    static let split: CGFloat = 56
    static let sheetInset: CGFloat = 8
    static let screenCorner: CGFloat = 62
    static var sheetCorner: CGFloat { screenCorner - sheetInset }

    // The palette (shared with the widgets): night, the greens of the app icon, white ink, and red only for errors.
    static let night = Palette.night
    static let nightLift = Palette.nightLift
    static let nightGlow = Palette.nightGlow
    static let deep = Palette.deep
    static let green = Palette.green
    static let mint = Palette.mint
    static let amber = Palette.amber
    static let red = Palette.red

    // One spring family.
    static let chrome = Animation.spring(response: 0.38, dampingFraction: 0.84)
    static let quick = Animation.spring(response: 0.26, dampingFraction: 1)
    static let smooth = Animation.spring(response: 0.44, dampingFraction: 1)
    static let grow = Animation.spring(response: 0.42, dampingFraction: 0.8)
    static let rise = Animation.spring(response: 0.55, dampingFraction: 0.86)

    static func freshnessColor(_ k: Computer.Freshness) -> Color {
        switch k {
        case .live: mint
        case .bad: amber
        case .done, .busy, .stale: .white
        }
    }
}

/// Words and blocks arriving on a screen rise 14 pt into place, one after another.
struct Rise: ViewModifier {
    let order: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(y: shown || reduceMotion ? 0 : 14)
            .blur(radius: shown || reduceMotion ? 0 : 6)
            .onAppear {
                withAnimation(Theme.rise.delay(Double(order) * 0.05)) { shown = true }
            }
    }
}

extension View {
    func rise(_ order: Int = 0) -> some View { modifier(Rise(order: order)) }
}

/// Press: sinks at once (90 ms), comes back softer (260 ms).
struct Press: ButtonStyle {
    var scale: CGFloat = 0.94
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(configuration.isPressed ? .easeOut(duration: 0.09) : .easeOut(duration: 0.26), value: configuration.isPressed)
    }
}

/// On a wide screen, centres its content on the whole screen rather than on the safe area: the same inset on both
/// sides (the larger of the two), so a strip on one side (iPhone Duo's clock and buttons) doesn't pull everything off
/// centre. Top and bottom match too, unless the keyboard is up.
struct ScreenCentred<Content: View>: View {
    @ViewBuilder let content: (CGSize) -> Content

    var body: some View {
        GeometryReader { geo in
            let s = geo.safeAreaInsets
            let screen = CGSize(width: geo.size.width + s.leading + s.trailing, height: geo.size.height + s.top + s.bottom)
            let side = max(s.leading, s.trailing)
            let keyboard = s.bottom > 80
            let top = keyboard ? s.top : max(s.top, s.bottom)
            let bottom = keyboard ? s.bottom : top
            let size = CGSize(width: max(0, screen.width - side * 2), height: max(0, screen.height - top - bottom))
            content(size)
                .frame(width: size.width, height: size.height)
                .position(x: screen.width / 2 - s.leading, y: top + size.height / 2 - s.top)
        }
    }
}
