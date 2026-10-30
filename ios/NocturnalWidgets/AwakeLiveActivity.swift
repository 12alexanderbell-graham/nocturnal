import ActivityKit
import SwiftUI
import WidgetKit

/// "MacBook Pro, awake until 15:30": a countdown on the Lock Screen and in the Dynamic Island. The system runs
/// the timer, so it stays right without the app or the computer sending anything. Once the end has passed it says the
/// computer is back to When busy.
struct AwakeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AwakeAttributes.self) { context in
            AwakeLockScreen(host: context.attributes.host, state: context.state, ended: context.isStale)
                .activityBackgroundTint(Palette.deep)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.isStale ? "Done" : "Awake").font(.headline)
                    } icon: {
                        Image(systemName: "sun.max.fill").foregroundStyle(Palette.mint)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Countdown(state: s, ended: context.isStale)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(timerInterval: s.from...max(s.until, s.from.addingTimeInterval(1)), countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                        .tint(Palette.mint)
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "sun.max.fill").foregroundStyle(Palette.mint)
            } compactTrailing: {
                Countdown(state: s, ended: context.isStale)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "sun.max.fill").foregroundStyle(Palette.mint)
            }
            .keylineTint(Palette.mint)
        }
    }
}

#Preview("Lock Screen", as: .content, using: AwakeAttributes(host: "MacBook Pro")) {
    AwakeLiveActivity()
} contentStates: {
    AwakeAttributes.ContentState(from: Date().addingTimeInterval(-1800), until: Date().addingTimeInterval(5400))
}
