import SwiftUI
import WidgetKit

struct DoseWidgetEntry: TimelineEntry {
    var date: Date
    var snapshot: DoseWidgetSnapshot
}

struct DoseWidgetTimeline: TimelineProvider {
    func placeholder(in context: Context) -> DoseWidgetEntry {
        DoseWidgetEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (DoseWidgetEntry) -> Void) {
        completion(DoseWidgetEntry(date: Date(), snapshot: DoseWidgetSnapshotFile.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DoseWidgetEntry>) -> Void) {
        let snapshot = DoseWidgetSnapshotFile.read()
        let now = Date()
        var dates = [now]
        var policy: TimelineReloadPolicy = .never
        if let slot = snapshot.slot {
            let fireAt = Date(timeIntervalSince1970: slot.fireAtEpoch)
            if fireAt > now {
                dates.append(fireAt)
                policy = .after(fireAt)
            }
        }
        let entries = dates.map { DoseWidgetEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: policy))
    }
}

struct DoseWidgetView: View {
    var snapshot: DoseWidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let slot = snapshot.slot {
            occupied(slot)
        } else {
            empty
        }
    }

    private func occupied(_ slot: DoseWidgetSnapshot.Slot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snapshot.chrome.nextTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(slot.medicationName)
                .font(.headline)
                .lineLimit(1)
            Text("\(slot.doseLabel) · \(slot.timeOfDay)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if family != .systemSmall {
                Spacer(minLength: 0)
            }
            Button(intent: MarkDoseTakenIntent(identity: slot.identity)) {
                Text(snapshot.chrome.takenAction)
                    .frame(maxWidth: .infinity)
            }
            .tint(accent(for: slot))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snapshot.chrome.emptyTitle)
                .font(.headline)
            Text(snapshot.chrome.emptyBody)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func accent(for slot: DoseWidgetSnapshot.Slot) -> Color {
        if let hex = slot.color, let color = Color(widgetHex: hex) {
            return color
        }
        return Color(red: 0.83, green: 0.24, blue: 0.42)
    }
}

struct PeriMediDoseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: DoseWidgetKind.id, provider: DoseWidgetTimeline()) { entry in
            DoseWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) {
                    Color(red: 1, green: 0.97, blue: 0.96)
                }
        }
        .configurationDisplayName(LocalizedStringResource("widget.gallery.name", defaultValue: "PeriMedi"))
        .description(LocalizedStringResource("widget.gallery.description", defaultValue: "Next pending dose"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PeriMediDoseWidgetBundle: WidgetBundle {
    var body: some Widget {
        PeriMediDoseWidget()
    }
}

private extension Color {
    init?(widgetHex: String) {
        var hex = widgetHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
