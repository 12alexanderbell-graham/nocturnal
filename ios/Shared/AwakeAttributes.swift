import ActivityKit
import Foundation

/// The Live Activity for a timed keep-awake ("Always for 2 h"): the Lock Screen and the Dynamic Island count down to
/// the end on their own, with no updates needed. The app starts it, moves it if the end changes, and ends it when the
/// computer stops being kept awake.
nonisolated struct AwakeAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var from: Date
        var until: Date
    }

    var host: String
}
