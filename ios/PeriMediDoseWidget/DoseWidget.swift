import PeriMediDomain
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
        let midnight = DateKeys.calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(86_400)
        completion(
            Timeline(
                entries: [
                    DoseWidgetEntry(date: now, snapshot: snapshot),
                    DoseWidgetEntry(date: midnight, snapshot: snapshot),
                ],
                policy: .after(midnight)
            )
        )
    }
}

enum DoseWidgetTheme {
    static let cream = Color(widgetHex: "#fff9f6") ?? Color.white
    static let blush500 = Color(widgetHex: "#e85a84") ?? Color.pink
    static let blush800 = Color(widgetHex: "#94274b") ?? Color.pink
    static let ink = Color(widgetHex: "#3d2c33") ?? Color.black
}

struct DoseWidgetView: View {
    var snapshot: DoseWidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let visible = snapshot.visible(at: Date())
        VStack(alignment: .leading, spacing: 8) {
            Text(snapshot.chrome.brandTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DoseWidgetTheme.blush800)
            if visible.meds.isEmpty {
                empty
            } else if family == .systemMedium {
                mediumList(visible.meds)
            } else {
                smallStack(visible.meds)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            DoseWidgetTheme.cream
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snapshot.chrome.emptyTitle)
                .font(.headline)
                .foregroundStyle(DoseWidgetTheme.ink)
            Text(snapshot.chrome.emptyBody)
                .font(.subheadline)
                .foregroundStyle(DoseWidgetTheme.ink.opacity(0.7))
        }
    }

    private func smallStack(_ meds: [DoseWidgetSnapshot.Row]) -> some View {
        let front = meds[0]
        let rest = Array(meds.dropFirst())
        let backs = Array(rest.prefix(2))
        return ZStack(alignment: .topTrailing) {
            ZStack(alignment: .topLeading) {
                ForEach(Array(backs.enumerated().reversed()), id: \.element.id) { index, row in
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(fill(for: row))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .offset(x: CGFloat(index + 1) * 7, y: CGFloat(index + 1) * 7)
                }
                frontCard(front)
            }
            if rest.count > 0 {
                Text("+\(rest.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(DoseWidgetTheme.blush800))
            }
        }
        .padding(.trailing, rest.isEmpty ? 0 : 16)
        .padding(.bottom, rest.isEmpty ? 0 : 16)
    }

    private func frontCard(_ row: DoseWidgetSnapshot.Row) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.name)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
            Text("\(row.doseLabel) · \(row.earliestTimeOfDay)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
            Spacer(minLength: 0)
            takenButton(row, compact: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(fill(for: row))
        )
    }

    private func mediumList(_ meds: [DoseWidgetSnapshot.Row]) -> some View {
        let rows = Array(meds.prefix(3))
        let extra = Array(meds.dropFirst(3))
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(rows) { row in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(fill(for: row))
                        .frame(width: 6)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DoseWidgetTheme.ink)
                            .lineLimit(1)
                        Text("\(row.doseLabel) · \(row.earliestTimeOfDay)")
                            .font(.caption)
                            .foregroundStyle(DoseWidgetTheme.ink.opacity(0.7))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    takenButton(row, compact: true)
                }
                .padding(.vertical, 4)
                .padding(.trailing, 4)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(fill(for: row).opacity(0.16))
                )
            }
            if !extra.isEmpty {
                HStack(spacing: 6) {
                    ForEach(extra.prefix(4)) { row in
                        Circle()
                            .fill(fill(for: row))
                            .frame(width: 10, height: 10)
                    }
                    Text("+\(extra.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DoseWidgetTheme.blush800)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func takenButton(_ row: DoseWidgetSnapshot.Row, compact: Bool) -> some View {
        Button(intent: MarkTodayMedicationTakenIntent(medicationId: row.medicationId)) {
            Text(snapshot.chrome.takenAction)
                .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .frame(maxWidth: compact ? nil : .infinity)
        }
        .tint(DoseWidgetTheme.blush500)
    }

    private func fill(for row: DoseWidgetSnapshot.Row) -> Color {
        Color(widgetHex: row.color) ?? DoseWidgetTheme.blush500
    }
}

struct PeriMediDoseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: DoseWidgetKind.id, provider: DoseWidgetTimeline()) { entry in
            DoseWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName(LocalizedStringResource("widget.gallery.name", defaultValue: "PeriMedi"))
        .description(LocalizedStringResource("widget.gallery.description", defaultValue: "Today's medications"))
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
