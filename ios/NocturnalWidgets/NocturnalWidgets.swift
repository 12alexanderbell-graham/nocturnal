import AppIntents
import SwiftUI
import WidgetKit

// MARK: Timeline

/// Draws what the app last stored, and asks the computer itself when that's more than a few minutes old (the app
/// isn't always open). Redraws every five minutes so "Last heard" turns up on time, and asks again after fifteen.
struct StatusProvider: TimelineProvider {
    static let askAfter: TimeInterval = 8 * 60

    func placeholder(in context: Context) -> StatusEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        let status = StatusStore.load()
        completion(context.isPreview && status == nil ? .sample : StatusEntry(date: Date(), status: status, paired: PairingStore.load() != nil || status?.demo == true))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        Task {
            var status = StatusStore.load()
            let paired = PairingStore.load() != nil
            if paired, status?.demo != true, status.map({ Date().timeIntervalSince($0.at) > Self.askAfter }) ?? true {
                if let panel = try? await Courier.send("panel", keep: false, wait: 8) {
                    let fresh = Status(panel: panel, at: Date())
                    StatusStore.save(fresh)
                    status = fresh
                }
            }
            let now = Date()
            let entries = (0..<3).map { StatusEntry(date: now.addingTimeInterval(Double($0) * 300), status: status, paired: paired || status?.demo == true) }
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60))))
        }
    }
}

// MARK: Widget

struct StatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "status", provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Nocturnal")
        .description("Whether your computer keeps working, with a button to keep it awake.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct StatusWidgetView: View {
    let entry: StatusEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular: StatusCircular(entry: entry)
        case .accessoryRectangular: StatusRectangular(entry: entry)
        case .accessoryInline: StatusInline(entry: entry)
        case .systemMedium: StatusMedium(entry: entry).widgetGround(entry.status)
        default: StatusSmall(entry: entry).widgetGround(entry.status)
        }
    }
}

// MARK: Previews

#Preview(as: .systemSmall) { StatusWidget() } timeline: { StatusEntry.sample }
#Preview(as: .systemMedium) { StatusWidget() } timeline: { StatusEntry.sample }
#Preview(as: .accessoryRectangular) { StatusWidget() } timeline: { StatusEntry.sample }
#Preview(as: .accessoryCircular) { StatusWidget() } timeline: { StatusEntry.sample }
