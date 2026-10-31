import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The widgets' faces. They live here, with the app, so its tests can draw them (for review and the App Store) as
/// well as the widget extension. Each takes the entry the timeline gives it.

/// One moment of a widget's timeline.
struct StatusEntry: TimelineEntry {
    let date: Date
    let status: Status?
    let paired: Bool

    static var sample: StatusEntry { StatusEntry(date: Date(), status: .sample, paired: true) }
}

// MARK: Home Screen

/// The state in a word or two and one quiet line under it; the computer's name and battery above. Nothing else.
struct StatusSmall: View {
    let entry: StatusEntry

    var body: some View {
        if let s = entry.status {
            VStack(alignment: .leading, spacing: 0) {
                Top(status: s)
                Spacer(minLength: 0)
                Summary(status: s, now: entry.date)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            Unpaired(paired: entry.paired)
        }
    }
}

/// The small face with one button: Always awake (or Wake, while it sleeps).
struct StatusMedium: View {
    let entry: StatusEntry

    var body: some View {
        if let s = entry.status {
            VStack(alignment: .leading, spacing: 0) {
                Top(status: s)
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 12) {
                    Summary(status: s, now: entry.date)
                    Spacer(minLength: 0)
                    KeepButton(status: s)
                        .fixedSize()
                        .layoutPriority(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            Unpaired(paired: entry.paired)
        }
    }
}

/// The computer's name, and its battery.
private struct Top: View {
    let status: Status

    var body: some View {
        HStack(spacing: 4) {
            Text(status.host).lineLimit(1)
            Spacer(minLength: 6)
            if let pct = status.pct {
                if status.plugged { Image(systemName: "bolt.fill").imageScale(.small) }
                Text("\(pct)%").monospacedDigit()
            }
        }
        .font(.system(.footnote, design: .rounded, weight: .semibold))
        .opacity(0.7)
    }
}

/// "Keeps working" over "Lid shut · 19 h left".
private struct Summary: View {
    let status: Status
    let now: Date

    var body: some View {
        let detail = status.detail(at: now)
        VStack(alignment: .leading, spacing: 2) {
            Text(status.headline)
                .font(.system(.title3, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if !detail.isEmpty {
                Text(detail)
                    .font(.footnote.weight(.medium))
                    .monospacedDigit()
                    .lineLimit(2)
                    .opacity(0.75)
            }
        }
    }
}

/// Always awake, on or off; Wake while it sleeps. Works without opening the app. Off stays in the app and Shortcuts.
private struct KeepButton: View {
    let status: Status

    var body: some View {
        if status.state == .asleep {
            Button(intent: WakeComputerIntent()) {
                Label("Wake", systemImage: "sun.max.fill").pill()
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.night)
            .background(.white, in: .capsule)
        } else {
            let on = KeepMode(wire: status.mode) == .always
            Button(intent: SetKeepModeIntent(on ? .auto : .always)) {
                Label("Always awake", systemImage: on ? "checkmark.circle.fill" : "circle").pill()
            }
            .buttonStyle(.plain)
            .foregroundStyle(on ? Palette.deep : .white)
            .background(on ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.16)), in: .capsule)
            .accessibilityAddTraits(on ? .isSelected : [])
        }
    }
}

private extension View {
    func pill() -> some View {
        font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
    }
}

private struct Unpaired: View {
    let paired: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Nocturnal")
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .opacity(0.7)
            Spacer(minLength: 0)
            Text(paired ? "Open the app" : "Pair in the app")
                .font(.system(.title3, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

extension View {
    /// The app's ground: green while the computer keeps working, night otherwise. White ink on both.
    func widgetGround(_ s: Status?) -> some View {
        foregroundStyle(.white)
            .containerBackground(for: .widget) {
                MeshGradient(width: 3, height: 3, points: Palette.meshPoints,
                             colors: Palette.ground(s?.awake ?? true ? 1 : 0), smoothsColors: true, colorSpace: .perceptual)
            }
    }
}

// MARK: Lock Screen

private extension Status {
    var symbol: String {
        switch state {
        case .working: "sun.max.fill"
        case .normal: "laptopcomputer"
        case .asleep: "moon.zzz.fill"
        case .silent: "wifi.slash"
        }
    }

    var figuresLine: String {
        var parts: [String] = []
        if let pct { parts.append("\(pct)%") }
        if let hours, !plugged { parts.append("\(Int(hours.rounded())) h left") }
        if plugged { parts.append("charging") }
        return parts.joined(separator: " · ")
    }
}

struct StatusCircular: View {
    let entry: StatusEntry

    var body: some View {
        if let s = entry.status, let pct = s.pct {
            Gauge(value: Double(pct), in: 0...100) {
                Image(systemName: s.symbol)
            } currentValueLabel: {
                Image(systemName: s.symbol).font(.system(size: 16, weight: .semibold))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetAccentable()
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: entry.status?.symbol ?? "laptopcomputer").font(.system(size: 18, weight: .semibold))
            }
            .containerBackground(for: .widget) { Color.clear }
        }
    }
}

struct StatusRectangular: View {
    let entry: StatusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let s = entry.status {
                Label(s.headline, systemImage: s.symbol)
                    .font(.headline)
                    .widgetAccentable()
                let detail = s.detail(at: entry.date)
                Text(detail.isEmpty ? s.figuresLine : detail).font(.subheadline).lineLimit(1)
            } else {
                Label("Nocturnal", systemImage: "laptopcomputer").font(.headline)
                Text(entry.paired ? "Open the app" : "Pair in the app").font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct StatusInline: View {
    let entry: StatusEntry

    var body: some View {
        if let s = entry.status {
            Label(s.pct.map { "\(s.headline) · \($0)%" } ?? s.headline, systemImage: s.symbol)
        } else {
            Label("Nocturnal", systemImage: "laptopcomputer")
        }
    }
}

extension Status {
    static var sample: Status {
        var p = Panel()
        p.host = "MacBook Pro"
        p.keeps = true
        p.lidClosed = true
        p.mode = "auto"
        p.agents = [.init(id: "claude", name: "Claude Code", working: true, state: "working")]
        p.numbers = .init(pct: 82, w: 3.1, h: 19)
        return Status(panel: p, at: Date(), demo: true)
    }
}

// MARK: Live Activity

/// The Live Activity on the Lock Screen: the computer, when it goes back to normal, the time left and a bar.
struct AwakeLockScreen: View {
    let host: String
    let state: AwakeAttributes.ContentState
    let ended: Bool
    /// A still picture's progress (the system only runs the timer bar in a real Live Activity).
    var still: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(host)
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .opacity(0.7)
                    Text(ended ? "Back to When busy" : "Awake until " + state.until.formatted(date: .omitted, time: .shortened))
                        .font(.headline)
                }
                .lineLimit(1)
                Spacer(minLength: 8)
                Countdown(state: state, ended: ended)
                    .font(.system(.title, design: .rounded, weight: .semibold))
            }
            Group {
                if let still {
                    Capsule().fill(.white.opacity(0.2)).frame(height: 4)
                        .overlay(alignment: .leading) {
                            GeometryReader { g in Capsule().fill(Palette.mint).frame(width: g.size.width * still) }
                        }
                } else {
                    ProgressView(timerInterval: state.from...max(state.until, state.from.addingTimeInterval(1)), countsDown: false) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                }
            }
            .tint(Palette.mint)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
}

/// Time left, counted by the system.
struct Countdown: View {
    let state: AwakeAttributes.ContentState
    let ended: Bool

    var body: some View {
        if ended || state.until <= Date() {
            Image(systemName: "checkmark")
        } else {
            Text(timerInterval: Date()...state.until, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
    }
}
