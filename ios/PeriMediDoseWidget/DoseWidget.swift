import PeriMediDomain
import SwiftUI
import UIKit
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
                entries: [DoseWidgetEntry(date: now, snapshot: snapshot)],
                policy: .after(min(midnight, now.addingTimeInterval(15 * 60)))
            )
        )
    }
}

enum DoseWidgetTheme {
    static let cream = Color(widgetHex: "#fff9f6") ?? Color.white
    static let blush500 = Color(widgetHex: "#e85a84") ?? Color.pink
    static let blush800 = Color(widgetHex: "#94274b") ?? Color.pink
    static let ink = Color(widgetHex: "#3d2c33") ?? Color.black
    static let inkSoft = Color(widgetHex: "#6b5560") ?? Color.gray
    static let pageWash = Color(widgetHex: "#fde2ea") ?? Color.clear
}

struct DoseWidgetView: View {
    var snapshot: DoseWidgetSnapshot
    var now: Date = Date()
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let visible = snapshot.visible(at: now)
        VStack(alignment: .leading, spacing: 8) {
            Text(snapshot.chrome.brandTitle)
                .font(.headline.weight(.bold))
                .foregroundStyle(DoseWidgetTheme.blush800)
                .fixedSize(horizontal: false, vertical: true)
            if visible.meds.isEmpty {
                Text(snapshot.chrome.emptyTitle)
                    .font(.subheadline)
                    .foregroundStyle(DoseWidgetTheme.ink)
            } else if family == .systemMedium {
                mediumList(visible.meds, taken: snapshot.chrome.takenAction)
            } else {
                smallStack(visible.meds, taken: snapshot.chrome.takenAction)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            ZStack {
                DoseWidgetTheme.cream
                RadialGradient(
                    colors: [DoseWidgetTheme.pageWash, .clear],
                    center: UnitPoint(x: 0.1, y: 0),
                    startRadius: 4,
                    endRadius: 180
                )
            }
        }
    }

    private func smallStack(_ meds: [DoseWidgetSnapshot.Row], taken: String) -> some View {
        let front = meds[0]
        let extra = meds.count - 1
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                medIcon(front)
                VStack(alignment: .leading, spacing: 0) {
                    Text(front.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DoseWidgetTheme.ink)
                        .lineLimit(1)
                    Text("\(front.doseLabel) · \(front.earliestTimeOfDay)")
                        .font(.caption)
                        .foregroundStyle(DoseWidgetTheme.inkSoft)
                        .lineLimit(1)
                }
            }
            takenButton(front, taken: taken)
            if extra > 0 {
                Text("+\(extra)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DoseWidgetTheme.blush800)
            }
        }
    }

    private func mediumList(_ meds: [DoseWidgetSnapshot.Row], taken: String) -> some View {
        let rows = Array(meds.prefix(2))
        let extra = meds.count - 2
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(rows) { row in
                medRow(row, taken: taken, nameLines: 1)
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DoseWidgetTheme.blush800)
            }
        }
    }

    private func medRow(_ row: DoseWidgetSnapshot.Row, taken: String, nameLines: Int) -> some View {
        HStack(spacing: 8) {
            medIcon(row)
            VStack(alignment: .leading, spacing: 0) {
                Text(row.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DoseWidgetTheme.ink)
                    .lineLimit(nameLines)
                Text("\(row.doseLabel) · \(row.earliestTimeOfDay)")
                    .font(.caption)
                    .foregroundStyle(DoseWidgetTheme.inkSoft)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            takenButton(row, taken: taken)
        }
    }

    private func medIcon(_ row: DoseWidgetSnapshot.Row) -> some View {
        let ring = Color(widgetHex: row.color) ?? DoseWidgetTheme.blush500
        return formImage(row.icon)
            .scaledToFill()
            .frame(width: 28, height: 28)
            .clipShape(Circle())
            .padding(2)
            .background(Circle().fill(ring))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func formImage(_ name: String) -> some View {
        if #available(iOS 18.0, *) {
            Image(uiImage: formThumbnail(name))
                .resizable()
                .widgetAccentedRenderingMode(.fullColor)
        } else {
            Image(uiImage: formThumbnail(name))
                .resizable()
        }
    }

    private func formThumbnail(_ name: String) -> UIImage {
        // The catalog photo is 1024px. The small widget archive rejects that size.
        let side: CGFloat = 96
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            UIImage(named: name)?.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
    }

    private func takenButton(_ row: DoseWidgetSnapshot.Row, taken: String) -> some View {
        Button(intent: MarkTodayMedicationTakenIntent(medicationId: row.medicationId)) {
            Text(taken)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(widgetHex: row.color) ?? DoseWidgetTheme.blush500))
        }
        .buttonStyle(.plain)
    }
}

struct PeriMediDoseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: DoseWidgetKind.id, provider: DoseWidgetTimeline()) { entry in
            DoseWidgetView(snapshot: entry.snapshot, now: entry.date)
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
