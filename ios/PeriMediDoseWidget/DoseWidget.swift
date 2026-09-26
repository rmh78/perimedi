import PeriMediDomain
import SwiftUI
import UIKit
import WidgetKit

struct DoseWidgetEntry: TimelineEntry {
    var date: Date
    var face: DoseWidgetFace
}

struct DoseWidgetTimeline: TimelineProvider {
    func placeholder(in context: Context) -> DoseWidgetEntry {
        let now = Date()
        return DoseWidgetEntry(date: now, face: DoseWidgetSnapshot.placeholder.face(at: now))
    }

    func getSnapshot(in context: Context, completion: @escaping (DoseWidgetEntry) -> Void) {
        let now = Date()
        completion(DoseWidgetEntry(date: now, face: DoseWidgetSnapshotFile.read().face(at: now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DoseWidgetEntry>) -> Void) {
        let snapshot = DoseWidgetSnapshotFile.read()
        let now = Date()
        let midnight = DateKeys.calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(86_400)
        let faceNow = snapshot.face(at: now)
        var entries = [DoseWidgetEntry(date: now, face: faceNow)]
        if showsCheck(faceNow), let until = snapshot.ack?.until, until > now {
            entries.append(DoseWidgetEntry(date: until, face: snapshot.face(at: until)))
            if midnight > until {
                entries.append(DoseWidgetEntry(date: midnight, face: snapshot.face(at: midnight)))
            }
            entries.sort { $0.date < $1.date }
            completion(Timeline(entries: entries, policy: .after(until)))
            return
        }
        if midnight > now {
            entries.append(DoseWidgetEntry(date: midnight, face: snapshot.face(at: midnight)))
        }
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }

    private func showsCheck(_ face: DoseWidgetFace) -> Bool {
        face.rows.contains { row in
            if case .check = row.control { return true }
            return false
        }
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
    var face: DoseWidgetFace
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 2 : 4) {
            Text(face.brandTitle)
                .font(.headline.weight(.bold))
                .foregroundStyle(DoseWidgetTheme.blush800)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
            if let helper = face.helper {
                Text(helper)
                    .font(.caption)
                    .foregroundStyle(DoseWidgetTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
            }
            if face.rows.isEmpty {
                if let emptyTitle = face.emptyTitle {
                    Text(emptyTitle)
                        .font(.subheadline)
                        .foregroundStyle(DoseWidgetTheme.ink)
                }
            } else if family == .systemMedium {
                mediumList(face.rows)
            } else {
                smallStack(face.rows)
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

    private func smallStack(_ rows: [DoseWidgetFace.Row]) -> some View {
        let front = rows[0]
        let extra = rows.count - 1
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                medIcon(front)
                VStack(alignment: .leading, spacing: 0) {
                    Text(front.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DoseWidgetTheme.ink)
                        .lineLimit(1)
                    Text(front.detail)
                        .font(.caption)
                        .foregroundStyle(DoseWidgetTheme.inkSoft)
                        .lineLimit(1)
                }
            }
            control(for: front)
            if extra > 0 {
                Text("+\(extra)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DoseWidgetTheme.blush800)
            }
        }
    }

    private func mediumList(_ rows: [DoseWidgetFace.Row]) -> some View {
        let shown = Array(rows.prefix(2))
        let extra = rows.count - 2
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(shown) { row in
                medRow(row)
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DoseWidgetTheme.blush800)
            }
        }
    }

    private func medRow(_ row: DoseWidgetFace.Row) -> some View {
        HStack(spacing: 8) {
            medIcon(row)
            VStack(alignment: .leading, spacing: 0) {
                Text(row.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DoseWidgetTheme.ink)
                    .lineLimit(1)
                Text(row.detail)
                    .font(.caption)
                    .foregroundStyle(DoseWidgetTheme.inkSoft)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            control(for: row)
        }
    }

    private func medIcon(_ row: DoseWidgetFace.Row) -> some View {
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

    @ViewBuilder
    private func control(for row: DoseWidgetFace.Row) -> some View {
        switch row.control {
        case .take(let label):
            Button(intent: MarkTodayMedicationTakenIntent(medicationId: row.medicationId)) {
                capsule(label, color: row.color)
            }
            .buttonStyle(.plain)
        case .check:
            capsule("✓", color: row.color)
        }
    }

    private func capsule(_ text: String, color: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color(widgetHex: color) ?? DoseWidgetTheme.blush500))
    }
}

struct PeriMediDoseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: DoseWidgetKind.id, provider: DoseWidgetTimeline()) { entry in
            DoseWidgetView(face: entry.face)
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
