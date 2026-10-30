import SwiftUI

/// Nocturnal's colours, for the app, the widgets and the Live Activity: night, the greens of the app icon, and
/// amber and red only for warnings and errors. The ink is always white.
nonisolated enum Palette {
    static let night = Color(red: 0.035, green: 0.047, blue: 0.098)
    static let nightLift = Color(red: 0.086, green: 0.118, blue: 0.247)
    static let nightGlow = Color(red: 0.231, green: 0.298, blue: 0.604)
    static let deep = Color(red: 0.020, green: 0.157, blue: 0.086)
    static let green = Color(red: 0.063, green: 0.400, blue: 0.231)
    static let mint = Color(red: 0.251, green: 0.839, blue: 0.608)
    static let amber = Color(red: 1.0, green: 0.776, blue: 0.282)
    static let red = Color(red: 1.0, green: 0.42, blue: 0.38)

    /// The ground's nine mesh colours, from night (0) to green (1).
    static func ground(_ awake: Double) -> [Color] {
        let night = [nightLift, Self.night, nightGlow,
                     Self.night, nightLift, Self.night,
                     Self.night, Self.night, nightLift]
        let green = [Self.green, deep, mint,
                     deep, Self.green, Self.green,
                     deep, deep, Self.green]
        return zip(night, green).map { $0.mix(with: $1, by: awake, in: .perceptual) }
    }

    static let meshPoints: [SIMD2<Float>] = [
        [0, 0], [0.5, 0], [1, 0],
        [0, 0.5], [0.5, 0.42], [1, 0.5],
        [0, 1], [0.5, 1], [1, 1],
    ]
}
