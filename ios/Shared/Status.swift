import Foundation
import WidgetKit

/// What the widgets and the Live Activity show: the computer's state as the phone last understood it. The app writes
/// it after every answer; the widgets refresh it themselves (Courier) once it's a few minutes old. It lives in the
/// app group, next to nothing else.
nonisolated struct Status: Codable, Equatable, Sendable {
    enum State: String, Codable, Sendable {
        case working    // kept awake
        case normal     // lid open, sleeps the usual way
        case asleep
        case silent     // kept awake with the lid open, yet not answering: offline
    }

    var host: String
    var state: State
    var headline: String
    /// A word from a widget button just pressed ("Wake sent…", or what went wrong). Empty otherwise: the widgets
    /// say what the computer is doing from the fields below, not which agent is busy.
    var line: String
    var mode: String            // "off", "auto" or "on"
    /// The end of a timed keep-awake.
    var until: Date?
    var pct: Int?
    var watts: Double?
    var hours: Double?
    var plugged = false
    /// Optional so a status saved by an older build still reads.
    var lidClosed: Bool?
    /// Minutes between a sleeping computer's check-ins (0: it can't be woken from the phone).
    var checkIn = 0
    var wakeFor = 60
    /// When the computer said this.
    var at: Date
    var demo = false

    init(panel p: Panel, at: Date, asleep: Bool = false, silent: Bool = false, demo: Bool = false) {
        host = p.host
        state = silent ? .silent : asleep ? .asleep : p.keeps ? .working : p.lidClosed ? .asleep : .normal
        headline = switch state {
        case .working: "Keeps working"
        case .normal: "Sleeps normally"
        case .asleep: "Asleep"
        case .silent: "Not answering"
        }
        line = ""
        mode = p.mode
        until = p.mode == "on" ? p.alwaysUntil.flatMap { Clock.date($0, after: at) } : nil
        let f = p.figures
        pct = f?.pct
        watts = f?.w
        hours = f?.h
        plugged = f?.plugged ?? false
        lidClosed = p.lidClosed
        checkIn = p.checkIn ?? 0
        wakeFor = p.wakeFor ?? 60
        self.at = at
        self.demo = demo
    }

    var awake: Bool { state == .working }

    /// The quiet line under the state: a button's answer if there is one; since when it sleeps; when it was last
    /// heard once the news is old; otherwise how it's set and how long the battery lasts ("Lid shut · 19 h left").
    func detail(at now: Date) -> String {
        if !line.isEmpty { return line }
        let time = at.formatted(date: .omitted, time: .shortened)
        if state == .asleep { return "Since " + time }
        if state == .silent || (!demo && now.timeIntervalSince(at) > 20 * 60) { return "Last heard at " + time }
        var parts: [String] = []
        if state == .working, let until, until > now {
            parts.append("Until " + until.formatted(date: .omitted, time: .shortened))
        } else if lidClosed == true {
            parts.append("Lid shut")
        }
        if plugged {
            parts.append("Plugged in")
        } else if let hours, hours > 0 {
            parts.append((hours < 1 ? "\(max(1, Int((hours * 60).rounded()))) min" : "\(Int(hours.rounded())) h") + " left")
        }
        return parts.joined(separator: " · ")
    }
}

/// The status in the app group, shared by the app and the widgets.
nonisolated enum StatusStore {
    static let group = "group.tools.nocturnal"
    private static let key = "status"

    static func load() -> Status? {
        guard let data = UserDefaults(suiteName: group)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Status.self, from: data)
    }

    /// Saves it and redraws the widgets, but only when something they show has changed (or it has aged a while),
    /// so a busy session in the app doesn't spend the widgets' refresh allowance.
    static func save(_ s: Status?) {
        let defaults = UserDefaults(suiteName: group)
        let before = load()
        guard let s else {
            defaults?.removeObject(forKey: key)
            if before != nil { WidgetCenter.shared.reloadAllTimelines() }
            return
        }
        guard let data = try? JSONEncoder().encode(s) else { return }
        defaults?.set(data, forKey: key)
        var same = before
        same?.at = s.at
        if same != s || before.map({ s.at.timeIntervalSince($0.at) > 300 }) == true {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

/// Times as the computer writes them ("14:30" or "2:30 PM", its own clock).
nonisolated enum Clock {
    /// Minutes from `now` until the clock next shows `text`.
    static func minutesUntil(_ text: String, now: Date = Date()) -> Double? {
        date(text, after: now).map { $0.timeIntervalSince(now) / 60 }
    }

    /// The next moment after `now` that the clock shows `text`.
    static func date(_ text: String, after now: Date) -> Date? {
        guard let m = text.firstMatch(of: /(\d{1,2})[:.](\d{2})\s*([AaPp])?/), var h = Int(m.1), let min = Int(m.2) else { return nil }
        if let ap = m.3?.lowercased() { h = h % 12 + (ap == "p" ? 12 : 0) }
        var c = Calendar.current.dateComponents([.year, .month, .day], from: now)
        c.hour = h
        c.minute = min
        guard var d = Calendar.current.date(from: c) else { return nil }
        if d < now { d = d.addingTimeInterval(24 * 3600) }
        return d
    }
}
