import SwiftUI
import Testing
@testable import NocturnalPhone

/// Draws every widget face and the Live Activity in each state, at three times their size, for review and the App
/// Store (written to dist/review/widgets when the Mac's folder is reachable). The widgets' own backgrounds only
/// appear on the Home Screen, so the ground is drawn here the same way.
@MainActor
struct WidgetShots {
    @Test func drawEverything() throws {
        var asleep = Status.sample
        asleep.state = .asleep
        asleep.headline = "Asleep"
        asleep.line = ""
        asleep.checkIn = 15
        asleep.demo = false
        asleep.at = Date().addingTimeInterval(-40 * 60)
        var waiting = Status.sample
        waiting.line = "Codex is waiting for you"
        waiting.mode = "on"
        waiting.demo = false
        let states: [(String, StatusEntry)] = [
            ("working", StatusEntry(date: Date(), status: { var s = Status.sample; s.demo = false; return s }(), paired: true)),
            ("waiting", StatusEntry(date: Date(), status: waiting, paired: true)),
            ("asleep", StatusEntry(date: Date(), status: asleep, paired: true)),
            ("unpaired", StatusEntry(date: Date(), status: nil, paired: false)),
        ]
        for (name, e) in states {
            save(home(StatusSmall(entry: e), e.status, CGSize(width: 170, height: 170)), "small-\(name)")
            save(home(StatusMedium(entry: e), e.status, CGSize(width: 364, height: 170)), "medium-\(name)")
            save(lock(StatusRectangular(entry: e), CGSize(width: 172, height: 76)), "lock-rect-\(name)")
            save(lock(StatusCircular(entry: e), CGSize(width: 76, height: 76)), "lock-circle-\(name)")
            save(lock(StatusInline(entry: e), CGSize(width: 260, height: 24)), "lock-inline-\(name)")
        }
        let state = AwakeAttributes.ContentState(from: Date().addingTimeInterval(-1800), until: Date().addingTimeInterval(5400))
        save(AwakeLockScreen(host: "MacBook Pro", state: state, ended: false, still: 0.25)
            .frame(width: 364).background(Palette.deep).clipShape(.rect(cornerRadius: 24)), "live-activity")
    }

    private func home(_ v: some View, _ s: Status?, _ size: CGSize) -> some View {
        v.padding(16)
            .frame(width: size.width, height: size.height)
            .foregroundStyle(.white)
            .background(MeshGradient(width: 3, height: 3, points: Palette.meshPoints,
                                     colors: Palette.ground(s?.awake ?? true ? 1 : 0), smoothsColors: true, colorSpace: .perceptual))
            .clipShape(.rect(cornerRadius: 22, style: .continuous))
    }

    /// Lock Screen widgets are white on the wallpaper; a dark wallpaper stands in.
    private func lock(_ v: some View, _ size: CGSize) -> some View {
        v.frame(width: size.width, height: size.height)
            .foregroundStyle(.white)
            .padding(8)
            .background(Color(white: 0.12))
            .environment(\.colorScheme, .dark)
    }

    private func save(_ v: some View, _ name: String) {
        let r = ImageRenderer(content: v)
        r.scale = 3
        guard let data = r.uiImage?.pngData() else { Issue.record("couldn't draw \(name)"); return }
        let dir = URL(fileURLWithPath: NSHomeDirectory().components(separatedBy: "/Library/Developer").first ?? NSHomeDirectory())
            .appendingPathComponent("Developer/Nocturnal/dist/review/widgets")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: dir.appendingPathComponent(name + ".png"))
    }
}
