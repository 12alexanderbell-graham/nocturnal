import ActivityKit
import Foundation

/// Keeps the Live Activity in step with the computer: shown while it's kept awake until a set time, moved if that
/// time changes, ended as soon as it isn't (Off, When Busy, Always with no end, asleep, or the end has passed).
@MainActor
enum AwakeActivity {
    static func sync(_ s: Status) {
        if s.awake, let until = s.until, until.timeIntervalSinceNow > 30 {
            show(host: s.host, until: until)
        } else {
            end()
        }
    }

    static func end() {
        for activity in Activity<AwakeAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private static func show(host: String, until: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let current = Activity<AwakeAttributes>.activities.first
        if let current, current.attributes.host == host {
            let state = current.content.state
            // The computer reports the end to the minute: only a real change moves it.
            guard abs(state.until.timeIntervalSince(until)) > 60 else { return }
            let next = AwakeAttributes.ContentState(from: state.from, until: until)
            Task { await current.update(ActivityContent(state: next, staleDate: until)) }
            return
        }
        end()
        let state = AwakeAttributes.ContentState(from: Date(), until: until)
        _ = try? Activity.request(attributes: AwakeAttributes(host: host),
                                  content: ActivityContent(state: state, staleDate: until))
    }
}
