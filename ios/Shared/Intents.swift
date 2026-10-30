import AppIntents
import Foundation

/// The keep-awake modes the widgets and Shortcuts can choose. Timed stops stay in the app, where the band is.
nonisolated enum KeepMode: String, AppEnum {
    case off, auto, always

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Keep Awake"
    static let caseDisplayRepresentations: [KeepMode: DisplayRepresentation] = [
        .off: "Off",
        .auto: "When Busy",
        .always: "Always",
    ]

    /// The mode as the computer reports it.
    init(wire: String) {
        self = switch wire { case "off": .off; case "on": .always; default: .auto }
    }
}

/// Off, When Busy or Always, from a widget or Shortcuts. The answer's status redraws the widgets.
struct SetKeepModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Keep the Computer Awake"
    static let description = IntentDescription("Sets Nocturnal on your computer to Off, When Busy or Always.")

    @Parameter(title: "Mode") var mode: KeepMode

    init() {}
    init(_ mode: KeepMode) { self.mode = mode }

    func perform() async throws -> some IntentResult {
        guard var status = StatusStore.load() else { return .result() }
        if status.demo {
            status.mode = mode == .off ? "off" : mode == .always ? "on" : "auto"
            status.until = nil
            if mode == .always { status.state = .working; status.headline = "Keeps working" }
            StatusStore.save(status)
            return .result()
        }
        let wire = mode == .always ? "always" : mode.rawValue
        do {
            if let panel = try await Courier.send("mode", ["mode": wire]) {
                StatusStore.save(Status(panel: panel, at: Date()))
            }
        } catch {
            status.line = Self.words(for: error)
            StatusStore.save(status)
        }
        return .result()
    }

    static func words(for error: Courier.Failure) -> String {
        switch error {
        case .notPaired: "Pair in the app first"
        case .relay: "Can't reach the relay"
        case .refused(let why): why
        case .noAnswer: "No answer from the computer"
        }
    }
}

/// Wakes a sleeping computer: it picks this up at its next check-in, so nothing waits for an answer.
struct WakeComputerIntent: AppIntent {
    static let title: LocalizedStringResource = "Wake the Computer"
    static let description = IntentDescription("Wakes the computer at its next check-in.")

    func perform() async throws -> some IntentResult {
        guard var status = StatusStore.load() else { return .result() }
        if status.demo {
            status.state = .working
            status.headline = "Keeps working"
        } else {
            do {
                try await Courier.send("wake", ["minutes": status.wakeFor], wait: 0)
                let by = Date().addingTimeInterval(Double(max(status.checkIn, 1)) * 60)
                status.line = "Wake sent. It wakes by " + by.formatted(date: .omitted, time: .shortened) + "."
            } catch {
                status.line = SetKeepModeIntent.words(for: error)
            }
        }
        StatusStore.save(status)
        return .result()
    }
}
