import SwiftUI

/// The one screen. The ground is the state (green while the computer keeps working, night while it sleeps). The bar
/// holds Exit Demo (in the demo) and Settings: system toolbar items, so iOS puts them where they belong on every
/// screen (the top bar on an iPhone, the side strip by the clock on iPhone Duo's outer screen). Then a slot for
/// notices; which computer, how fresh the news is, what it's doing, its numbers and what the lid-shut time has saved;
/// what the band is set to (or the Undo), the keep-awake band and the main circle (sleep now, or wake it).
/// On a wide screen (iPhone Duo open, iPad) the words and the controls stand side by side.
struct HomeView: View {
    @Environment(Computer.self) private var computer
    @Environment(\.scenePhase) private var phase
    @State private var settingsShown = false
    @Namespace private var ns

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            GeometryReader { geo in
                if geo.size.width >= Theme.wide {
                    ScreenCentred { size in wide(context.date, size) }
                } else {
                    narrow(context.date)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .onChange(of: context.date) { _, now in if phase == .active { computer.tick(now) } }
        }
        .foregroundStyle(.white)
        .toolbar {
            if computer.isDemo, !computer.isMarketing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Exit Demo", systemImage: "xmark") { withAnimation(Theme.smooth) { computer.forget() } }
                        .accessibilityIdentifier("exitDemo")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings", systemImage: "gearshape.fill") { settingsShown = true }
                    .accessibilityIdentifier("settings")
            }
            .matchedTransitionSource(id: "settings", in: ns)
        }
        .sheet(isPresented: $settingsShown) {
            SettingsPage()
                .presentationDetents([.medium, .large])
                .navigationTransition(.zoom(sourceID: "settings", in: ns))
        }
        // Only a real trip to the background closes the stream: a glance at Notification Center (inactive) doesn't.
        .onChange(of: phase, initial: true) { old, now in
            if now == .active, old != .inactive || !computer.listening { computer.appeared() }
            if now == .background { computer.disappeared() }
        }
    }

    // MARK: Layout

    /// A phone: one column under the bar.
    private func narrow(_ now: Date) -> some View {
        VStack(spacing: 0) {
            NoticeSlot(notice: notice)
                .frame(height: 52)
            Spacer(minLength: 8)
            hero(now)
            Spacer(minLength: 8)
            figures
            Spacer(minLength: 8)
            bottom
                .padding(.bottom, Theme.bottom - 14)
        }
        .padding(.horizontal, Theme.side)
        .frame(maxWidth: Theme.column)
    }

    /// A wide screen: the words on the left, the numbers and the controls on the right.
    private func wide(_ now: Date, _ size: CGSize) -> some View {
        let half = min((size.width - Theme.side * 2 - Theme.split) / 2, Theme.column)
        return VStack(spacing: 0) {
            NoticeSlot(notice: notice)
                .frame(height: 52)
                .frame(maxWidth: half * 2 + Theme.split)
            Spacer(minLength: 8)
            HStack(alignment: .center, spacing: Theme.split) {
                hero(now)
                    .frame(width: half)
                VStack(spacing: 36) {
                    figures
                    bottom
                }
                .frame(width: half)
            }
            Spacer(minLength: 8)
            // As tall as the notice slot, so the two columns sit in the middle of the screen.
            Color.clear.frame(height: 52)
        }
        .padding(.horizontal, Theme.side)
    }

    private func hero(_ now: Date) -> some View {
        let fresh = computer.freshness(at: now)
        return VStack(spacing: 0) {
            Text(computer.panel?.host ?? "Your computer")
                .font(.headline)
                .lineLimit(1)
                .rise(0)
            Button { Task { await computer.refresh() } } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(fresh.kind == .busy ? AnyShapeStyle(.clear) : AnyShapeStyle(Theme.freshnessColor(fresh.kind)))
                        .strokeBorder(Theme.freshnessColor(fresh.kind), lineWidth: fresh.kind == .busy ? 2 : 0)
                        .frame(width: 8, height: 8)
                    Text(fresh.text)
                        .font(.subheadline.weight(.semibold))
                        .contentTransition(.interpolate)
                }
                .foregroundStyle(Theme.freshnessColor(fresh.kind))
                .frame(minHeight: 32)
                .padding(.horizontal, 10)
                .contentShape(.capsule)
            }
            .buttonStyle(Press())
            .animation(Theme.smooth, value: fresh.text)
            .accessibilityHint("Refreshes")
            .rise(1)

            Text(computer.headline)
                .font(.system(.largeTitle, weight: .bold))
                .multilineTextAlignment(.center)
                .contentTransition(.interpolate)
                .animation(Theme.smooth, value: computer.headline)
                .padding(.top, 18)
                .accessibilityIdentifier("headline")
                .rise(2)
            Text(computer.line)
                .font(.body)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .contentTransition(.interpolate)
                .animation(Theme.smooth, value: computer.line)
                .padding(.top, 8)
                .padding(.horizontal, 12)
                .rise(3)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    /// Battery, power draw and hours left with the lid shut; then what the lid-shut time is worth.
    private var figures: some View {
        let p = computer.panel
        let n = p?.figures
        return VStack(spacing: 18) {
            HStack(spacing: 0) {
                if let n {
                    Figure(value: Double(n.pct), digits: 0, unit: "%",
                           spoken: n.charging ? "Battery, charging" : n.plugged ? "Battery, plugged in" : "Battery")
                    Figure(value: n.w, digits: (n.w ?? 0) < 10 ? 1 : 0, unit: "W", spoken: "Using now")
                    Figure(value: n.h, digits: (n.h ?? 0) < 10 ? 1 : 0, unit: "h",
                           spoken: n.plugged ? "Hours on battery with the lid shut" : "Hours left with the lid shut")
                }
            }
            .frame(height: 44)
            Text(savingsLine(p))
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .contentTransition(.interpolate)
        }
        .rise(4)
    }

    /// Two lines: the week so far ("6 h 20 min working, lid shut" / "4 sessions · ≈38 Wh saved"), or what being shut
    /// saves right now.
    private func savingsLine(_ p: Panel?) -> String {
        guard let p else { return "" }
        if let t = p.weekTitle { return "This week: " + t + (p.weekLine.map { "\n" + $0 } ?? "") }
        return p.drawLine ?? ""
    }

    private var bottom: some View {
        VStack(spacing: 10) {
            ReadoutSlot(words: computer.hovering?.word ?? computer.stopWords)
                .frame(height: 30)
            HStack(alignment: .center, spacing: 14) {
                KeepAwakeBand(stop: computer.shownStop, enabled: computer.reachable,
                              hovering: Binding(get: { computer.hovering }, set: { computer.hovering = $0 })) { s in
                    // With the lid shut and nothing else holding it, Off sleeps it: Undo for a few seconds.
                    if s == .off, let p = computer.panel, p.lidClosed, p.mode != "off", p.holdList.isEmpty {
                        computer.hold(.off)
                    } else {
                        if computer.held == .off { computer.undoHeld() }
                        Task { await computer.choose(s) }
                    }
                }
                mainCircle
            }
        }
        .rise(5)
    }

    /// One circle, one place: Sleep Now while it's awake, Undo while a sleep counts down, Wake It while it's asleep
    /// (and an hourglass once the wake is on its way). With check-ins off a sleeping computer can't be woken from
    /// here, so the circle stays a moon and does nothing. The symbol morphs; the circle never moves.
    private var mainCircle: some View {
        let held = computer.held != nil
        let reachable = computer.reachable
        let waking = !reachable && computer.wakeSentAt != nil
        let canWake = computer.checkIn > 0
        let symbol = held ? "arrow.uturn.backward" : reachable ? "moon.zzz.fill" : waking ? "hourglass" : canWake ? "sun.max.fill" : "moon.zzz.fill"
        let label = held ? "Undo" : reachable ? "Sleep now" : waking ? "Wake sent" : canWake ? "Wake it" : "Can't be woken from here"
        return Button {
            if held { withAnimation(Theme.chrome) { computer.undoHeld() } }
            else if reachable { computer.hold(.sleep) }
            else { Task { await computer.wake() } }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
                .frame(width: Theme.band, height: Theme.band)
                .contentShape(.circle)
        }
        .buttonStyle(Press())
        .disabled(!held && !reachable && (waking || !canWake))
        .glassEffect(.clear.interactive(), in: .circle)
        .animation(Theme.chrome, value: symbol)
        .accessibilityLabel(label)
        .accessibilityIdentifier(held ? "undo" : "main")
    }

    private var notice: Notice? {
        let p = computer.panel
        if let m = computer.message { return Notice(symbol: "exclamationmark.circle.fill", text: m, color: Theme.red) }
        if let w = p?.warnings.first { return Notice(symbol: "exclamationmark.triangle.fill", text: w, color: Theme.amber) }
        if let t = p?.powerTest { return Notice(symbol: "gauge.with.dots.needle.33percent", text: t, color: .white) }
        if p?.autoApprove == true { return Notice(symbol: "checkmark.shield.fill", text: "Approve everything is on", color: Theme.amber) }
        return nil
    }
}

// MARK: Pieces

/// One number with its unit; rolls to new values. The unit says what it is; VoiceOver hears the full words.
private struct Figure: View {
    let value: Double?
    let digits: Int
    let unit: String
    let spoken: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            if let value {
                Text(value, format: .number.precision(.fractionLength(digits)))
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: value))
                    .animation(Theme.smooth, value: value)
            } else {
                Text("–").font(.system(.title, design: .rounded, weight: .semibold))
            }
            Text(unit).font(.system(.headline, design: .rounded))
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityValue(value.map { "\($0.formatted(.number.precision(.fractionLength(digits)))) \(unit)" } ?? "unknown")
    }
}

struct Notice: Equatable {
    let symbol: String
    let text: String
    let color: Color
}

/// The place under the head where notices appear. It has its own height, so nothing below moves when one comes.
private struct NoticeSlot: View {
    let notice: Notice?

    var body: some View {
        ZStack {
            if let n = notice {
                HStack(spacing: 8) {
                    Image(systemName: n.symbol).foregroundStyle(n.color)
                    Text(n.text).font(.subheadline.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .glassEffect(.clear, in: .capsule)
                .transition(.offset(y: -30).combined(with: .scale(scale: 0.9, anchor: .top)))
                .id(n.text)
                .accessibilityIdentifier("notice")
            }
        }
        .frame(maxWidth: .infinity)
        .animation(Theme.chrome, value: notice)
    }
}

/// What the band is set to, or the countdown after Sleep or Off. One line of text that changes in place: the words
/// morph and the seconds roll, nothing slides in or out.
private struct ReadoutSlot: View {
    @Environment(Computer.self) private var computer
    let words: String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let text: String = {
                guard let held = computer.held, let until = computer.heldUntil else { return words }
                let left = max(1, Int(until.timeIntervalSince(context.date).rounded(.up)))
                let countdown = held == .sleep ? "Sleeps in \(left) s" : "Off · sleeps in \(left) s"
                return computer.checkIn == 0 ? countdown + " · can't wake it from here" : countdown
            }()
            Text(text)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.numericText(countsDown: true))
                .animation(Theme.smooth, value: text)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("readout")
        }
        .sensoryFeedback(.warning, trigger: computer.held) { _, new in new != nil }
    }
}

#Preview {
    NavigationStack { HomeView().background(Ground(awake: 1).ignoresSafeArea()) }.environment(Computer.preview)
}
